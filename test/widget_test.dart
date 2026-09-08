import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:piesocket_flutter_demo/identity.dart';
import 'package:piesocket_flutter_demo/main.dart';

void main() {
  testWidgets('app boots into the display-name gate', (tester) async {
    await tester.pumpWidget(const PieSocketDemoApp());
    expect(find.text('Pick a display name'), findsOneWidget);
  });

  testWidgets('entering a name reveals the home screen', (tester) async {
    await tester.pumpWidget(const PieSocketDemoApp());
    await tester.enterText(find.byType(TextField), 'alice');
    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();
    expect(find.text('PieSocket Flutter Demo'), findsOneWidget);
    expect(find.text('Chatroom'), findsOneWidget);
  });

  test('IdentityGate is exported', () {
    expect(IdentityGate, isNotNull);
  });
}
