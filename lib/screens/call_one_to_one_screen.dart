import 'package:flutter/material.dart';
import 'package:piesocket_channels/channels.dart';

import '../config.dart';
import '../shared.dart';
import 'rtc_common.dart';

/// Port of the JS demo's `call-one-to-one-v4.html`. Channel name
/// `call-<room>`, PieRTC signalling on the `rtc::` namespace — wire-identical
/// to the JS PieRTC client, so a browser tab and this screen can call each
/// other.
class CallOneToOneScreen extends StatefulWidget {
  const CallOneToOneScreen({super.key, required this.username});

  final String username;

  @override
  State<CallOneToOneScreen> createState() => _CallOneToOneScreenState();
}

class _CallOneToOneScreenState extends State<CallOneToOneScreen>
    with EventLogHost {
  final _pool = RendererPool();
  PieSocket? _piesocket;
  Channel? _channel;
  String? _channelId;
  String get _username => widget.username;

  bool _joined = false;
  bool _sharingScreen = false;
  String _room = '';
  String? _remoteUuid;
  String? _remoteScreenId;

  @override
  void dispose() {
    _leave(pop: false);
    _pool.disposeAll();
    super.dispose();
  }

  Future<void> _join(String room, bool audioOnly) async {
    final piesocket = buildPieSocket(_username);
    final channelId = 'call-$room';
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
        final member = _channel?.getMemberByUUID(uuid);
        final name = (member is Map ? member['user'] : null) ?? uuid;
        if (stream.id.contains('screen')) {
          await _pool.set(stream.id, stream);
          if (mounted) setState(() => _remoteScreenId = stream.id);
          logLine('screen from $name', LogKind.system);
          return;
        }
        await _pool.set(uuid, stream);
        if (mounted) setState(() => _remoteUuid = uuid);
        logLine('connected to $name', LogKind.system);
      },
      onParticipantLeft: (uuid) {
        _pool.remove(uuid);
        final screenId = _remoteScreenId;
        if (screenId != null) _pool.remove(screenId);
        if (mounted) {
          setState(() {
            _remoteUuid = _remoteUuid == uuid ? null : _remoteUuid;
            _remoteScreenId = null;
          });
        }
        logLine('the other participant left', LogKind.system);
      },
      onScreenSharingStopped: (uuid, streamId) {
        _pool.remove(streamId);
        if (mounted) {
          setState(() {
            if (_remoteScreenId == streamId) _remoteScreenId = null;
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
    channel.listen('system:connected', (_) => logLine('joined #$channelId',
        LogKind.system));

    setState(() {
      _piesocket = piesocket;
      _channel = channel;
      _channelId = channelId;
      _room = room;
      _joined = true;
    });
  }

  void _leave({bool pop = true}) {
    final id = _channelId;
    if (id != null) _piesocket?.leave(id);
    _channel = null;
    _piesocket = null;
    _channelId = null;
    if (pop && mounted) Navigator.of(context).pop();
  }

  int get _occupancy => _channel?.getAllMembers().length ?? 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('1:1 call')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (!_joined)
            JoinCallForm(
              roomHint: 'Room code (e.g. call-1234)',
              onJoin: _join,
            )
          else ...[
            Row(children: [
              const ConnPill(connected: true),
              const SizedBox(width: 8),
              Text('#call-$_room',
                  style: Theme.of(context).textTheme.labelLarge),
              const Spacer(),
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
                onPressed: () => _leave(),
                icon: const Icon(Icons.call_end),
                label: const Text('Leave'),
              ),
            ]),
            if (_occupancy > 2)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Text(
                  'This room has more than 2 people — for a real 1:1 flow, '
                  'pick a room code nobody else is using.',
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ),
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
                if (_remoteUuid != null)
                  VideoTile(
                    renderer: _pool[_remoteUuid!],
                    label: _remoteName,
                  ),
                if (_remoteScreenId != null)
                  VideoTile(
                    renderer: _pool[_remoteScreenId!],
                    label: '$_remoteName (screen)',
                  ),
              ],
            ),
            if (_remoteUuid == null)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Text('Waiting for the other person to join…',
                    style: Theme.of(context).textTheme.bodyMedium),
              ),
            const SizedBox(height: 16),
            EventLog(lines: log),
          ],
        ],
      ),
    );
  }

  String get _remoteName {
    final uuid = _remoteUuid;
    if (uuid == null) return '';
    final member = _channel?.getMemberByUUID(uuid);
    return (member is Map ? member['user'] as String? : null) ?? uuid;
  }
}
