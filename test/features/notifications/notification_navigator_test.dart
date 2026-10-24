import 'package:currency/features/auth/domain/entities/auth_session.dart';
import 'package:currency/features/auth/presentation/bloc/auth_session_cubit.dart';
import 'package:currency/features/notifications/domain/entities/notification_destination.dart';
import 'package:currency/features/notifications/presentation/bloc/notification_navigator.dart';
import 'package:currency/features/profile/domain/usecases/get_profile.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/fake_auth_repository.dart';
import '../../helpers/fake_profile_repository.dart';
import '../../helpers/fake_push_message_source.dart';

const _alertId = '3f2b8c1e-9d4a-4e0b-8a57-1c2d3e4f5a6b';
const _tap = {'type': 'PRICE_ALERT', 'alertId': _alertId};

void main() {
  late FakeAuthRepository auth;
  late FakePushMessageSource source;
  late AuthSessionCubit session;
  late NotificationNavigator navigator;

  Future<void> pumpApp(WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        navigatorKey: navigator.navigatorKey,
        home: const Scaffold(body: Text('home')),
      ),
    );
    await navigator.start(session);
    await tester.pump();
  }

  Future<void> startWith(
    WidgetTester tester, {
    required AuthSession? restored,
  }) async {
    auth.restored = restored;
    await session.start();
    await pumpApp(tester);
  }

  setUp(() {
    auth = FakeAuthRepository();
    source = FakePushMessageSource();
    session = AuthSessionCubit(auth);
    navigator = NotificationNavigator(
      source,
      GetProfile(FakeProfileRepository()),
      routeBuilder: (destination, _) => MaterialPageRoute<void>(
        builder: (_) => Scaffold(
          body: Text(
            'alerts:${(destination as PriceAlertsDestination).alertId}',
          ),
        ),
      ),
    );
  });

  tearDown(() async {
    await navigator.dispose();
    await session.close();
  });

  testWidgets('a tap while signed in opens the destination', (tester) async {
    await startWith(tester, restored: fakeSession);

    source.taps.add(_tap);
    await tester.pumpAndSettle();

    expect(find.text('alerts:$_alertId'), findsOneWidget);
  });

  testWidgets('the notification that launched the app is opened', (
    tester,
  ) async {
    source.initial = _tap;
    await startWith(tester, restored: fakeSession);
    await tester.pumpAndSettle();

    expect(find.text('alerts:$_alertId'), findsOneWidget);
  });

  testWidgets('an unsupported or invalid payload does nothing', (tester) async {
    await startWith(tester, restored: fakeSession);

    source.taps.add({'type': 'UNKNOWN'});
    source.taps.add({'type': 'PRICE_ALERT', 'alertId': 'not-a-uuid'});
    await tester.pumpAndSettle();

    expect(find.text('home'), findsOneWidget);
  });

  testWidgets('a repeated tap does not open the screen twice', (tester) async {
    await startWith(tester, restored: fakeSession);

    source.taps.add(_tap);
    source.taps.add(_tap);
    await tester.pumpAndSettle();

    expect(find.text('alerts:$_alertId'), findsOneWidget);
    navigator.navigatorKey.currentState!.pop();
    await tester.pumpAndSettle();
    expect(find.text('home'), findsOneWidget);
  });

  testWidgets('a tap while signed out opens after sign-in', (tester) async {
    await startWith(tester, restored: null);

    source.taps.add(_tap);
    await tester.pumpAndSettle();
    expect(find.text('alerts:$_alertId'), findsNothing);

    auth.sessions.add(fakeSession);
    await tester.pumpAndSettle();

    expect(find.text('alerts:$_alertId'), findsOneWidget);
  });

  testWidgets('waits for the base currency to be chosen', (tester) async {
    await startWith(
      tester,
      restored: fakeSession.copyWith(requiresBaseCurrency: true),
    );

    source.taps.add(_tap);
    await tester.pumpAndSettle();
    expect(find.text('alerts:$_alertId'), findsNothing);

    auth.sessions.add(fakeSession);
    await tester.pumpAndSettle();

    expect(find.text('alerts:$_alertId'), findsOneWidget);
  });

  testWidgets('a held destination is dropped on logout', (tester) async {
    await startWith(
      tester,
      restored: fakeSession.copyWith(requiresBaseCurrency: true),
    );
    source.taps.add(_tap);
    await tester.pumpAndSettle();

    // Logout, then someone else signs in.
    auth.sessions.add(null);
    await tester.pumpAndSettle();
    auth.sessions.add(fakeSession);
    await tester.pumpAndSettle();

    expect(find.text('alerts:$_alertId'), findsNothing);
    expect(find.text('home'), findsOneWidget);
  });
}
