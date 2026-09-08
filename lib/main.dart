import 'package:flutter/material.dart';

import 'identity.dart';
import 'screens/home_screen.dart';

void main() => runApp(const PieSocketDemoApp());

class PieSocketDemoApp extends StatefulWidget {
  const PieSocketDemoApp({super.key});

  @override
  State<PieSocketDemoApp> createState() => _PieSocketDemoAppState();
}

class _PieSocketDemoAppState extends State<PieSocketDemoApp> {
  final _username = ValueNotifier<String>('');

  @override
  void dispose() {
    _username.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = ColorScheme.fromSeed(
      seedColor: const Color(0xFF7C5CFF),
      brightness: Brightness.dark,
    );
    return Identity(
      notifier: _username,
      child: MaterialApp(
        title: 'PieSocket Flutter Demo',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          colorScheme: scheme,
          useMaterial3: true,
          cardTheme: CardThemeData(
            elevation: 0,
            color: scheme.surfaceContainer,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: BorderSide(color: scheme.outlineVariant),
            ),
          ),
          inputDecorationTheme: const InputDecorationTheme(
            border: OutlineInputBorder(),
            isDense: true,
          ),
        ),
        home: const IdentityGate(child: HomeScreen()),
      ),
    );
  }
}
