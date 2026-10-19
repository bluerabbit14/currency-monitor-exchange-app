import 'package:currency/app.dart';
import 'package:currency/core/di/injection.dart';
import 'package:currency/features/auth/presentation/bloc/auth_session_cubit.dart';
import 'package:currency/features/shell/presentation/widgets/floating_nav_bar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/fake_auth_repository.dart';
import '../../helpers/fake_currency_repository.dart';
import '../../helpers/fake_favorite_repository.dart';
import '../../helpers/fake_profile_repository.dart';

void main() {
  setUp(() async {
    await sl.reset();
    await init();
    await useFakeProfileRepository();
    await useFakeCurrencyRepository();
    await useFakeFavoriteRepository();
  });

  Future<void> open(WidgetTester tester) async {
    final session = AuthSessionCubit(
      FakeAuthRepository()..restored = fakeSession,
    );
    await tester.pumpWidget(CurrencyApp(sessionCubit: session));
    await session.start();
    await tester.pumpAndSettle();
  }

  Finder bar() => find.byType(FloatingNavBar);
  Finder navLabel(String label) =>
      find.descendant(of: bar(), matching: find.text(label));

  /// Bottom edge of the page area: the pages sit in a Positioned.fill-style
  /// box, so this is the bottom of the IndexedStack.
  double contentBottom(WidgetTester tester) =>
      tester.getBottomLeft(find.byType(IndexedStack).first).dy;

  testWidgets('the bar is anchored to the bottom and the pages end above it', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(800, 1600);
    tester.view.devicePixelRatio = 2;
    // A home indicator inset, to prove the bar handles the safe area.
    tester.view.padding = const FakeViewPadding(bottom: 68);
    tester.view.viewPadding = const FakeViewPadding(bottom: 68);
    addTearDown(tester.view.reset);
    await open(tester);

    final screenBottom =
        tester.view.physicalSize.height / tester.view.devicePixelRatio;
    // The bar sits on the screen bottom, inside the safe area.
    expect(tester.getBottomLeft(bar()).dy, closeTo(screenBottom, 0.5));
    // The pages stop exactly where the bar starts: no gap, no overlap.
    expect(contentBottom(tester), closeTo(tester.getTopLeft(bar()).dy, 0.5));
  });

  testWidgets('the bar does not move when switching tabs', (tester) async {
    tester.view.physicalSize = const Size(800, 1600);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);
    await open(tester);
    final rect = tester.getRect(bar());

    for (final tab in ['Browse', 'Favorites', 'Settings', 'Converter']) {
      await tester.tap(navLabel(tab));
      await tester.pumpAndSettle();
      expect(tester.getRect(bar()), rect, reason: tab);
      expect(contentBottom(tester), closeTo(rect.top, 0.5), reason: tab);
      expect(tester.takeException(), isNull, reason: tab);
    }
  });

  testWidgets('with the keyboard up the pages end above the keyboard', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(800, 1600);
    tester.view.devicePixelRatio = 2;
    tester.view.viewInsets = const FakeViewPadding(bottom: 600);
    addTearDown(tester.view.reset);
    await open(tester);

    // 600 physical pixels at 2x: 300 logical.
    final keyboardTop = 800 - 300;
    expect(contentBottom(tester), closeTo(keyboardTop, 0.5));
    expect(tester.takeException(), isNull);
  });
}
