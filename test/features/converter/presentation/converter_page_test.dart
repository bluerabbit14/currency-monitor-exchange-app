import 'package:currency/core/di/injection.dart';
import 'package:currency/features/converter/domain/entities/conversion.dart';
import 'package:currency/features/converter/presentation/pages/converter_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../helpers/fake_converter_repository.dart';
import '../../../helpers/fake_favorite_repository.dart';

void main() {
  late FakeConverterRepository converter;

  setUp(() async {
    await sl.reset();
    await init();
    converter = await useFakeConverterRepository();
    await useFakeFavoriteRepository();
    converter.session = ConverterSession(
      assets: [inrAsset, usdAsset],
      activeSymbol: 'INR',
    );
  });

  Future<void> open(WidgetTester tester) async {
    tester.view.physicalSize = const Size(800, 1800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(const MaterialApp(home: ConverterPage()));
    await tester.pumpAndSettle();
  }

  Future<void> press(WidgetTester tester, String key) async {
    await tester.tap(find.byKey(ValueKey('key-$key')));
    await tester.pump();
  }

  testWidgets('typing shows the amount on the active row and converts the '
      'others', (tester) async {
    await open(tester);
    expect(find.text('INR'), findsOneWidget);
    expect(find.text('USD'), findsOneWidget);

    await press(tester, '1');
    await press(tester, '2');
    await press(tester, '+');
    await press(tester, '3');
    // The active row shows what was typed; the fake prices every pair at 1.
    expect(find.text('12+3'), findsOneWidget);
    expect(find.text('15'), findsOneWidget);

    await press(tester, '=');
    expect(find.text('15'), findsNWidgets(2));
    expect(converter.session?.expression, '15');
  });

  testWidgets('tapping a row makes it the one typed into', (tester) async {
    await open(tester);
    await press(tester, '7');
    await tester.tap(find.text('USD'));
    await tester.pumpAndSettle();
    await press(tester, '1');
    expect(converter.session?.activeSymbol, 'USD');
    // 7 carried over to USD, then a 1 typed after it.
    expect(find.text('71'), findsNWidgets(2));
  });

  testWidgets('Clear empties the list', (tester) async {
    await open(tester);
    await tester.tap(find.byIcon(Icons.more_horiz));
    await tester.pumpAndSettle();
    expect(find.text('Add Currency'), findsOneWidget);
    await tester.tap(find.text('Clear'));
    await tester.pumpAndSettle();
    expect(find.text('No currencies yet'), findsOneWidget);
    expect(converter.session?.assets, isEmpty);
  });
}
