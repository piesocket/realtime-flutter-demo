import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:piesocket_channels/channels.dart';

/// A [PieSocketEvent] delivers `data`/`meta` as strings — JSON text when the
/// sender put an object there, a bare string otherwise. These decode
/// defensively so a malformed or plain payload never throws.
Map<String, dynamic> decodeMap(String raw) {
  if (raw.isEmpty) return const {};
  try {
    final decoded = json.decode(raw);
    return decoded is Map ? decoded.cast<String, dynamic>() : {'value': decoded};
  } catch (_) {
    return {'value': raw};
  }
}

String memberUser(dynamic member) {
  if (member is Map) return (member['user'] ?? member['uuid'] ?? '?').toString();
  return member.toString();
}

String? memberUuid(dynamic member) {
  if (member is Map) return member['uuid']?.toString();
  return null;
}

// ── Event log ─────────────────────────────────────────────────────────────

enum LogKind { info, me, system, error }

class LogLine {
  LogLine(this.text, this.kind) : at = DateTime.now();
  final String text;
  final LogKind kind;
  final DateTime at;
}

/// Rolling event log, newest at the bottom — the JS demo's `.log` panel.
class EventLog extends StatelessWidget {
  const EventLog({super.key, required this.lines, this.height = 160});

  final List<LogLine> lines;
  final double height;

  Color _color(BuildContext context, LogKind kind) {
    final scheme = Theme.of(context).colorScheme;
    return switch (kind) {
      LogKind.me => scheme.primary,
      LogKind.system => scheme.tertiary,
      LogKind.error => scheme.error,
      LogKind.info => scheme.onSurfaceVariant,
    };
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: height,
      width: double.infinity,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(8),
      ),
      child: ListView.builder(
        reverse: true,
        itemCount: lines.length,
        itemBuilder: (context, i) {
          final line = lines[lines.length - 1 - i];
          final ts =
              '${line.at.hour.toString().padLeft(2, '0')}:${line.at.minute.toString().padLeft(2, '0')}:${line.at.second.toString().padLeft(2, '0')}';
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 1),
            child: Text(
              '[$ts] ${line.text}',
              style: TextStyle(
                fontFamily: 'monospace',
                fontSize: 12,
                color: _color(context, line.kind),
              ),
            ),
          );
        },
      ),
    );
  }
}

/// Mixin giving a State a capped [log] list plus [logLine].
mixin EventLogHost<T extends StatefulWidget> on State<T> {
  final List<LogLine> log = [];

  void logLine(String text, [LogKind kind = LogKind.info]) {
    if (!mounted) return;
    setState(() {
      log.add(LogLine(text, kind));
      if (log.length > 200) log.removeAt(0);
    });
  }
}

// ── Member list ───────────────────────────────────────────────────────────

class MemberList extends StatelessWidget {
  const MemberList({
    super.key,
    required this.members,
    required this.selfUuid,
    this.selfName,
  });

  final List<dynamic> members;
  final String selfUuid;
  final String? selfName;

  @override
  Widget build(BuildContext context) {
    if (members.isEmpty) {
      return Text('No one here yet',
          style: Theme.of(context).textTheme.bodySmall);
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final m in members)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 3),
            child: Row(
              children: [
                Icon(Icons.circle,
                    size: 9, color: Theme.of(context).colorScheme.primary),
                const SizedBox(width: 8),
                Text(memberUser(m)),
                if (memberUuid(m) == selfUuid ||
                    (selfName != null && memberUser(m) == selfName))
                  Text('  (you)',
                      style: Theme.of(context).textTheme.bodySmall),
              ],
            ),
          ),
      ],
    );
  }
}

// ── Connection pill ───────────────────────────────────────────────────────

class ConnPill extends StatelessWidget {
  const ConnPill({super.key, required this.connected, this.label});

  final bool connected;
  final String? label;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.circle,
              size: 9,
              color: connected ? scheme.primary : scheme.onSurfaceVariant),
          const SizedBox(width: 6),
          Text(label ?? (connected ? 'connected' : 'connecting…'),
              style: Theme.of(context).textTheme.labelMedium),
        ],
      ),
    );
  }
}

// ── Section card ──────────────────────────────────────────────────────────

class DemoCard extends StatelessWidget {
  const DemoCard({super.key, required this.child, this.title});

  final Widget child;
  final String? title;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            if (title != null) ...[
              Text(title!, style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 12),
            ],
            child,
          ],
        ),
      ),
    );
  }
}
