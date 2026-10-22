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

      expect(find.text('AED 0.038306'), findsOneWidget);
      expect(find.text('+AED 0.000018'), findsOneWidget);
      expect(find.text('AED 3.67'), findsOneWidget);
      expect(find.text('+AED 0.0002'), findsOneWidget);
      expect(find.text('AED 4.22'), findsOneWidget);
      expect(find.text('+AED 0.004105'), findsOneWidget);
      expect(find.text('AED 1.00'), findsOneWidget);
      expect(find.text('AED 0.00'), findsOneWidget);
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
      expect(find.text(r'$3.67'), findsOneWidget);
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
      expect(find.text('-AED 0.000181'), findsOneWidget);
      expect(
        colorOf('-AED 0.000181').toARGB32(),
        isNot(colorOf('+AED 0.0002').toARGB32()),
      );
      expect(colorOf('+AED 0.0002'), colorOf('+AED 0.0002'));
    });

    testWidgets('crypto and commodities get a badge instead of a flag', (
      tester,
    ) async {
      favorites.favorites = [btcAsset, goldAsset];
      await openFavorites(tester);

      expect(find.text('Bitcoin'), findsOneWidget);
      expect(find.text('Gold'), findsOneWidget);
      expect(find.text('AED 250,000.50'), findsOneWidget);
      expect(find.text('+AED 1,200.25'), findsOneWidget);
      expect(find.text('-AED 15.00'), findsOneWidget);
    });

    testWidgets(
      'a price that fails shows a dash and does not block the others',
      (tester) async {
        favorites.quoteFailures.add('EUR');
        await openFavorites(tester);

        expect(find.text('—'), findsOneWidget);
        expect(find.text('AED 3.67'), findsOneWidget);
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
      expect(find.text('AED 3.67'), findsNothing);

      gated.gate.complete();
      await tester.pumpAndSettle();

      expect(find.text('···'), findsNothing);
      expect(find.text('AED 3.67'), findsOneWidget);
      expect(find.text('AED 0.038306'), findsOneWidget);
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

    testWidgets('the sheet has Done, search, tabs and a check per favorite', (
      tester,
    ) async {
      await openPicker(tester);

      expect(inSheet(find.text('Add to Favorites')), findsOneWidget);
      expect(inSheet(find.text('Done')), findsOneWidget);
      expect(inSheet(find.text('Search...')), findsOneWidget);
      expect(inSheet(find.text('Currency')), findsOneWidget);
      expect(inSheet(find.text('Crypto')), findsOneWidget);
      expect(inSheet(find.text('Commodities')), findsOneWidget);
      // The Currency tab lists every currency, favorites included.
      expect(inSheet(find.text('Euro')), findsOneWidget);
      expect(inSheet(find.text('Bitcoin')), findsNothing);
      // INR, USD, EUR and AED are favorites.
      expect(inSheet(find.byIcon(Icons.check_rounded)), findsNWidgets(4));
    });

    testWidgets(
      'only the asset list scrolls; the header, search and tabs stay',
      (tester) async {
        favorites.assets = [
          ...favorites.assets,
          for (var i = 0; i < 40; i++) fiat('Q$i', 'Extra $i'),
        ];
        await openPicker(tester);
        final titleTop = tester
            .getTopLeft(inSheet(find.text('Add to Favorites')))
            .dy;
        final tabsTop = tester.getTopLeft(inSheet(find.text('Crypto'))).dy;
        final firstRowTop = tester
            .getTopLeft(inSheet(find.text('Indian Rupee')))
            .dy;

        await tester.drag(
          inSheet(find.byType(ListView)),
          const Offset(0, -400),
        );
        await tester.pumpAndSettle();

        expect(
          tester.getTopLeft(inSheet(find.text('Add to Favorites'))).dy,
          titleTop,
        );
        expect(tester.getTopLeft(inSheet(find.text('Crypto'))).dy, tabsTop);
        expect(
          inSheet(find.text('Indian Rupee')),
          findsNothing,
        ); // scrolled away
        expect(firstRowTop, greaterThan(tabsTop));
      },
    );

    testWidgets('the tabs switch between currencies, crypto and commodities', (
      tester,
    ) async {
      await openPicker(tester);

      await tester.tap(inSheet(find.text('Crypto')));
      await tester.pumpAndSettle();
      expect(inSheet(find.text('Bitcoin')), findsOneWidget);
      expect(inSheet(find.text('Euro')), findsNothing);
      expect(inSheet(find.text('Gold')), findsNothing);

      await tester.tap(inSheet(find.text('Commodities')));
      await tester.pumpAndSettle();
      expect(inSheet(find.text('Gold')), findsOneWidget);
      expect(inSheet(find.text('Bitcoin')), findsNothing);
    });

    testWidgets('search filters within the selected tab', (tester) async {
      await openPicker(tester);

      await tester.enterText(inSheet(find.byType(TextField)), 'eur');
      await tester.pump();
      expect(inSheet(find.text('Euro')), findsOneWidget);
      expect(inSheet(find.text('US Dollar')), findsNothing);

      // Bitcoin is on another tab.
      await tester.enterText(inSheet(find.byType(TextField)), 'bit');
      await tester.pump();
      expect(inSheet(find.text('Nothing found')), findsOneWidget);
      await tester.tap(inSheet(find.text('Crypto')));
      await tester.pumpAndSettle();
      expect(inSheet(find.text('Bitcoin')), findsOneWidget);
    });

    testWidgets('tapping an asset favorites it and the sheet stays open', (
      tester,
    ) async {
      await openPicker(tester);
      await tester.tap(inSheet(find.text('Crypto')));
      await tester.pumpAndSettle();
      expect(inSheet(find.byIcon(Icons.check_rounded)), findsNothing);

      await tester.tap(find.byKey(const ValueKey('favorite-toggle-id-BTC')));
      await tester.pumpAndSettle();

      expect(favorites.added, ['id-BTC']);
      expect(find.byType(BottomSheet), findsOneWidget);
      expect(inSheet(find.byIcon(Icons.check_rounded)), findsOneWidget);
    });

    testWidgets('tapping the row text does nothing; only the check toggles', (
      tester,
    ) async {
      await openPicker(tester);

      await tester.tap(inSheet(find.text('Euro')));
      await tester.pumpAndSettle();

      expect(favorites.added, isEmpty);
      expect(favorites.removed, isEmpty);
      expect(inSheet(find.byIcon(Icons.check_rounded)), findsNWidgets(4));
    });

    testWidgets('tapping a favorite removes it', (tester) async {
      await openPicker(tester);

      await tester.tap(find.byKey(const ValueKey('favorite-toggle-id-EUR')));
      await tester.pumpAndSettle();

      expect(favorites.removed, ['id-EUR']);
      expect(inSheet(find.byIcon(Icons.check_rounded)), findsNWidgets(3));
    });

    testWidgets('Done closes the sheet and the list shows the new favorite', (
      tester,
    ) async {
      await openPicker(tester);
      await tester.tap(inSheet(find.text('Crypto')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('favorite-toggle-id-BTC')));
      await tester.pumpAndSettle();

      await tester.tap(inSheet(find.text('Done')));
      await tester.pumpAndSettle();

      expect(find.byType(BottomSheet), findsNothing);
      expect(find.text('Bitcoin'), findsOneWidget);
      expect(find.text('AED 250,000.50'), findsOneWidget);
      // Newest first.
      expect(
        tester.getTopLeft(find.text('Bitcoin')).dy,
        lessThan(tester.getTopLeft(find.text('INR')).dy),
      );
    });

    testWidgets('Done without changes does not reload the list', (
      tester,
    ) async {
      await openPicker(tester);
      final loadsBefore = favorites.loads;

      await tester.tap(inSheet(find.text('Done')));
      await tester.pumpAndSettle();

      expect(find.byType(BottomSheet), findsNothing);
      expect(favorites.loads, loadsBefore);
    });

    testWidgets('a failed add puts the check back and says why', (
      tester,
    ) async {
      favorites.addFailure = const ServerFailure('Asset not found');
      await openPicker(tester);
      await tester.tap(inSheet(find.text('Crypto')));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const ValueKey('favorite-toggle-id-BTC')));
      await tester.pumpAndSettle();

      expect(find.byType(BottomSheet), findsOneWidget);
      expect(inSheet(find.byIcon(Icons.check_rounded)), findsNothing);
      // Shown by both the page and the sheet scaffolds.
      expect(find.text("Couldn't update. Asset not found"), findsWidgets);
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
      expect(inSheet(find.text('Euro')), findsOneWidget);
    });
  });

  testWidgets('only the list scrolls; the title and add button stay put', (
    tester,
  ) async {
    favorites.favorites = [
      for (var i = 0; i < 30; i++) fiat('Q$i', 'Extra $i'),
    ];
    await openFavorites(tester);
    final title = find.byWidgetPredicate(
      (w) => w is Text && w.data == 'Favorites' && w.style?.fontSize == 24,
    );
    final titleTop = tester.getTopLeft(title).dy;
    final addTop = tester.getTopLeft(find.byIcon(Icons.add_rounded)).dy;

    await tester.drag(find.byType(ListView).first, const Offset(0, -600));
    await tester.pumpAndSettle();

    expect(tester.getTopLeft(title).dy, titleTop);
    expect(tester.getTopLeft(find.byIcon(Icons.add_rounded)).dy, addTop);
    expect(find.text('Q0'), findsNothing); // scrolled out of view
  });

  group('removing', () {
    Future<void> slide(WidgetTester tester, String symbol) async {
      await tester.drag(find.text(symbol), const Offset(-300, 0));
      await tester.pumpAndSettle();
    }

    testWidgets('sliding a row only reveals Alert and Delete', (tester) async {
      await openFavorites(tester);
      expect(find.text('Delete'), findsNothing);

      await slide(tester, 'EUR');

      expect(find.text('Alert'), findsOneWidget);
      expect(find.text('Delete'), findsOneWidget);
      expect(favorites.removed, isEmpty);
      expect(find.text('EUR'), findsOneWidget);
    });

    testWidgets('Delete asks first and cancelling removes nothing', (
      tester,
    ) async {
      await openFavorites(tester);
      await slide(tester, 'EUR');

      await tester.tap(find.text('Delete'));
      await tester.pumpAndSettle();
      expect(find.text('Remove from favorites?'), findsOneWidget);
      expect(favorites.removed, isEmpty);

      await tester.tap(find.widgetWithText(TextButton, 'Cancel'));
      await tester.pumpAndSettle();

      expect(favorites.removed, isEmpty);
      expect(find.text('EUR'), findsOneWidget);
    });

    testWidgets('confirming calls the delete service and drops the row', (
      tester,
    ) async {
      await openFavorites(tester);
      await slide(tester, 'EUR');

      await tester.tap(find.text('Delete'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Delete'));
      await tester.pumpAndSettle();

      expect(favorites.removed, ['id-EUR']);
      expect(find.text('EUR'), findsNothing);
      expect(find.text('INR'), findsOneWidget);
    });

    testWidgets('a failed removal keeps the row and says why', (tester) async {
      favorites.removeFailure = const NetworkFailure();
      await openFavorites(tester);
      await slide(tester, 'EUR');

      await tester.tap(find.text('Delete'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Delete'));
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
      await slide(tester, 'USD');

      await tester.tap(find.text('Delete'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Delete'));
      await tester.pumpAndSettle();

      expect(find.text('No favorites yet'), findsOneWidget);
    });

    testWidgets('Alert opens the editor for that asset in the base currency', (
      tester,
    ) async {
      await openFavorites(tester);
      await slide(tester, 'EUR');

      await tester.tap(find.text('Alert'));
      await tester.pumpAndSettle();

      expect(find.byType(BottomSheet), findsOneWidget);
      expect(
        find.descendant(
          of: find.byType(BottomSheet),
          matching: find.textContaining('EUR'),
        ),
        findsWidgets,
      );
      expect(favorites.removed, isEmpty);
    });
  });
}
