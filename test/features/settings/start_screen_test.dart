import 'package:currency/app.dart';
import 'package:currency/core/di/injection.dart';
import 'package:currency/features/auth/presentation/bloc/auth_session_cubit.dart';
import 'package:currency/features/browse/presentation/pages/browse_page.dart';
import 'package:currency/features/converter/presentation/pages/converter_page.dart';
import 'package:currency/features/favourite/presentation/pages/favourite_page.dart';
import 'package:currency/features/settings/data/datasources/start_screen_local_data_source.dart';
import 'package:currency/features/settings/data/repositories/start_screen_repository_impl.dart';
import 'package:currency/features/settings/domain/entities/start_screen.dart';
import 'package:currency/features/settings/presentation/bloc/start_screen_cubit.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../helpers/fake_converter_repository.dart';

import '../../helpers/fake_auth_repository.dart';
import '../../helpers/fake_currency_repository.dart';
import '../../helpers/fake_favorite_repository.dart';
import '../../helpers/fake_profile_repository.dart';

void main() {
  group('storage', () {
    setUp(() => SharedPreferences.setMockInitialValues({}));

    StartScreenRepositoryImpl repo() =>
        const StartScreenRepositoryImpl(StartScreenLocalDataSource());

    test('defaults to the converter', () async {
      expect(await repo().getStartScreen(), StartScreen.converter);
    });

    test('a saved choice survives a restart', () async {
      await repo().setStartScreen(StartScreen.favorites);

      // A new repository and cubit stand in for the next app launch.
      final cubit = StartScreenCubit(repo());
      expect(cubit.state, StartScreen.converter);
      await cubit.load();
      expect(cubit.state, StartScreen.favorites);
    });

    test('an unknown saved value falls back to the converter', () async {
      SharedPreferences.setMockInitialValues({'start_screen_v1': 'nonsense'});
      expect(await repo().getStartScreen(), StartScreen.converter);
    });

    test('select applies at once and saves', () async {
      final cubit = StartScreenCubit(repo());
      await cubit.select(StartScreen.browse);
      expect(cubit.state, StartScreen.browse);
      expect(await repo().getStartScreen(), StartScreen.browse);
    });
  });

  group('app', () {
    late FakeAuthRepository auth;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      TestWidgetsFlutterBinding.ensureInitialized()
          .platformDispatcher
          .accessibilityFeaturesTestValue = const FakeAccessibilityFeatures(
        disableAnimations: true,
      );
      await sl.reset();
      await init();
      await useFakeConverterRepository();
      await useFakeProfileRepository();
      await useFakeCurrencyRepository();
      await useFakeFavoriteRepository();
      auth = FakeAuthRepository()..restored = fakeSession;
    });

    Future<void> launch(WidgetTester tester) async {
      tester.view.physicalSize = const Size(800, 1800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      // The real app loads the saved choice before runApp.
      await sl<StartScreenCubit>().load();
      final session = AuthSessionCubit(auth);
      await tester.pumpWidget(CurrencyApp(sessionCubit: session));
      await session.start();
      await tester.pumpAndSettle();
    }

    testWidgets('opens on the converter by default', (tester) async {
      await launch(tester);
      expect(find.byType(ConverterPage), findsOneWidget);
    });

    testWidgets('opens on the saved start screen', (tester) async {
      SharedPreferences.setMockInitialValues({'start_screen_v1': 'favorites'});
      await launch(tester);
      expect(find.byType(FavouritePage), findsOneWidget);
      expect(find.byType(ConverterPage), findsNothing);
    });

    testWidgets('Settings shows the choice and lets the user change it', (
      tester,
    ) async {
      await launch(tester);
      await tester.tap(find.text('Settings').last);
      await tester.pumpAndSettle();
      expect(find.text('Start screen'), findsOneWidget);
      expect(find.text('Converter'), findsWidgets);

      await tester.tap(find.text('Start screen'));
      await tester.pumpAndSettle();
      expect(find.text('Convert currencies instantly'), findsOneWidget);
      expect(find.text('Explore all currencies and crypto'), findsOneWidget);
      expect(find.text('Quick access to your picks'), findsOneWidget);

      await tester.tap(find.text('Browse').last);
      await tester.pumpAndSettle();

      // The sheet closed, the row shows the new choice and it is saved.
      expect(find.text('Quick access to your picks'), findsNothing);
      expect(sl<StartScreenCubit>().state, StartScreen.browse);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('start_screen_v1'), 'browse');
      expect(find.byType(BrowsePage), findsNothing); // not opened now
    });
  });
}
