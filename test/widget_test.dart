import 'package:flutter_test/flutter_test.dart';

import 'package:crownex/main.dart';
import 'package:crownex/screens/onboarding_screen.dart';
import 'package:crownex/screens/splash_screen.dart';

void main() {
  testWidgets('Crownex splash transitions to onboarding', (tester) async {
    await tester.pumpWidget(const CrownexApp());

    expect(find.byType(SplashScreen), findsOneWidget);

    await tester.pump(const Duration(milliseconds: 2300));
    await tester.pumpAndSettle();

    expect(find.byType(OnboardingScreen), findsOneWidget);
    expect(find.text('Get Started'), findsOneWidget);
    expect(find.textContaining('Transact Crypto'), findsOneWidget);
  });
}
