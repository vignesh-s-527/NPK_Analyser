import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:npk_farmer/app/ferta_components.dart';
import 'package:npk_farmer/app/ferta_theme.dart';

void main() {
  testWidgets('nutrient number settles on the stored value', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: buildFertaTheme(),
        home: const Scaffold(
          body: Center(child: FertaAnimatedNumber(value: 18.5)),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('18.5'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('nutrient number respects reduced motion', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: buildFertaTheme(),
        home: MediaQuery(
          data: const MediaQueryData(disableAnimations: true),
          child: const Scaffold(
            body: Center(child: FertaAnimatedNumber(value: 12)),
          ),
        ),
      ),
    );

    expect(find.text('12'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
