import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:npk_farmer/app/ferta_theme.dart';
import 'package:npk_farmer/app/npk_app.dart';

void main() {
  testWidgets('launch screen presents farmer and expert entry points',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: buildFertaTheme(),
        home: const LaunchScreen(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('FERTA'), findsOneWidget);
    expect(find.text('Continue as Farmer'), findsOneWidget);
    expect(find.text('Agricultural Expert'), findsOneWidget);
    expect(
        find.text('Works on this device without an account'), findsOneWidget);

    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('ta'),
        supportedLocales: const [Locale('en'), Locale('ta')],
        localizationsDelegates: const [
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        theme: buildFertaTheme(),
        home: const LaunchScreen(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('உங்கள் மண்ணைத் தெளிவாக அறியுங்கள்'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
