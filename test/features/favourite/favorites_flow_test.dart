import 'dart:async';

import 'package:currency/app.dart';
import 'package:currency/core/di/injection.dart';
import 'package:currency/core/error/failures.dart';
import 'package:currency/features/auth/presentation/bloc/auth_session_cubit.dart';
import 'package:currency/features/currency/domain/entities/currency.dart';
import 'package:currency/features/favourite/domain/entities/asset_item.dart';
import 'package:currency/features/profile/domain/entities/user_profile.dart';
import 'package:currency/features/shell/presentation/widgets/floating_nav_bar.dart';
import 'package:dartz/dartz.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/fake_auth_repository.dart';
import '../../helpers/fake_currency_repository.dart';
import '../../helpers/fake_favorite_repository.dart';
import '../../helpers/fake_profile_repository.dart';

const aedCurrency = Currency(id: 'id-aed', code: 'AED', name: 'UAE Dirham');

class _GatedFavorites extends FakeFavoriteRepository {
  final gate = Completer<void>();

  @override
  Future<Either<Failure, AssetQuote>> getQuote({
    required String symbol,
    required String quote,
  }) async {
    await gate.future;
    return super.getQuote(symbol: symbol, quote: quote);
  }
}

void main() {
  late FakeAuthRepository auth;
  late FakeProfileRepository profile;
  late FakeFavoriteRepository favorites;

  setUp(() async {
    await sl.reset();
    await init();
    profile = await useFakeProfileRepository();
    await useFakeCurrencyRepository();
    favorites = await useFakeFavoriteRepository();
    profile.result = Right(
      UserProfile(email: 'me@example.com', baseCurrency: aedCurrency),
    );
    favorites
      ..favorites = [inrAsset, usdAsset, eurAsset, aedAsset]
      ..assets = [inrAsset, usdAsset, eurAsset, aedAsset, btcAsset, goldAsset]
      ..quotes = {
        'INR': const AssetQuote(rate: 0.038306, change: 0.000018),
        'USD': const AssetQuote(rate: 3.67, change: 0.0002),
        'EUR': const AssetQuote(rate: 4.22, change: 0.004105),
        'AED': const AssetQuote(rate: 1, change: 0),
        'SAR': const AssetQuote(rate: 0.977797, change: -0.000181),
        'BTC': const AssetQuote(rate: 250000.5, change: 1200.25),
        'XAU': const AssetQuote(rate: 9000, change: -15),
      };
    auth = FakeAuthRepository()..restored = fakeSession;
  });

  Future<void> openApp(WidgetTester tester) async {
    tester.view.physicalSize = const Size(800, 1800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final session = AuthSessionCubit(auth);
    await tester.pumpWidget(CurrencyApp(sessionCubit: session));
    await session.start();
    await tester.pump();
  }

  Future<void> openFavorites(WidgetTester tester) async {
    await openApp(tester);
    await tester.tap(
      find.descendant(
        of: find.byType(FloatingNavBar),
        matching: find.text('Favorites'),
      ),
    );
    await tester.pumpAndSettle();
  }

  group('the list', () {
    testWidgets('nothing loads until the tab is opened', (tester) async {
      await openApp(tester);
      expect(favorites.loads, 0);
      expect(favorites.quoteRequests, isEmpty);

      await tester.tap(
        find.descendant(
          of: find.byType(FloatingNavBar),
          matching: find.text('Favorites'),
        ),
      );
      await tester.pumpAndSettle();

      expect(favorites.loads, 1);
    });

    testWidgets('shows each favorite with its price and 24h change', (
      tester,
    ) async {
      await openFavorites(tester);

      // Title (and the tab label).
      expect(find.text('Favorites'), findsNWidgets(2));
      for (final code in ['INR', 'USD', 'EUR', 'AED']) {
        expect(find.text(code), findsOneWidget, reason: code);
      }
      expect(find.text('Indian Rupee'), findsOneWidget);
      expect(find.text('United Arab Emirates Dirham'), findsOneWidget);

      expect(find.text('0.038306AED'), findsOneWidget);
      expect(find.text('+0.000018AED'), findsOneWidget);
      expect(find.text('3.67AED'), findsOneWidget);
      expect(find.text('+0.0002AED'), findsOneWidget);
      expect(find.text('4.22AED'), findsOneWidget);
      expect(find.text('+0.004105AED'), findsOneWidget);
      expect(find.text('1.00AED'), findsOneWidget);
      expect(find.text('0.00AED'), findsOneWidget);
    });

    testWidgets('prices are requested in the base currency', (tester) async {
      await openFavorites(tester);
      expect(
        favorites.quoteRequests,
        unorderedEquals(['INR/AED', 'USD/AED', 'EUR/AED', 'AED/AED']),
      );
    });

    testWidgets('without a base currency prices are in USD', (tester) async {
      profile.result = const Right(UserProfile(email: 'me@example.com'));
      await openFavorites(tester);

      expect(favorites.quoteRequests, contains('INR/USD'));
      expect(find.text('3.67USD'), findsOneWidget);
    });

    testWidgets('if the profile cannot be loaded, prices fall back to USD', (
      tester,
    ) async {
      profile.result = const Left(NetworkFailure());
      await openFavorites(tester);

      expect(favorites.quoteRequests, contains('EUR/USD'));
      expect(find.text('INR'), findsOneWidget);
    });

    testWidgets('a falling price is red, a rising one green', (tester) async {
      favorites.favorites = [fiat('SAR', 'Saudi Riyal'), usdAsset];
      await openFavorites(tester);

      Color colorOf(String text) =>
          tester.widget<Text>(find.text(text)).style!.color!;
      expect(find.text('-0.000181AED'), findsOneWidget);
      expect(
        colorOf('-0.000181AED').toARGB32(),
        isNot(colorOf('+0.0002AED').toARGB32()),
      );
      expect(colorOf('+0.0002AED'), colorOf('+0.0002AED'));
    });

    testWidgets('crypto and commodities get a badge instead of a flag', (
      tester,
    ) async {
      favorites.favorites = [btcAsset, goldAsset];
      await openFavorites(tester);

      expect(find.text('Bitcoin'), findsOneWidget);
      expect(find.text('Gold'), findsOneWidget);
      expect(find.text('250000.50AED'), findsOneWidget);
      expect(find.text('+1200.25AED'), findsOneWidget);
      expect(find.text('-15.00AED'), findsOneWidget);
    });

    testWidgets(
      'a price that fails shows a dash and does not block the others',
      (tester) async {
        favorites.quoteFailures.add('EUR');
        await openFavorites(tester);

        expect(find.text('—'), findsOneWidget);
        expect(find.text('3.67AED'), findsOneWidget);
      },
    );

    testWidgets('the list shows at once; prices fill in afterwards', (
      tester,
    ) async {
      final gated = _GatedFavorites()
        ..favorites = [inrAsset, usdAsset]
        ..quotes = favorites.quotes;
      await installFavoriteRepository(gated);

      await openApp(tester);
      await tester.tap(
        find.descendant(
          of: find.byType(FloatingNavBar),
          matching: find.text('Favorites'),
        ),
      );
      await tester.pump();
      await tester.pump();

      // Rows are there, prices are still loading.
      expect(find.text('INR'), findsOneWidget);
      expect(find.text('USD'), findsOneWidget);
      expect(find.text('···'), findsNWidgets(2));
      expect(find.text('3.67AED'), findsNothing);

      gated.gate.complete();
      await tester.pumpAndSettle();

      expect(find.text('···'), findsNothing);
      expect(find.text('3.67AED'), findsOneWidget);
      expect(find.text('0.038306AED'), findsOneWidget);
    });

    testWidgets('empty state offers to add a favorite', (tester) async {
      favorites.favorites = [];
      await openFavorites(tester);

      expect(find.text('No favorites yet'), findsOneWidget);
      expect(find.widgetWithText(FilledButton, 'Add favorite'), findsOneWidget);
    });

    testWidgets('a failed load shows the message and Retry', (tester) async {
      favorites.favoritesFailure = const NetworkFailure();
      await openFavorites(tester);
      expect(find.text(const NetworkFailure().message), findsOneWidget);

      favorites.favoritesFailure = null;
      await tester.tap(find.text('Retry'));
      await tester.pumpAndSettle();
      expect(find.text('INR'), findsOneWidget);
    });

    testWidgets('pull to refresh reloads the list and prices', (tester) async {
      await openFavorites(tester);
      expect(favorites.loads, 1);

      favorites.favorites = [btcAsset];
      await tester.fling(
        find.byType(ListView).first,
        const Offset(0, 500),
        1000,
      );
      await tester.pumpAndSettle();

      expect(favorites.loads, 2);
      expect(find.text('Bitcoin'), findsOneWidget);
      expect(find.text('INR'), findsNothing);
    });

    testWidgets('a failed refresh keeps the rows and says why', (tester) async {
      await openFavorites(tester);

      favorites.favoritesFailure = const NetworkFailure();
      await tester.fling(
        find.byType(ListView).first,
        const Offset(0, 500),
        1000,
      );
      await tester.pumpAndSettle();

      expect(find.text('INR'), findsOneWidget);
      expect(find.text(const NetworkFailure().message), findsOneWidget);
    });
  });

  group('adding', () {
    Future<void> openPicker(WidgetTester tester) async {
      await openFavorites(tester);
      await tester.tap(find.byIcon(Icons.add_rounded));
      await tester.pumpAndSettle();
    }

    Finder inSheet(Finder f) =>
        find.descendant(of: find.byType(BottomSheet), matching: f);

    testWidgets('the picker lists assets that are not favorites yet', (
      tester,
    ) async {
      await openPicker(tester);

      expect(inSheet(find.text('Add favorite')), findsOneWidget);
      expect(inSheet(find.text('Bitcoin')), findsOneWidget);
      expect(inSheet(find.text('Gold')), findsOneWidget);
      // Already favorites: not offered again.
      expect(inSheet(find.text('Euro')), findsNothing);
      expect(inSheet(find.text('Indian Rupee')), findsNothing);
    });

    testWidgets('search filters by symbol or name', (tester) async {
      await openPicker(tester);

      await tester.enterText(inSheet(find.byType(TextField)), 'bit');
      await tester.pump();
      expect(inSheet(find.text('Bitcoin')), findsOneWidget);
      expect(inSheet(find.text('Gold')), findsNothing);

      await tester.enterText(inSheet(find.byType(TextField)), 'xau');
      await tester.pump();
      expect(inSheet(find.text('Gold')), findsOneWidget);

      await tester.enterText(inSheet(find.byType(TextField)), 'zzz');
      await tester.pump();
      expect(inSheet(find.text('Nothing found')), findsOneWidget);
    });

    testWidgets('tapping an asset adds it, closes the sheet and prices it', (
      tester,
    ) async {
      await openPicker(tester);

      await tester.tap(inSheet(find.text('Bitcoin')));
      await tester.pumpAndSettle();

      expect(favorites.added, ['id-BTC']);
      expect(find.byType(BottomSheet), findsNothing);
      expect(find.text('Bitcoin'), findsOneWidget);
      expect(find.text('250000.50AED'), findsOneWidget);
      // Newest first.
      expect(
        tester.getTopLeft(find.text('Bitcoin')).dy,
        lessThan(tester.getTopLeft(find.text('INR')).dy),
      );
    });

    testWidgets('a failed add says why and changes nothing', (tester) async {
      favorites.addFailure = const ServerFailure('Asset not found');
      await openPicker(tester);

      await tester.tap(inSheet(find.text('Bitcoin')));
      await tester.pumpAndSettle();

      expect(find.byType(BottomSheet), findsNothing);
      expect(find.text("Couldn't add BTC. Asset not found"), findsOneWidget);
      expect(find.text('Bitcoin'), findsNothing);
    });

    testWidgets('when everything is already a favorite the picker says so', (
      tester,
    ) async {
      favorites.assets = [inrAsset, usdAsset];
      await openPicker(tester);

      expect(
        inSheet(find.text('Everything is already in your favorites')),
        findsOneWidget,
      );
    });

    testWidgets('a failed asset load offers Retry', (tester) async {
      favorites.assetsFailure = const NetworkFailure();
      await openPicker(tester);
      expect(
        inSheet(find.text(const NetworkFailure().message)),
        findsOneWidget,
      );

      favorites.assetsFailure = null;
      await tester.tap(inSheet(find.text('Retry')));
      await tester.pumpAndSettle();
      expect(inSheet(find.text('Bitcoin')), findsOneWidget);
    });

    testWidgets('closing the picker adds nothing', (tester) async {
      await openPicker(tester);
      await tester.tap(find.byIcon(Icons.close_rounded));
      await tester.pumpAndSettle();
      expect(favorites.added, isEmpty);
    });
  });

  group('removing', () {
    testWidgets('swiping a row left removes the favorite', (tester) async {
      await openFavorites(tester);

      await tester.drag(find.text('EUR'), const Offset(-700, 0));
      await tester.pumpAndSettle();

      expect(favorites.removed, ['id-EUR']);
      expect(find.text('EUR'), findsNothing);
      expect(find.text('INR'), findsOneWidget);
    });

    testWidgets('a failed removal keeps the row and says why', (tester) async {
      favorites.removeFailure = const NetworkFailure();
      await openFavorites(tester);

      await tester.drag(find.text('EUR'), const Offset(-700, 0));
      await tester.pumpAndSettle();

      expect(favorites.removed, ['id-EUR']);
      expect(find.text('EUR'), findsOneWidget);
      expect(
        find.text("Couldn't remove EUR. ${const NetworkFailure().message}"),
        findsOneWidget,
      );
    });

    testWidgets('removing the last favorite shows the empty state', (
      tester,
    ) async {
      favorites.favorites = [usdAsset];
      await openFavorites(tester);

      await tester.drag(find.text('USD'), const Offset(-700, 0));
      await tester.pumpAndSettle();

      expect(find.text('No favorites yet'), findsOneWidget);
    });
  });
}
