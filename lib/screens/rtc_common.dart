import 'package:flutter/material.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';

/// Keeps one initialised [RTCVideoRenderer] per stream key (self, or a
/// participant uuid), so the call screens only deal with keys + streams.
class RendererPool {
  final Map<String, RTCVideoRenderer> _renderers = {};

  Iterable<String> get keys => _renderers.keys;

  RTCVideoRenderer? operator [](String key) => _renderers[key];

  Future<RTCVideoRenderer> set(String key, MediaStream stream) async {
    var renderer = _renderers[key];
    if (renderer == null) {
      renderer = RTCVideoRenderer();
      await renderer.initialize();
      _renderers[key] = renderer;
    }
    renderer.srcObject = stream;
    return renderer;
  }

  void remove(String key) {
    final renderer = _renderers.remove(key);
    renderer?.srcObject = null;
    renderer?.dispose();
  }

  void disposeAll() {
    for (final r in _renderers.values) {
      r.srcObject = null;
      r.dispose();
    }
    _renderers.clear();
  }
}

class VideoTile extends StatelessWidget {
  const VideoTile({
    super.key,
    required this.renderer,
    required this.label,
    this.mirror = false,
    this.aspectRatio = 4 / 3,
  });

  final RTCVideoRenderer? renderer;
  final String label;
  final bool mirror;
  final double aspectRatio;

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: aspectRatio,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(10),
        child: Container(
          color: Colors.black,
          child: Stack(
            fit: StackFit.expand,
            children: [
              if (renderer != null)
                RTCVideoView(
                  renderer!,
                  mirror: mirror,
                  objectFit:
                      RTCVideoViewObjectFit.RTCVideoViewObjectFitCover,
                )
              else
                const Center(
                  child: Icon(Icons.videocam_off, color: Colors.white38),
                ),
              Positioned(
                left: 8,
                bottom: 8,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: Colors.black54,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    label,
                    style: const TextStyle(color: Colors.white, fontSize: 12),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The "start / join a call" form shared by all three call screens.
class JoinCallForm extends StatefulWidget {
  const JoinCallForm({
    super.key,
    required this.roomHint,
    required this.onJoin,
    this.extraToggles = const [],
  });

  final String roomHint;
  final void Function(String room, bool audioOnly) onJoin;
  final List<Widget> extraToggles;

  @override
  State<JoinCallForm> createState() => _JoinCallFormState();
}

class _JoinCallFormState extends State<JoinCallForm> {
  final _controller = TextEditingController();
  bool _audioOnly = false;

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
            Text('Start or join a call',
                style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 12),
            TextField(
              controller: _controller,
              decoration: InputDecoration(hintText: widget.roomHint),
            ),
            const SizedBox(height: 8),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Audio only'),
              value: _audioOnly,
              onChanged: (v) => setState(() => _audioOnly = v),
            ),
            ...widget.extraToggles,
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
                widget.onJoin(room, _audioOnly);
              },
              child: const Text('Join'),
            ),
          ],
        ),
      ),
    );
  }
}
