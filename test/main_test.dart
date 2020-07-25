// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility that Flutter provides. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:salesforce_notifications/main.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const String LOGIN_MESSAGE = "Logging in";
  const String LOGOUT_MESSAGE = "Logging out";

  List<MethodCall> logs = <MethodCall>[];

  MethodChannel('flutter.module.com/channelcommunication')
    .setMockMethodCallHandler((MethodCall call) async {
      logs.add(call);
      switch (call.method) {
        case 'login':
          return LOGIN_MESSAGE;
        case 'logout':
          return LOGOUT_MESSAGE;
        default:
          return null;
      }
    });

  tearDown(() async {
    logs.clear();
  });
  testWidgets('Initialization test', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(MaterialApp(home: HomePage()));

    // Verify that our counter starts at 0.
    expect(find.text("Salesforce Time"), findsOneWidget);
  });
  testWidgets('Login sends platform channel', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(MaterialApp(home: HomePage()));

    final loginBtn = find.text("Log in");
    expect(loginBtn, findsOneWidget);

    // Tap the '+' icon and trigger a frame.
    await tester.tap(loginBtn);
    await tester.pumpAndSettle();

    // Verify the login platform event was called
    expect(logs, <Matcher>[
      isMethodCall(
        'login', arguments: null
      )
    ]);
    expect(find.text(LOGIN_MESSAGE), findsOneWidget);
  });
  testWidgets('Logout sends platform channel', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(MaterialApp(home: HomePage()));

    final logoutBtn = find.text("Log Out");
    expect(logoutBtn, findsOneWidget);

    // Tap the '+' icon and trigger a frame.
    await tester.tap(logoutBtn);
    await tester.pumpAndSettle();

    // Verify the login platform event was called
    expect(logs, <Matcher>[
      isMethodCall(
        'logout', arguments: null
      )
    ]);
    expect(find.text(LOGOUT_MESSAGE), findsOneWidget);
  });
}
