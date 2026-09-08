import 'dart:convert';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:piesocket_channels/channels.dart';

import '../config.dart';
import '../shared.dart';

/// Port of the JS demo's `binary-transfer-v4.html`.
///
/// A tiny JSON `file-meta` frame (name/type/size) is published right before
/// the raw bytes so the receiver knows how to reconstruct the file. The
/// bytes go out as a real binary WebSocket frame via `channel.sendBinary()`
/// (added in SDK 2.4.0); the server re-wraps any inbound binary frame as a
/// `system::binary` event whose `data` is base64. Same wire behaviour as the
/// JS demo, so a browser tab on `#binary-demo` interoperates.
const _channelName = 'binary-demo';
const _maxBytes = 2 * 1024 * 1024;

class _Received {
  _Received(this.name, this.type, this.bytes);
  final String name;
  final String type;
  final Uint8List bytes;
  bool get isImage => type.startsWith('image/');
}

class BinaryTransferScreen extends StatefulWidget {
  const BinaryTransferScreen({super.key, required this.username});

  final String username;

  @override
  State<BinaryTransferScreen> createState() => _BinaryTransferScreenState();
}

class _BinaryTransferScreenState extends State<BinaryTransferScreen>
    with EventLogHost {
  late final PieSocket _piesocket;
  String get _username => widget.username;
  Channel? _channel;
  bool _connected = false;

  Map<String, dynamic>? _pendingMeta;
  PlatformFile? _picked;
  final List<_Received> _received = [];

  @override
  void initState() {
    super.initState();
    // notifySelf off: we don't want our own file-meta / binary frames echoed
    // back (they'd arrive with no matching pending meta and just log noise).
    _piesocket = buildPieSocket(_username, presence: false, notifySelf: false);
    final channel = _piesocket.join(_channelName);
    _channel = channel;

    channel.listen('system:connected', (_) {
      logLine('subscribed to #$_channelName', LogKind.system);
      if (mounted) setState(() => _connected = true);
    });

    channel.listen('file-meta', (event) {
      final data = decodeMap(event.getData());
      final meta = decodeMap(event.getMeta());
      if ((meta['from'] ?? '') == _username) return;
      _pendingMeta = data;
      logLine(
        'incoming: ${data['name']} (${data['size']} bytes) from ${meta['from']}',
        LogKind.system,
      );
    });

    channel.listen('system::binary', (event) {
      final meta = _pendingMeta;
      if (meta == null) {
        logLine('binary frame arrived with no pending file-meta — dropped',
            LogKind.error);
        return;
      }
      final bytes = base64Decode(event.getData());
      setState(() {
        _received.insert(
          0,
          _Received(
            (meta['name'] ?? 'file').toString(),
            (meta['type'] ?? 'application/octet-stream').toString(),
            bytes,
          ),
        );
      });
      logLine('reconstructed ${meta['name']} (${bytes.length} bytes)');
      _pendingMeta = null;
    });
  }

  @override
  void dispose() {
    _piesocket.leave(_channelName);
    super.dispose();
  }

  Future<void> _pickFile() async {
    final result = await FilePicker.platform.pickFiles(withData: true);
    if (result == null || result.files.isEmpty) return;
    final file = result.files.first;
    if ((file.size) > _maxBytes) {
      setState(() => _picked = null);
      _snack('Too large (2 MB max)');
      return;
    }
    setState(() => _picked = file);
  }

  void _sendFile() {
    final file = _picked;
    final channel = _channel;
    if (file == null || channel == null) return;
    final bytes = file.bytes;
    if (bytes == null) {
      _snack('Could not read file bytes');
      return;
    }
    final type = _guessType(file.extension);
    channel.publishEvent(
      'file-meta',
      data: {'name': file.name, 'type': type, 'size': bytes.length},
      meta: {'from': _username},
    );
    channel.sendBinary(bytes);
    logLine('sent ${file.name} (${bytes.length} bytes)', LogKind.me);
    setState(() => _picked = null);
  }

  static String _guessType(String? ext) {
    switch ((ext ?? '').toLowerCase()) {
      case 'png':
        return 'image/png';
      case 'jpg':
      case 'jpeg':
        return 'image/jpeg';
      case 'gif':
        return 'image/gif';
      case 'webp':
        return 'image/webp';
      case 'txt':
        return 'text/plain';
      case 'json':
        return 'application/json';
      case 'pdf':
        return 'application/pdf';
      default:
        return 'application/octet-stream';
    }
  }

  void _snack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(msg)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Binary transfer'),
        actions: [
          Center(child: ConnPill(connected: _connected)),
          const SizedBox(width: 12),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          DemoCard(
            title: 'Send',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(children: [
                  OutlinedButton.icon(
                    onPressed: _pickFile,
                    icon: const Icon(Icons.attach_file),
                    label: const Text('Pick file'),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      _picked == null
                          ? 'Capped at 2 MB for this demo.'
                          : '${_picked!.name} — ${_picked!.size} bytes',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ),
                ]),
                const SizedBox(height: 12),
                FilledButton(
                  onPressed:
                      _picked != null && _connected ? _sendFile : null,
                  child: const Text('Send file'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          DemoCard(
            title: 'Received',
            child: _received.isEmpty
                ? Text('Nothing received yet',
                    style: Theme.of(context).textTheme.bodySmall)
                : Column(
                    children: [
                      for (final r in _received)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: r.isImage
                              ? ClipRRect(
                                  borderRadius: BorderRadius.circular(8),
                                  child: Image.memory(r.bytes,
                                      fit: BoxFit.contain),
                                )
                              : ListTile(
                                  leading: const Icon(Icons.insert_drive_file),
                                  title: Text(r.name),
                                  subtitle: Text('${r.bytes.length} bytes'),
                                ),
                        ),
                    ],
                  ),
          ),
          const SizedBox(height: 16),
          DemoCard(title: 'Event log', child: EventLog(lines: log)),
        ],
      ),
    );
  }
}
