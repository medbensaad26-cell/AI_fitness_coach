import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:ai_fitness_coach_mobile/app/app.dart';

void main() {
  testWidgets('App renders splash placeholder', (WidgetTester tester) async {
    await tester.pumpWidget(const ProviderScope(child: AiFitnessCoachApp()));

    expect(find.text('AI Fitness Coach'), findsOneWidget);
    expect(find.text('Continue to login'), findsOneWidget);
  });
}
