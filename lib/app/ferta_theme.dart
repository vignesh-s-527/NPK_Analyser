import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

abstract final class FertaColors {
  static const forest = Color(0xff173f35);
  static const forestDeep = Color(0xff10342b);
  static const leaf = Color(0xff4c7c55);
  static const leafLight = Color(0xffe4efdf);
  static const lime = Color(0xffd8e8a8);
  static const canvas = Color(0xfff5f6f0);
  static const surface = Color(0xffffffff);
  static const ink = Color(0xff1d2924);
  static const muted = Color(0xff68766d);
  static const line = Color(0xffe0e6de);
  static const warning = Color(0xff996515);
  static const warningLight = Color(0xfffff2d8);
  static const error = Color(0xffa53c32);
  static const errorLight = Color(0xffffe7e3);
  static const success = Color(0xff2f6b45);
}

abstract final class FertaSpace {
  static const xs = 4.0;
  static const sm = 8.0;
  static const md = 12.0;
  static const lg = 16.0;
  static const xl = 24.0;
  static const xxl = 32.0;
}

abstract final class FertaRadius {
  static const sm = 12.0;
  static const md = 18.0;
  static const lg = 24.0;
  static const pill = 999.0;
}

ThemeData buildFertaTheme() {
  final colors = ColorScheme.fromSeed(
    seedColor: FertaColors.forest,
    brightness: Brightness.light,
  ).copyWith(
    primary: FertaColors.forest,
    onPrimary: Colors.white,
    secondary: FertaColors.leaf,
    onSecondary: Colors.white,
    tertiary: FertaColors.lime,
    surface: FertaColors.surface,
    onSurface: FertaColors.ink,
    error: FertaColors.error,
  );
  final base = ThemeData(
    colorScheme: colors,
    useMaterial3: true,
    scaffoldBackgroundColor: FertaColors.canvas,
    visualDensity: VisualDensity.standard,
    splashFactory: InkSparkle.splashFactory,
  );
  final text = base.textTheme;
  return base.copyWith(
    textTheme: text.copyWith(
      headlineLarge: text.headlineLarge?.copyWith(
        color: FertaColors.ink,
        fontWeight: FontWeight.w700,
      ),
      headlineMedium: text.headlineMedium?.copyWith(
        color: FertaColors.ink,
        fontWeight: FontWeight.w700,
      ),
      headlineSmall: text.headlineSmall?.copyWith(
        color: FertaColors.ink,
        fontWeight: FontWeight.w700,
      ),
      titleLarge: text.titleLarge?.copyWith(
        color: FertaColors.ink,
        fontWeight: FontWeight.w700,
      ),
      titleMedium: text.titleMedium?.copyWith(
        color: FertaColors.ink,
        fontWeight: FontWeight.w600,
      ),
      bodyLarge: text.bodyLarge?.copyWith(
        color: FertaColors.ink,
        height: 1.42,
      ),
      bodyMedium: text.bodyMedium?.copyWith(
        color: FertaColors.muted,
        height: 1.4,
      ),
      labelLarge: text.labelLarge?.copyWith(fontWeight: FontWeight.w600),
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: FertaColors.canvas,
      foregroundColor: FertaColors.ink,
      surfaceTintColor: Colors.transparent,
      centerTitle: false,
      elevation: 0,
      scrolledUnderElevation: 0,
      titleTextStyle: TextStyle(
        color: FertaColors.ink,
        fontSize: 20,
        fontWeight: FontWeight.w700,
      ),
    ),
    cardTheme: CardThemeData(
      color: FertaColors.surface,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      margin: const EdgeInsets.only(bottom: FertaSpace.md),
      shape: RoundedRectangleBorder(
        side: const BorderSide(color: FertaColors.line),
        borderRadius: BorderRadius.circular(FertaRadius.md),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: FertaColors.surface,
      contentPadding: const EdgeInsets.symmetric(
        horizontal: FertaSpace.lg,
        vertical: FertaSpace.md,
      ),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(FertaRadius.sm),
        borderSide: const BorderSide(color: FertaColors.line),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(FertaRadius.sm),
        borderSide: const BorderSide(color: FertaColors.line),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(FertaRadius.sm),
        borderSide: const BorderSide(color: FertaColors.leaf, width: 1.6),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(FertaRadius.sm),
        borderSide: const BorderSide(color: FertaColors.error),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        minimumSize: const Size(48, 52),
        padding: const EdgeInsets.symmetric(horizontal: FertaSpace.xl),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(FertaRadius.sm),
        ),
        textStyle: const TextStyle(fontWeight: FontWeight.w600),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        minimumSize: const Size(48, 50),
        padding: const EdgeInsets.symmetric(horizontal: FertaSpace.lg),
        side: const BorderSide(color: FertaColors.line),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(FertaRadius.sm),
        ),
        textStyle: const TextStyle(fontWeight: FontWeight.w600),
      ),
    ),
    navigationBarTheme: NavigationBarThemeData(
      height: 72,
      backgroundColor: FertaColors.surface,
      surfaceTintColor: Colors.transparent,
      indicatorColor: FertaColors.leafLight,
      elevation: 0,
      labelTextStyle: WidgetStateProperty.resolveWith((states) => TextStyle(
            fontSize: 12,
            fontWeight: states.contains(WidgetState.selected)
                ? FontWeight.w700
                : FontWeight.w500,
            color: states.contains(WidgetState.selected)
                ? FertaColors.forest
                : FertaColors.muted,
          )),
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: FertaColors.forestDeep,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(FertaRadius.sm),
      ),
      contentTextStyle: const TextStyle(color: Colors.white),
    ),
    dividerTheme: const DividerThemeData(
      color: FertaColors.line,
      thickness: 1,
      space: FertaSpace.xl,
    ),
    pageTransitionsTheme: const PageTransitionsTheme(
      builders: {
        TargetPlatform.android: FadeUpwardsPageTransitionsBuilder(),
        TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
        TargetPlatform.linux: FadeUpwardsPageTransitionsBuilder(),
        TargetPlatform.macOS: CupertinoPageTransitionsBuilder(),
        TargetPlatform.windows: FadeUpwardsPageTransitionsBuilder(),
      },
    ),
  );
}
