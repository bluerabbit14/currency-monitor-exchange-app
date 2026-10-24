import 'package:currency/app.dart';
import 'package:currency/core/di/injection.dart';
import 'package:currency/features/auth/presentation/bloc/auth_session_cubit.dart';
import 'package:currency/features/feedback/domain/repositories/feedback_repository.dart';
import 'package:currency/features/shell/presentation/widgets/floating_nav_bar.dart';
import 'package:currency/core/error/failures.dart';
import 'package:dartz/dartz.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/fake_auth_repository.dart';
import '../../helpers/fake_converter_repository.dart';
import '../../helpers/fake_currency_repository.dart';
import '../../helpers/fake_profile_repository.dart';

class _FakeFeedbackRepository implements FeedbackRepository {
  final sent = <(int?, String?)>[];

  @override
  Future<Either<Failure, Unit>> submit({int? rating, String? message}) async {
    sent.add((rating, message));
    return const Right(unit);
  }
}

void main() {
  testWidgets('feedback can be sent again and again', (tester) async {
    await sl.reset();
    await init();
    await useFakeConverterRepository();
    await useFakeProfileRepository();
    await useFakeCurrencyRepository();
    final repo = _FakeFeedbackRepository();
    sl.unregister<FeedbackRepository>();
    sl.registerSingleton<FeedbackRepository>(repo);

    tester.view.physicalSize = const Size(800, 1800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final session = AuthSessionCubit(FakeAuthRepository()..restored = fakeSession);
    await tester.pumpWidget(CurrencyApp(sessionCubit: session));
    await session.start();
    await tester.pump();
    await tester.tap(
      find.descendant(
        of: find.byType(FloatingNavBar),
        matching: find.text('Settings'),
      ),
    );
    await tester.pumpAndSettle();

    for (var i = 1; i <= 3; i++) {
      await tester.tap(find.text('Feedback'));
      await tester.pumpAndSettle();
      expect(find.text('Send feedback'), findsOneWidget, reason: 'open #$i');
      await tester.tap(find.byTooltip('4 stars'));
      await tester.pump();
      await tester.tap(find.text('Submit'));
      await tester.pumpAndSettle();
      expect(find.text('Send feedback'), findsNothing);
    }
    expect(repo.sent.length, 3);
  });
}
