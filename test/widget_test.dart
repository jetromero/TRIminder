// TRIminder widget test for screen time tracking app
//
// This test verifies the basic structure of the TRIminder app

import 'package:flutter_test/flutter_test.dart';

import 'package:triminder/main.dart';

void main() {
  testWidgets('TRIminder app smoke test', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(const TRIminderApp());

    // Verify that login screen shows up
    expect(find.text('TRIminder'), findsOneWidget);
    expect(find.text('Digital Wellness & Screen Time Tracker'), findsOneWidget);
    
    // Verify login form elements exist
    expect(find.text('EVSU Email'), findsOneWidget);
    expect(find.text('Password'), findsOneWidget);
    expect(find.text('Login'), findsOneWidget);
    expect(find.text('Sign Up'), findsOneWidget);
  });

  testWidgets('Login form validation test', (WidgetTester tester) async {
    await tester.pumpWidget(const TRIminderApp());

    // Tap login button without entering data
    await tester.tap(find.text('Login'));
    await tester.pump();

    // Should show validation errors
    expect(find.text('Please enter your email'), findsOneWidget);
    expect(find.text('Please enter your password'), findsOneWidget);
  });
}
