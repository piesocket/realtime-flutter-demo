import 'package:flutter/material.dart';

import '../identity.dart';
import 'binary_transfer_screen.dart';
import 'call_many_to_many_screen.dart';
import 'call_one_to_many_screen.dart';
import 'call_one_to_one_screen.dart';
import 'chatroom_screen.dart';

class _Demo {
  const _Demo(this.title, this.blurb, this.tags, this.builder);
  final String title;
  final String blurb;
  final List<String> tags;
  final Widget Function(String username) builder;
}

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  static final _demos = <_Demo>[
    _Demo(
      'Chatroom',
      'Two channels (#general, #random) over one shared socket: switch rooms, '
          'see who\'s online, DM a member, watch a typing indicator.',
      ['multi-channel', 'presence', 'typing', 'C2C'],
      (u) => ChatroomScreen(username: u),
    ),
    _Demo(
      'Binary transfer',
      'Send a small file or image as a raw binary frame and reassemble it on '
          'the other end — v4\'s system::binary framing.',
      ['binary'],
      (u) => BinaryTransferScreen(username: u),
    ),
    _Demo(
      '1:1 call',
      'Two-party PieRTC video/audio call — the simplest calling shape, '
          'audio-only toggle included.',
      ['PieRTC', 'video', 'audio'],
      (u) => CallOneToOneScreen(username: u),
    ),
    _Demo(
      '1:many broadcast',
      'One broadcaster streaming to any number of watchers — a lecture / '
          'livestream shape. Screen sharing included.',
      ['PieRTC', 'broadcast', 'screen share'],
      (u) => CallOneToManyScreen(username: u),
    ),
    _Demo(
      'Many:many call',
      'Full mesh video conference — everyone sees and hears everyone else. '
          'Screen sharing included.',
      ['PieRTC', 'mesh', 'screen share'],
      (u) => CallManyToManyScreen(username: u),
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final name = Identity.nameOf(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('PieSocket Flutter Demo'),
        actions: [
          Center(
            child: Padding(
              padding: const EdgeInsets.only(right: 4),
              child: Text(name, style: Theme.of(context).textTheme.labelLarge),
            ),
          ),
          IconButton(
            tooltip: 'Change display name',
            icon: const Icon(Icons.badge_outlined),
            onPressed: () => showChangeNameDialog(context),
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            'Each screen exercises a different part of the PieSocket v4 SDK '
            'against the public demo cluster. It talks to the JavaScript demo '
            'too — join the same room from a browser and you\'ll see each '
            'other.',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 16),
          for (final demo in _demos) ...[
            Card(
              clipBehavior: Clip.antiAlias,
              child: InkWell(
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => demo.builder(Identity.nameOf(context)),
                  ),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(demo.title,
                          style: Theme.of(context).textTheme.titleMedium),
                      const SizedBox(height: 6),
                      Text(demo.blurb,
                          style: Theme.of(context).textTheme.bodyMedium),
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: [
                          for (final tag in demo.tags)
                            Chip(
                              label: Text(tag),
                              visualDensity: VisualDensity.compact,
                              materialTapTargetSize:
                                  MaterialTapTargetSize.shrinkWrap,
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
          ],
        ],
      ),
    );
  }
}
