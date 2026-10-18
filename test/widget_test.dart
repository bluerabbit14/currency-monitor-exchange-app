import 'package:currency/app.dart';
import 'package:currency/core/di/injection.dart';
import 'package:currency/features/auth/presentation/bloc/auth_session_cubit.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers/fake_auth_repository.dart';

void main() {
  testWidgets('shows the four home tabs', (WidgetTester tester) async {
    await sl.reset();
    await init();
    final repo = FakeAuthRepository()..restored = fakeSession;
    final session = AuthSessionCubit(repo);
    await tester.pumpWidget(CurrencyApp(sessionCubit: session));
    await session.start();
    await tester.pump();

    expect(find.text('Converter'), findsWidgets);
    expect(find.text('Browse'), findsWidgets);
    expect(find.text('Favourites'), findsWidgets);
    expect(find.text('Settings'), findsWidgets);

    await tester.tap(find.widgetWithText(FilledButton, 'Convert'));
    await tester.pumpAndSettle();
    expect(find.text('1.00 USD = 0.92 EUR'), findsOneWidget);

    final navigationBar = find.byType(NavigationBar);
    await tester.tap(
      find.descendant(of: navigationBar, matching: find.text('Browse')),
    );
    await tester.pumpAndSettle();
    expect(tester.widget<NavigationBar>(navigationBar).selectedIndex, 1);
    expect(find.text('Currency list will appear here.'), findsOneWidget);

    await tester.tap(
      find.descendant(of: navigationBar, matching: find.text('Favourites')),
    );
    await tester.pumpAndSettle();
    expect(tester.widget<NavigationBar>(navigationBar).selectedIndex, 2);
    expect(find.text('Saved currencies will appear here.'), findsOneWidget);

    await tester.tap(
      find.descendant(of: navigationBar, matching: find.text('Settings')),
    );
    await tester.pumpAndSettle();
    expect(tester.widget<NavigationBar>(navigationBar).selectedIndex, 3);
    expect(find.text('App preferences will appear here.'), findsOneWidget);
  });
}
