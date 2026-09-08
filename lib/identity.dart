import 'package:flutter/material.dart';

/// The display name other participants see for this device — the Flutter
/// equivalent of the JS demo's `#username` URL hash. Held for the session;
/// changeable from the home screen so you can run two devices/simulators as
/// two different people in the same room.
class Identity extends InheritedNotifier<ValueNotifier<String>> {
  const Identity({
    super.key,
    required ValueNotifier<String> super.notifier,
    required super.child,
  });

  static ValueNotifier<String> of(BuildContext context) {
    final widget = context.dependOnInheritedWidgetOfExactType<Identity>();
    assert(widget != null, 'No Identity in the widget tree');
    return widget!.notifier!;
  }

  static String nameOf(BuildContext context) => of(context).value;
}

/// Blocks the app behind a "pick a display name" screen until one is set,
/// then shows [child]. Mirrors the JS demo always prompting on load.
class IdentityGate extends StatelessWidget {
  const IdentityGate({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final name = Identity.of(context);
    return ValueListenableBuilder<String>(
      valueListenable: name,
      builder: (context, value, _) {
        if (value.isNotEmpty) return child;
        return _NamePrompt(onSubmit: (n) => name.value = n);
      },
    );
  }
}

class _NamePrompt extends StatefulWidget {
  const _NamePrompt({required this.onSubmit});

  final ValueChanged<String> onSubmit;

  @override
  State<_NamePrompt> createState() => _NamePromptState();
}

class _NamePromptState extends State<_NamePrompt> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    final value = _controller.text.trim();
    if (value.isEmpty) return;
    widget.onSubmit(value);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 380),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text('Pick a display name',
                    style: Theme.of(context).textTheme.headlineSmall),
                const SizedBox(height: 8),
                Text(
                  'Other participants will see you by this name. Run a second '
                  'device with a different name to simulate another person — or '
                  'open the JavaScript demo in a browser.',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                const SizedBox(height: 20),
                TextField(
                  controller: _controller,
                  autofocus: true,
                  textInputAction: TextInputAction.go,
                  decoration: const InputDecoration(
                    labelText: 'Display name',
                    hintText: 'e.g. alice',
                    border: OutlineInputBorder(),
                  ),
                  onSubmitted: (_) => _submit(),
                ),
                const SizedBox(height: 16),
                FilledButton(onPressed: _submit, child: const Text('Continue')),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Small dialog to change the display name mid-session.
Future<void> showChangeNameDialog(BuildContext context) async {
  final name = Identity.of(context);
  final controller = TextEditingController(text: name.value);
  final result = await showDialog<String>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Change display name'),
      content: TextField(
        controller: controller,
        autofocus: true,
        decoration: const InputDecoration(hintText: 'e.g. bob'),
        onSubmitted: (v) => Navigator.pop(context, v.trim()),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, controller.text.trim()),
          child: const Text('Save'),
        ),
      ],
    ),
  );
  if (result != null && result.isNotEmpty) name.value = result;
}
