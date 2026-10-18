import 'package:currency/core/error/failures.dart';
import 'package:currency/features/profile/data/datasources/profile_remote_data_source.dart';
import 'package:currency/features/profile/data/models/user_profile_model.dart';
import 'package:currency/features/profile/data/repositories/profile_repository_impl.dart';
import 'package:currency/features/profile/domain/entities/user_profile.dart';
import 'package:currency/features/profile/domain/usecases/get_profile.dart';
import 'package:currency/features/profile/presentation/bloc/profile_cubit.dart';
import 'package:currency/features/profile/presentation/widgets/profile_header.dart';
import 'package:dartz/dartz.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/auth_fakes.dart';
import '../../helpers/fake_profile_repository.dart';

Future<ProfileCubit> pumpHeader(
  WidgetTester tester,
  FakeProfileRepository repo, {
  bool load = true,
}) async {
  final cubit = ProfileCubit(GetProfile(repo));
  addTearDown(cubit.close);
  if (load) await cubit.load();
  await tester.pumpWidget(
    MaterialApp(
      home: BlocProvider.value(
        value: cubit,
        child: const Scaffold(body: ProfileHeader()),
      ),
    ),
  );
  await tester.pump();
  return cubit;
}

Future<void> pumpProfile(WidgetTester tester, UserProfile profile) =>
    pumpHeader(tester, FakeProfileRepository()..result = Right(profile));

void main() {
  group('UserProfileModel', () {
    test('parses the backend response (null name, image and phone)', () {
      final profile = UserProfileModel.fromJson({
        'id': 'e9b6701d-78aa-4389-aa41-c2cc89fac818',
        'email': '14asifcr7@gmail.com',
        'phoneNumber': null,
        'displayName': null,
        'profileImageUrl': null,
        'currentPlan': {'code': 'FREE', 'features': []},
        'baseCurrency': null,
      });

      expect(profile.email, '14asifcr7@gmail.com');
      expect(profile.displayName, isNull);
      expect(profile.phoneNumber, isNull);
      expect(profile.profileImageUrl, isNull);
    });

    test('treats blank strings as missing and rejects wrong types', () {
      final profile = UserProfileModel.fromJson({
        'email': '  ',
        'phoneNumber': ' +911234567890 ',
        'displayName': '',
      });
      expect(profile.email, isNull);
      expect(profile.phoneNumber, '+911234567890');
      expect(profile.displayName, isNull);

      expect(
        () => UserProfileModel.fromJson({'email': 5}),
        throwsFormatException,
      );
    });

    test('contact prefers email over phone', () {
      expect(
        const UserProfile(email: 'a@b.co', phoneNumber: '+911').contact,
        'a@b.co',
      );
      expect(const UserProfile(phoneNumber: '+911').contact, '+911');
      expect(const UserProfile().contact, isNull);
    });
  });

  group('repository', () {
    test('GETs /users/me and maps the envelope body', () async {
      final adapter = FakeAdapter(
        (_) => ok({
          'email': 'me@example.com',
          'displayName': 'Pat',
          'profileImageUrl': 'https://example.com/p.png',
        }),
      );
      final repo = ProfileRepositoryImpl(
        ProfileRemoteDataSource(clientFor(adapter)),
      );

      final profile = (await repo.getProfile()).getOrElse(() => throw 'x');

      expect(adapter.requests.single.method, 'GET');
      expect(adapter.requests.single.path, '/api/v1/users/me');
      expect(profile.displayName, 'Pat');
      expect(profile.profileImageUrl, 'https://example.com/p.png');
    });

    test('failures map like the auth ones', () async {
      final adapter = FakeAdapter((_) => apiError(503, 'db down'));
      final repo = ProfileRepositoryImpl(
        ProfileRemoteDataSource(clientFor(adapter)),
      );
      expect(
        (await repo.getProfile()).swap().getOrElse(() => throw 'x').message,
        contains('temporarily unavailable'),
      );

      adapter.handler = (o) => throw DioException.connectionError(
        requestOptions: o,
        reason: 'offline',
      );
      expect(
        (await repo.getProfile()).swap().getOrElse(() => throw 'x'),
        const NetworkFailure(),
      );
    });
  });

  group('ProfileHeader', () {
    testWidgets('name + email: shows both, never the phone', (tester) async {
      await pumpProfile(
        tester,
        const UserProfile(
          displayName: 'Pat Person',
          email: 'pat@example.com',
          phoneNumber: '+911234567890',
        ),
      );
      expect(find.text('Pat Person'), findsOneWidget);
      expect(find.text('pat@example.com'), findsOneWidget);
      expect(find.text('+911234567890'), findsNothing);
    });

    testWidgets('no name: email is the single headline', (tester) async {
      await pumpProfile(tester, const UserProfile(email: 'pat@example.com'));
      expect(find.text('pat@example.com'), findsOneWidget);
    });

    testWidgets('phone only: shows the phone number', (tester) async {
      await pumpProfile(
        tester,
        const UserProfile(phoneNumber: '+911234567890'),
      );
      expect(find.text('+911234567890'), findsOneWidget);
    });

    testWidgets('no image url: placeholder, no network image', (tester) async {
      await pumpProfile(tester, const UserProfile(email: 'pat@example.com'));
      expect(find.byIcon(Icons.person_rounded), findsOneWidget);
      expect(find.byType(Image), findsNothing);
    });

    testWidgets('image url that fails to load falls back to the placeholder', (
      tester,
    ) async {
      await pumpProfile(
        tester,
        const UserProfile(
          email: 'pat@example.com',
          profileImageUrl: 'https://example.com/p.png',
        ),
      );
      expect(find.byType(Image), findsOneWidget);
      await tester.pump(const Duration(milliseconds: 100));
      // The test HTTP client always fails.
      expect(find.byIcon(Icons.person_rounded), findsOneWidget);
    });

    testWidgets('non-http image url is ignored', (tester) async {
      await pumpProfile(
        tester,
        const UserProfile(
          email: 'pat@example.com',
          profileImageUrl: 'javascript:alert(1)',
        ),
      );
      expect(find.byType(Image), findsNothing);
    });

    testWidgets('error shows the message and Retry reloads', (tester) async {
      final repo = FakeProfileRepository()
        ..result = const Left(NetworkFailure());
      await pumpHeader(tester, repo);
      expect(find.text(const NetworkFailure().message), findsOneWidget);

      repo.result = const Right(UserProfile(email: 'me@example.com'));
      await tester.tap(find.text('Retry'));
      await tester.pumpAndSettle();

      expect(repo.calls, 2);
      expect(find.text('me@example.com'), findsOneWidget);
    });

    testWidgets('shows a skeleton while loading', (tester) async {
      await pumpHeader(tester, FakeProfileRepository(), load: false);
      expect(find.byType(Text), findsNothing);
    });
  });
}
