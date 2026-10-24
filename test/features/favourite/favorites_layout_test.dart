import 'package:currency/app.dart';
import 'package:currency/core/di/injection.dart';
import 'package:currency/features/auth/presentation/bloc/auth_session_cubit.dart';
import 'package:currency/features/currency/domain/entities/currency.dart';
import 'package:currency/features/favourite/domain/entities/asset_item.dart';
import 'package:currency/features/profile/domain/entities/user_profile.dart';
import 'package:currency/features/shell/presentation/widgets/floating_nav_bar.dart';
import 'package:dartz/dartz.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/fake_converter_repository.dart';

import '../../helpers/fake_auth_repository.dart';
import '../../helpers/fake_currency_repository.dart';
import '../../helpers/fake_favorite_repository.dart';
import '../../helpers/fake_profile_repository.dart';

/// The favorites list and the add-favorite sheet must not overflow on small /
/// large / landscape screens with large text, long names and long prices.
void main() {
  const sizes = {
    'small phone': Size(320, 568),
    'regular phone': Size(390, 844),
    'landscape': Size(800, 360),
  };

  for (final entry in sizes.entries) {
    for (final textScale in [1.0, 2.0]) {
      testWidgets('favorites: ${entry.key}, text x$textScale', (tester) async {
        await sl.reset();
        await init();
        await useFakeConverterRepository();
        final profile = await useFakeProfileRepository();
        await useFakeCurrencyRepository();
        final favorites = await useFakeFavoriteRepository();
        profile.result = const Right(
          UserProfile(
            email: 'me@example.com',
            baseCurrency: Currency(
              id: 'id-aed',
              code: 'AED',
              name: 'United Arab Emirates Dirham',
            ),
          ),
        );
        const longName = AssetItem(
          id: 'id-long',
          symbol: 'LONGSYMBOL',
          name: 'An Extremely Long Asset Name That Will Never Fit On One Line At All',
          kind: AssetKind.crypto,
        );
        favorites
          ..favorites = [inrAsset, usdAsset, btcAsset, goldAsset, longName]
          ..assets = [
            inrAsset,
            usdAsset,
            btcAsset,
            goldAsset,
            longName,
            eurAsset,
          ]
          ..quotes = {
            'INR': const AssetQuote(rate: 0.038306, change: 0.000018),
            'USD': const AssetQuote(rate: 3.67, change: -0.0002),
            'BTC': const AssetQuote(
              rate: 98765432.123456,
              change: 123456.654321,
            ),
            'XAU': const AssetQuote(rate: 9000, change: -15),
            'LONGSYMBOL': const AssetQuote(
              rate: 123456789.123456,
              change: -98765.4321,
            ),
          };

        tester.view.physicalSize = entry.value;
        tester.view.devicePixelRatio = 1;
        tester.platformDispatcher.textScaleFactorTestValue = textScale;
        addTearDown(() {
          tester.view.reset();
          tester.platformDispatcher.clearAllTestValues();
        });

        final session = AuthSessionCubit(
          FakeAuthRepository()..restored = fakeSession,
        );
        await tester.pumpWidget(CurrencyApp(sessionCubit: session));
        await session.start();
        await tester.pump();
        await tester.tap(
          find.descendant(
            of: find.byType(FloatingNavBar),
            matching: find.byIcon(Icons.favorite_border_rounded),
          ),
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull, reason: 'favorites list');

        // Scroll through the whole list.
        await tester.drag(find.byType(ListView).first, const Offset(0, -2000));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull, reason: 'favorites list, end');
        await tester.drag(find.byType(ListView).first, const Offset(0, 2000));
        await tester.pumpAndSettle();

        // Add-favorite sheet (with the keyboard up).
        await tester.tap(find.byIcon(Icons.add_rounded));
        await tester.pumpAndSettle();
        expect(find.byType(BottomSheet), findsOneWidget);
        expect(tester.takeException(), isNull, reason: 'picker');

        tester.view.viewInsets = const FakeViewPadding(bottom: 280);
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull, reason: 'picker + keyboard');
      });
    }
  }
}
