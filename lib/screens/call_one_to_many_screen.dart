import 'package:flutter/material.dart';
import 'package:piesocket_channels/channels.dart';

import '../config.dart';
import '../shared.dart';
import 'rtc_common.dart';

/// Port of the JS demo's `call-one-to-many-v4.html` — broadcast shape,
/// channel `broadcast-<room>`. Only the broadcaster requests camera/mic
/// (`shouldBroadcast: true`); watchers request an offer from whoever is
/// already broadcasting. Wire-compatible with the JS PieRTC broadcast client.
class CallOneToManyScreen extends StatefulWidget {
  const CallOneToManyScreen({super.key, required this.username});

  final String username;

  @override
  State<CallOneToManyScreen> createState() => _CallOneToManyScreenState();
}

class _CallOneToManyScreenState extends State<CallOneToManyScreen>
    with EventLogHost {
  final _pool = RendererPool();
  PieSocket? _piesocket;
  Channel? _channel;
  String? _channelId;
  String get _username => widget.username;

  bool _joined = false;
  bool _isBroadcaster = false;
  bool _sharingScreen = false;
  String _room = '';
  final List<String> _remotes = [];
  final Map<String, String> _tileLabel = {};

  @override
  void dispose() {
    final id = _channelId;
    if (id != null) _piesocket?.leave(id);
    _pool.disposeAll();
    super.dispose();
  }

  Future<void> _join(String room, bool audioOnly, bool broadcaster) async {
    final piesocket = buildPieSocket(_username);
    final channelId = 'broadcast-$room';
    final channel = piesocket.join(
      channelId,
      shouldBroadcast: broadcaster,
      video: broadcaster && !audioOnly,
      audio: broadcaster,
      pieRTC: true,
      onLocalVideo: (stream, _) async {
        await _pool.set('self', stream);
        if (mounted) setState(() {});
        logLine('local media ready', LogKind.system);
      },
      onParticipantJoined: (uuid, stream) async {
        final isScreen = stream.id.contains('screen');
        final key = isScreen ? stream.id : uuid;
        await _pool.set(key, stream);
        if (mounted) {
          setState(() {
            _tileLabel[key] = _name(uuid) + (isScreen ? ' (screen)' : '');
            if (!_remotes.contains(key)) _remotes.add(key);
          });
        }
        logLine('${isScreen ? "screen from" : "receiving stream from"} '
            '${_name(uuid)}', LogKind.system);
      },
      onParticipantLeft: (uuid) {
        _pool.remove(uuid);
        if (mounted) setState(() => _remotes.remove(uuid));
      },
      onScreenSharingStopped: (uuid, streamId) {
        _pool.remove(streamId);
        if (mounted) {
          setState(() {
            _remotes.remove(streamId);
            if (uuid == _channel?.uuid) _sharingScreen = false;
          });
        }
      },
    );

    for (final evt in const [
      'system::member_joined',
      'system::member_left',
      'system::member_list',
    ]) {
      channel.listen(evt, (_) {
        if (mounted) setState(() {});
      });
    }

    setState(() {
      _piesocket = piesocket;
      _channel = channel;
      _channelId = channelId;
      _room = room;
      _isBroadcaster = broadcaster;
      _joined = true;
    });
    logLine(
      'joined #$channelId as ${broadcaster ? 'broadcaster' : 'watcher'}',
      LogKind.system,
    );
  }

  String _name(String uuid) {
    final member = _channel?.getMemberByUUID(uuid);
    return (member is Map ? member['user'] as String? : null) ?? uuid;
  }

  void _leave() {
    final id = _channelId;
    if (id != null) _piesocket?.leave(id);
    _channel = null;
    _piesocket = null;
    _channelId = null;
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final members = _channel?.getAllMembers() ?? const [];
    return Scaffold(
      appBar: AppBar(title: const Text('1:many broadcast')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (!_joined)
            _BroadcastJoinForm(onJoin: _join)
          else ...[
            Row(children: [
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.secondaryContainer,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(_isBroadcaster ? 'Broadcasting' : 'Watching',
                    style: Theme.of(context).textTheme.labelMedium),
              ),
              const SizedBox(width: 8),
              const ConnPill(connected: true),
              const SizedBox(width: 8),
              Text('#broadcast-$_room',
                  style: Theme.of(context).textTheme.labelLarge),
            ]),
            const SizedBox(height: 8),
            Row(children: [
              if (_isBroadcaster)
                OutlinedButton.icon(
                  onPressed: () {
                    final rtc = _channel?.pieRTC;
                    if (rtc == null) return;
                    if (_sharingScreen) {
                      rtc.stopScreenShare();
                      setState(() => _sharingScreen = false);
                    } else {
                      rtc.shareScreen();
                      setState(() => _sharingScreen = true);
                    }
                  },
                  icon: Icon(_sharingScreen ? Icons.stop_screen_share
                      : Icons.screen_share),
                  label: Text(_sharingScreen ? 'Stop sharing' : 'Share screen'),
                ),
              if (_isBroadcaster) const SizedBox(width: 8),
              FilledButton.tonalIcon(
                onPressed: _leave,
                icon: const Icon(Icons.call_end),
                label: const Text('Leave'),
              ),
            ]),
            const SizedBox(height: 16),
            if (_isBroadcaster) ...[
              Text('You', style: Theme.of(context).textTheme.titleSmall),
              const SizedBox(height: 8),
              SizedBox(
                width: 260,
                child: VideoTile(
                    renderer: _pool['self'], label: _username, mirror: true),
              ),
              const SizedBox(height: 16),
            ],
            Text('Broadcast', style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 8),
            if (_remotes.isEmpty)
              Text(
                _isBroadcaster
                    ? 'Waiting for watchers…'
                    : 'Waiting for a broadcaster…',
                style: Theme.of(context).textTheme.bodyMedium,
              )
            else
              GridView.count(
                crossAxisCount: 2,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                mainAxisSpacing: 12,
                crossAxisSpacing: 12,
                childAspectRatio: 4 / 3,
                children: [
                  for (final key in _remotes)
                    VideoTile(
                        renderer: _pool[key],
                        label: _tileLabel[key] ?? _name(key)),
                ],
              ),
            const SizedBox(height: 16),
            DemoCard(
              title: 'Members (${members.length})',
              child: MemberList(
                members: members,
                selfUuid: _channel?.uuid ?? '',
                selfName: _username,
              ),
            ),
            const SizedBox(height: 16),
            EventLog(lines: log),
          ],
        ],
      ),
    );
  }
}

class _BroadcastJoinForm extends StatefulWidget {
  const _BroadcastJoinForm({required this.onJoin});

  final Future<void> Function(String room, bool audioOnly, bool broadcaster)
      onJoin;

  @override
  State<_BroadcastJoinForm> createState() => _BroadcastJoinFormState();
}

class _BroadcastJoinFormState extends State<_BroadcastJoinForm> {
  final _controller = TextEditingController();
  bool _audioOnly = false;
  bool _broadcaster = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Join a broadcast room',
                style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 12),
            TextField(
              controller: _controller,
              decoration:
                  const InputDecoration(hintText: 'Room code (e.g. keynote-42)'),
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text("I'm the broadcaster"),
              value: _broadcaster,
              onChanged: (v) => setState(() => _broadcaster = v),
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Audio only'),
              value: _audioOnly,
              onChanged: (v) => setState(() => _audioOnly = v),
            ),
            const SizedBox(height: 8),
            FilledButton(
              onPressed: () {
                final room = _controller.text.trim();
                if (room.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Enter a room code first.')),
                  );
                  return;
                }
                widget.onJoin(room, _audioOnly, _broadcaster);
              },
              child: const Text('Join'),
            ),
          ],
        ),
      ),
    );
  }
}
