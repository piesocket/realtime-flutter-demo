import 'package:flutter/material.dart';
import 'package:piesocket_channels/channels.dart';

import '../config.dart';
import '../shared.dart';
import 'rtc_common.dart';

/// Port of the JS demo's `call-many-to-many-v4.html` — full mesh, channel
/// `mesh-<room>`. Every participant streams to every other. Wire-compatible
/// with the JS PieRTC mesh client.
class CallManyToManyScreen extends StatefulWidget {
  const CallManyToManyScreen({super.key, required this.username});

  final String username;

  @override
  State<CallManyToManyScreen> createState() => _CallManyToManyScreenState();
}

class _CallManyToManyScreenState extends State<CallManyToManyScreen>
    with EventLogHost {
  final _pool = RendererPool();
  PieSocket? _piesocket;
  Channel? _channel;
  String? _channelId;
  String get _username => widget.username;

  bool _joined = false;
  bool _sharingScreen = false;
  String _room = '';
  final List<String> _remotes = [];
  final Map<String, String> _tileLabel = {}; // pool key -> label

  @override
  void dispose() {
    final id = _channelId;
    if (id != null) _piesocket?.leave(id);
    _pool.disposeAll();
    super.dispose();
  }

  Future<void> _join(String room, bool audioOnly) async {
    final piesocket = buildPieSocket(_username);
    final channelId = 'mesh-$room';
    final channel = piesocket.join(
      channelId,
      video: !audioOnly,
      audio: true,
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
        logLine('${isScreen ? "screen from" : "connected to"} ${_name(uuid)}',
            LogKind.system);
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
      _joined = true;
    });
    logLine('joined #$channelId', LogKind.system);
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
      appBar: AppBar(title: const Text('Many:many call')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (!_joined)
            JoinCallForm(roomHint: 'Room code (e.g. standup)', onJoin: _join)
          else ...[
            Row(children: [
              const ConnPill(connected: true),
              const SizedBox(width: 8),
              Text('#mesh-$_room',
                  style: Theme.of(context).textTheme.labelLarge),
              const Spacer(),
              Text('Members: ${members.length}',
                  style: Theme.of(context).textTheme.labelMedium),
            ]),
            const SizedBox(height: 8),
            Row(children: [
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
              const SizedBox(width: 8),
              FilledButton.tonalIcon(
                onPressed: _leave,
                icon: const Icon(Icons.call_end),
                label: const Text('Leave'),
              ),
            ]),
            const SizedBox(height: 16),
            GridView.count(
              crossAxisCount: 2,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
              childAspectRatio: 4 / 3,
              children: [
                VideoTile(
                    renderer: _pool['self'], label: _username, mirror: true),
                for (final key in _remotes)
                  VideoTile(
                      renderer: _pool[key], label: _tileLabel[key] ?? _name(key)),
              ],
            ),
            const SizedBox(height: 16),
            DemoCard(
              title: 'Members',
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
