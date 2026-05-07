import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fulan_auth_feature/fulan_auth_feature.dart';

import 'package:fulan_auth/main.dart';

void main() {
  testWidgets('Shows sign-in screen by default', (WidgetTester tester) async {
    final repo = MockAuthRepository(sessionStorage: InMemorySessionStorage());
    await tester.pumpWidget(MyApp(authRepository: repo));
    await tester.pump();

    expect(find.text('Sign in to Fulan'), findsOneWidget);
    expect(find.widgetWithText(FilledButton, 'Sign in'), findsOneWidget);
  });
}
