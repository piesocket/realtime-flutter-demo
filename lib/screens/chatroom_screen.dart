import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:piesocket_channels/channels.dart';

import '../config.dart';
import '../shared.dart';

/// Port of the JS demo's `chatroom-v4.html`.
///
/// Two channels — `general` and `random` — subscribed over one shared v4
/// socket. Switching tabs doesn't reconnect. Presence is delta-based, typing
/// is a debounced indicator, and a DM is a plain frame with a top-level
/// `system::to` so the server delivers it to one member only.
///
/// Channel names, event names (`chat-message`, `typing`) and the `meta.from`
/// shape are identical to the JS demo, so a browser tab in `#general` and
/// this screen are in the same room.
const _channelNames = ['general', 'random'];

class _Msg {
  _Msg(this.from, this.text, {this.mine = false, this.dm = false});
  final String from;
  final String text;
  final bool mine;
  final bool dm;
}

class ChatroomScreen extends StatefulWidget {
  const ChatroomScreen({super.key, required this.username});

  final String username;

  @override
  State<ChatroomScreen> createState() => _ChatroomScreenState();
}

class _ChatroomScreenState extends State<ChatroomScreen>
    with EventLogHost, SingleTickerProviderStateMixin {
  late final PieSocket _piesocket;
  late final TabController _tabs;
  String get _username => widget.username;

  final Map<String, Channel> _channels = {};
  final Map<String, List<_Msg>> _messages = {
    for (final n in _channelNames) n: <_Msg>[],
  };

  bool _connected = false;
  String _activeChannel = _channelNames.first;
  final _input = TextEditingController();
  final _dmInput = TextEditingController();
  String? _dmTarget;

  final Map<String, Timer> _typingTimers = {};
  final Map<String, String> _typingBy = {};
  DateTime _lastTypingSentAt = DateTime.fromMillisecondsSinceEpoch(0);

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: _channelNames.length, vsync: this)
      ..addListener(() {
        if (!_tabs.indexIsChanging) {
          setState(() => _activeChannel = _channelNames[_tabs.index]);
        }
      });
    _piesocket = buildPieSocket(_username);
    for (final name in _channelNames) {
      _joinChannel(name);
    }
  }

  @override
  void dispose() {
    for (final t in _typingTimers.values) {
      t.cancel();
    }
    // Leave secondaries before the primary so we don't trigger a pointless
    // primary-migration reconnect mid-teardown.
    for (final name in _channelNames.reversed) {
      _piesocket.leave(name);
    }
    _tabs.dispose();
    _input.dispose();
    _dmInput.dispose();
    super.dispose();
  }

  void _joinChannel(String name) {
    final channel = _piesocket.join(name);
    _channels[name] = channel;

    // Only the primary channel fires system:connected — the Connection
    // intercepts secondary channels' system::subscribe_success before it
    // reaches their listeners (it settles the control future instead). One
    // flag for the shared socket is all we need.
    channel.listen('system:connected', (_) {
      logLine('[#$name] connected (shared socket)', LogKind.system);
      if (mounted) setState(() => _connected = true);
    });

    channel.listen('chat-message', (event) {
      final data = decodeMap(event.getData());
      final meta = decodeMap(event.getMeta());
      final from = (meta['from'] ?? 'unknown').toString();
      if (from == _username) return; // our own frames are echoed locally
      final dm = data['dm'] == true;
      _appendMessage(
        name,
        _Msg(from, (data['text'] ?? '').toString(), dm: dm),
      );
      logLine('[#$name] $from: ${data['text']}${dm ? ' (DM)' : ''}');
    });

    channel.listen('typing', (event) {
      final data = decodeMap(event.getData());
      final user = (data['user'] ?? '').toString();
      if (user.isEmpty || user == _username) return;
      _showTyping(name, user);
    });

    for (final evt in const [
      'system::member_joined',
      'system::member_left',
      'system::member_list',
    ]) {
      channel.listen(evt, (_) {
        if (mounted) setState(() {}); // member list / dm targets re-render
        logLine('[#$name] $evt', LogKind.system);
      });
    }
  }

  void _appendMessage(String channel, _Msg msg) {
    if (!mounted) return;
    setState(() => _messages[channel]!.add(msg));
  }

  void _showTyping(String channel, String user) {
    _typingTimers[channel]?.cancel();
    setState(() => _typingBy[channel] = user);
    _typingTimers[channel] = Timer(const Duration(seconds: 3), () {
      if (mounted) setState(() => _typingBy.remove(channel));
    });
  }

  void _sendMessage() {
    final text = _input.text.trim();
    if (text.isEmpty) return;
    final channel = _channels[_activeChannel];
    if (channel == null) return;
    channel.publishEvent('chat-message',
        data: {'text': text}, meta: {'from': _username});
    _appendMessage(_activeChannel, _Msg(_username, text, mine: true));
    _input.clear();
  }

  void _maybeSendTyping() {
    final now = DateTime.now();
    if (now.difference(_lastTypingSentAt).inMilliseconds < 1500) return;
    _lastTypingSentAt = now;
    _channels[_activeChannel]
        ?.publishEvent('typing', data: {'user': _username});
  }

  void _sendDm() {
    final target = _dmTarget;
    final text = _dmInput.text.trim();
    if (target == null || text.isEmpty) return;
    final channel = _channels[_activeChannel];
    if (channel == null) return;

    // Raw send() so we can set a top-level `system::to` — the server only
    // delivers this frame to the member whose `user` identity matches.
    // publishEvent() has no parameter for top-level keys like this. Same
    // wire shape as the JS demo's DM.
    channel.send(json.encode({
      'event': 'chat-message',
      'data': {'text': text, 'dm': true},
      'meta': {'from': _username},
      'system::to': target,
    }));

    _appendMessage(
      _activeChannel,
      _Msg('you → $target', text, mine: true, dm: true),
    );
    logLine('[#$_activeChannel] DM to $target: $text', LogKind.me);
    _dmInput.clear();
  }

  List<dynamic> get _activeMembers =>
      _channels[_activeChannel]?.getAllMembers() ?? const [];

  List<String> get _dmTargets {
    final names = <String>{};
    for (final m in _activeMembers) {
      final user = memberUser(m);
      if (user != _username && user != '?') names.add(user);
    }
    return names.toList()..sort();
  }

  @override
  Widget build(BuildContext context) {
    final targets = _dmTargets;
    if (_dmTarget != null && !targets.contains(_dmTarget)) _dmTarget = null;
    final messages = _messages[_activeChannel]!;
    final typing = _typingBy[_activeChannel];

    return Scaffold(
      appBar: AppBar(
        title: const Text('Chatroom'),
        actions: [
          Center(child: ConnPill(connected: _connected)),
          const SizedBox(width: 12),
        ],
        bottom: TabBar(
          controller: _tabs,
          tabs: [for (final n in _channelNames) Tab(text: '#$n')],
        ),
      ),
      body: LayoutBuilder(builder: (context, constraints) {
        final wide = constraints.maxWidth > 720;
        final chat = _chatPane(messages, typing);
        final side = _sidePane(targets);
        return Padding(
          padding: const EdgeInsets.all(16),
          child: wide
              ? Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(child: chat),
                    const SizedBox(width: 16),
                    SizedBox(width: 300, child: side),
                  ],
                )
              : ListView(children: [chat, const SizedBox(height: 16), side]),
        );
      }),
    );
  }

  Widget _chatPane(List<_Msg> messages, String? typing) {
    return DemoCard(
      title: '#$_activeChannel',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            height: 320,
            child: messages.isEmpty
                ? Center(
                    child: Text('No messages yet',
                        style: Theme.of(context).textTheme.bodySmall),
                  )
                : ListView.builder(
                    itemCount: messages.length,
                    itemBuilder: (context, i) => _bubble(messages[i]),
                  ),
          ),
          SizedBox(
            height: 20,
            child: Text(
              typing == null ? '' : '$typing is typing…',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
          const SizedBox(height: 8),
          Row(children: [
            Expanded(
              child: TextField(
                controller: _input,
                decoration: const InputDecoration(hintText: 'Message the room…'),
                onChanged: (_) => _maybeSendTyping(),
                onSubmitted: (_) => _sendMessage(),
              ),
            ),
            const SizedBox(width: 8),
            FilledButton(onPressed: _sendMessage, child: const Text('Send')),
          ]),
          const SizedBox(height: 8),
          Row(children: [
            Expanded(
              child: DropdownButtonFormField<String>(
                initialValue: _dmTarget,
                decoration: const InputDecoration(hintText: 'Direct message to…'),
                items: [
                  for (final t in _dmTargets)
                    DropdownMenuItem(value: t, child: Text(t)),
                ],
                onChanged: (v) => setState(() => _dmTarget = v),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: TextField(
                controller: _dmInput,
                decoration: const InputDecoration(hintText: 'Private message…'),
                onSubmitted: (_) => _sendDm(),
              ),
            ),
            const SizedBox(width: 8),
            OutlinedButton(onPressed: _sendDm, child: const Text('Send DM')),
          ]),
        ],
      ),
    );
  }

  Widget _bubble(_Msg m) {
    final scheme = Theme.of(context).colorScheme;
    return Align(
      alignment: m.mine ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 3),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        constraints: const BoxConstraints(maxWidth: 260),
        decoration: BoxDecoration(
          color: m.dm
              ? scheme.tertiaryContainer
              : (m.mine ? scheme.primaryContainer : scheme.surfaceContainerHighest),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${m.from}${m.dm ? ' (direct message)' : ''}',
              style: Theme.of(context)
                  .textTheme
                  .labelSmall
                  ?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 2),
            Text(m.text),
          ],
        ),
      ),
    );
  }

  Widget _sidePane(List<String> targets) {
    final channel = _channels[_activeChannel];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        DemoCard(
          title: 'Members — #$_activeChannel',
          child: MemberList(
            members: _activeMembers,
            selfUuid: channel?.uuid ?? '',
            selfName: _username,
          ),
        ),
        const SizedBox(height: 16),
        DemoCard(
          title: 'Event log',
          child: EventLog(lines: log),
        ),
      ],
    );
  }
}
