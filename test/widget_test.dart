import 'package:currency/app.dart';
import 'package:currency/core/di/injection.dart';
import 'package:currency/features/auth/presentation/bloc/auth_session_cubit.dart';
import 'package:currency/features/shell/presentation/widgets/floating_nav_bar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers/fake_auth_repository.dart';
import 'helpers/fake_profile_repository.dart';

void main() {
  testWidgets('shows the four home tabs', (WidgetTester tester) async {
    await sl.reset();
    await init();
    final profile = await useFakeProfileRepository();
    final repo = FakeAuthRepository()..restored = fakeSession;
    final session = AuthSessionCubit(repo);
    await tester.pumpWidget(CurrencyApp(sessionCubit: session));
    await session.start();
    await tester.pump();

    // Nothing loads at launch: the profile is fetched on first visit to Settings.
    expect(profile.calls, 0);

    expect(find.text('Converter'), findsWidgets);
    expect(find.text('Browse'), findsWidgets);
    expect(find.text('Favorites'), findsWidgets);
    expect(find.text('Settings'), findsWidgets);

    await tester.tap(find.widgetWithText(FilledButton, 'Convert'));
    await tester.pumpAndSettle();
    expect(find.text('1.00 USD = 0.92 EUR'), findsOneWidget);

    final navigationBar = find.byType(FloatingNavBar);
    await tester.tap(
      find.descendant(of: navigationBar, matching: find.text('Browse')),
    );
    await tester.pumpAndSettle();
    expect(tester.widget<FloatingNavBar>(navigationBar).currentIndex, 1);
    expect(find.text('Currency list will appear here.'), findsOneWidget);

    await tester.tap(
      find.descendant(of: navigationBar, matching: find.text('Favorites')),
    );
    await tester.pumpAndSettle();
    expect(tester.widget<FloatingNavBar>(navigationBar).currentIndex, 2);
    expect(find.text('Saved currencies will appear here.'), findsOneWidget);

    await tester.tap(
      find.descendant(of: navigationBar, matching: find.text('Settings')),
    );
    await tester.pumpAndSettle();
    expect(tester.widget<FloatingNavBar>(navigationBar).currentIndex, 3);
    expect(profile.calls, 1);
    for (final row in [
      'Notifications',
      'Your currency',
      'Start screen',
      'Feedback',
      'Rate app',
      'Share app',
    ]) {
      expect(find.text(row), findsOneWidget, reason: row);
    }
    expect(find.text('Premium'), findsNothing);
  });
}
