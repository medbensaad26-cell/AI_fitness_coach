import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:ai_fitness_coach_mobile/app/app.dart';

void main() {
  testWidgets('App navigates through full user flow', (WidgetTester tester) async {
    await tester.pumpWidget(const ProviderScope(child: AiFitnessCoachApp()));
    await tester.pump();

    // 1. Splash screen
    expect(find.text('AI Fitness Coach'), findsWidgets);
    expect(find.text('Continue to login'), findsOneWidget);

    // Tap "Continue to login"
    await tester.tap(find.text('Continue to login'));
    await tester.pumpAndSettle();

    // 2. Login screen
    expect(find.text('Login'), findsWidgets);
    expect(find.text('Create account'), findsOneWidget);

    // Tap "Create account" -> Register screen
    await tester.tap(find.text('Create account'));
    await tester.pumpAndSettle();

    // 3. Register screen
    expect(find.text('Register'), findsWidgets);
    expect(find.text('Back to login'), findsOneWidget);

    // Tap "Back to login"
    await tester.tap(find.text('Back to login'));
    await tester.pumpAndSettle();

    // Tap "Start onboarding" -> Onboarding screen
    await tester.tap(find.text('Start onboarding'));
    await tester.pumpAndSettle();

    // 4. Onboarding screen
    expect(find.text('Onboarding'), findsWidgets);
    expect(find.text('Finish (placeholder)'), findsOneWidget);

    // Tap "Finish (placeholder)" -> Home screen
    await tester.tap(find.text('Finish (placeholder)'));
    await tester.pumpAndSettle();

    // 5. Home screen
    expect(find.text('Home'), findsWidgets);
    expect(find.text('Open program details'), findsOneWidget);
    expect(find.text('Start workout session'), findsOneWidget);
    expect(find.text('View session history'), findsOneWidget);

    // Tap "Open program details" -> Program details screen
    await tester.tap(find.text('Open program details'));
    await tester.pumpAndSettle();

    // 6. Program details screen
    expect(find.text('Program details'), findsWidgets);
    expect(find.text('Start session'), findsOneWidget);

    // Tap "Back to home"
    await tester.tap(find.text('Back to home'));
    await tester.pumpAndSettle();

    // Tap "Start workout session" -> Active session screen
    await tester.tap(find.text('Start workout session'));
    await tester.pumpAndSettle();

    // 7. Active session screen
    expect(find.text('Active workout'), findsWidgets);

    // Tap "Finish (placeholder)" -> Session history screen
    await tester.tap(find.text('Finish (placeholder)'));
    await tester.pumpAndSettle();

    // 8. Session history screen
    expect(find.text('Session history'), findsWidgets);
    expect(find.text('No session history yet.'), findsOneWidget);

    // Tap "Back to home" -> back home
    await tester.tap(find.text('Back to home'));
    await tester.pumpAndSettle();

    expect(find.text('Home'), findsWidgets);
  });
}
