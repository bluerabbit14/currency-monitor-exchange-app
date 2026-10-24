import 'package:currency/app.dart';
import 'package:currency/core/di/injection.dart';
import 'package:currency/features/auth/presentation/bloc/auth_session_cubit.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/fake_converter_repository.dart';

import '../helpers/fake_auth_repository.dart';
import '../helpers/fake_currency_repository.dart';
import '../helpers/fake_favorite_repository.dart';
import '../helpers/fake_profile_repository.dart';

/// Renders the screens that are not covered by their own layout tests at
/// small / large / landscape sizes and large text, and fails on any overflow.
void main() {
  const sizes = {
    'small phone': Size(320, 568),
    'regular phone': Size(390, 844),
    'landscape': Size(800, 360),
  };

  for (final entry in sizes.entries) {
    for (final textScale in [1.0, 2.0]) {
      final label = '${entry.key}, text x$textScale';

      testWidgets('new-user currency picker: $label', (tester) async {
        await sl.reset();
        await init();
        await useFakeConverterRepository();
        await useFakeProfileRepository();
        await useFakeCurrencyRepository();
        await useFakeFavoriteRepository();
        final auth = FakeAuthRepository()
          ..restored = fakeSession.copyWith(requiresBaseCurrency: true);

        tester.view.physicalSize = entry.value;
        tester.view.devicePixelRatio = 1;
        tester.platformDispatcher.textScaleFactorTestValue = textScale;
        addTearDown(() {
          tester.view.reset();
          tester.platformDispatcher.clearAllTestValues();
        });

        final session = AuthSessionCubit(auth);
        await tester.pumpWidget(CurrencyApp(sessionCubit: session));
        await session.start();
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull, reason: 'picker, idle');

        await tester.scrollUntilVisible(
          find.text('Euro'),
          100,
          scrollable: find.byType(Scrollable).first,
        );
        await tester.ensureVisible(find.text('Euro'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Euro'));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull, reason: 'picker, selected');
      });

      testWidgets('home + tab bar: $label', (tester) async {
        await sl.reset();
        await init();
        await useFakeConverterRepository();
        await useFakeProfileRepository();
        await useFakeCurrencyRepository();
        await useFakeFavoriteRepository();
        final auth = FakeAuthRepository()..restored = fakeSession;

        tester.view.physicalSize = entry.value;
        tester.view.devicePixelRatio = 1;
        tester.platformDispatcher.textScaleFactorTestValue = textScale;
        addTearDown(() {
          tester.view.reset();
          tester.platformDispatcher.clearAllTestValues();
        });

        final session = AuthSessionCubit(auth);
        await tester.pumpWidget(CurrencyApp(sessionCubit: session));
        await session.start();
        await tester.pumpAndSettle();

        for (final tab in ['Browse', 'Favorites', 'Settings', 'Converter']) {
          await tester.tap(find.text(tab).last);
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull, reason: 'tab $tab');
        }
      });
    }
  }
}
