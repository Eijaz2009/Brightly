import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:device_preview/device_preview.dart';
import 'package:google_fonts/google_fonts.dart';

import 'firebase_options.dart';
import 'screens/splash_screen.dart';
import 'services/app_style.dart';
import 'services/data_migration.dart';

import 'package:provider/provider.dart';
import 'services/app_state.dart';
import 'providers/scholarship_provider.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  if (Firebase.apps.isEmpty) {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  }

  // Restore persisted preferences (theme / locale) before the first frame.
  await AppState.load();

  // Seed the catalogue without blocking startup. Previously this was awaited,
  // so a slow/offline Firestore froze the app on a blank native splash.
  // It also requires admin rights, so for anonymous users it is a no-op.
  unawaited(DataMigration.uploadDefaultScholarships());

  runApp(
    DevicePreview(
      enabled: true,
      builder: (context) => MultiProvider(
        providers: [
          ChangeNotifierProvider(create: (_) => ScholarshipProvider()),
        ],
        child: const MyApp(),
      ),
    ),
  );
}

/// Fire-and-forget helper (avoids pulling in dart:async just for this).
void unawaited(Future<void> future) {
  future.catchError((Object e) {
    debugPrint('Background task failed: $e');
  });
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: AppState.themeNotifier,
      builder: (_, mode, _) {
        return ValueListenableBuilder<Locale>(
          valueListenable: AppState.localeNotifier,
          builder: (context, locale, _) {
            return MaterialApp(
              title: 'Brightly',
              debugShowCheckedModeBanner: false,
              themeMode: mode,
              theme: buildTheme(Brightness.light),
              darkTheme: buildTheme(Brightness.dark),
              supportedLocales: const [Locale('en'), Locale('id')],
              locale: locale,
              localeResolutionCallback: (deviceLocale, supported) {
                final code = deviceLocale?.languageCode;
                return supported.firstWhere(
                  (l) => l.languageCode == code,
                  orElse: () => const Locale('en'),
                );
              },
              builder: DevicePreview.appBuilder,
              home: const SplashScreen(),
            );
          },
        );
      },
    );
  }
}

/// Shared theme for both brightnesses so the two branches can never drift.
ThemeData buildTheme(Brightness brightness) {
  final dark = brightness == Brightness.dark;

  final canvas = dark ? AppStyle.inkDark : AppStyle.cream;
  final surface = dark ? AppStyle.paperDark : AppStyle.paper;
  final border = dark ? AppStyle.lineDark : const Color(0xFFD5D5D5);
  final onSurface = dark ? const Color(0xFFE8E8E8) : AppStyle.ink;
  final muted = dark ? const Color(0xFF777777) : const Color(0xFF666666);

  final scheme = ColorScheme.fromSeed(
    seedColor: AppStyle.spark,
    primary: AppStyle.spark,
    secondary: AppStyle.ink,
    tertiary: AppStyle.success,
    surface: surface,
    brightness: brightness,
  );

  final base = GoogleFonts.plusJakartaSansTextTheme();

  return ThemeData(
    useMaterial3: true,
    brightness: brightness,
    colorScheme: scheme,
    scaffoldBackgroundColor: canvas,
    canvasColor: canvas,
    textTheme: base.apply(bodyColor: onSurface, displayColor: onSurface),
    dividerTheme: DividerThemeData(color: border, thickness: 1, space: 1),
    splashFactory: InkSparkle.splashFactory,

    appBarTheme: AppBarTheme(
      backgroundColor: canvas,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: true,
      iconTheme: IconThemeData(color: onSurface),
      titleTextStyle: GoogleFonts.plusJakartaSans(
        color: onSurface,
        fontSize: 17,
        fontWeight: FontWeight.w800,
      ),
    ),

    // 1px separators instead of the default heavy divider, so grouped content
    // reads as one card rather than a stack of rows.
    cardTheme: CardThemeData(
      color: surface,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppStyle.rMd),
        side: BorderSide(color: border, width: 1),
      ),
    ),

    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: dark ? AppStyle.sandDark : AppStyle.ink,      contentTextStyle: GoogleFonts.plusJakartaSans(
        color: Colors.white,
        fontWeight: FontWeight.w600,
        fontSize: 13,
      ),
      shape: const StadiumBorder(),
      insetPadding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
    ),

    dialogTheme: DialogThemeData(
      backgroundColor: surface,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppStyle.rLg),
      ),
      titleTextStyle: GoogleFonts.plusJakartaSans(
        color: onSurface,
        fontSize: 18,
        fontWeight: FontWeight.w800,
      ),
      contentTextStyle: GoogleFonts.plusJakartaSans(
        color: muted,
        fontSize: 14,
        height: 1.55,
      ),
    ),

    bottomSheetTheme: BottomSheetThemeData(
      backgroundColor: surface,
      surfaceTintColor: Colors.transparent,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppStyle.rXl)),
      ),
    ),

    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: dark ? Colors.white.withValues(alpha: 0.04) : surface,
      isDense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
      hintStyle: GoogleFonts.plusJakartaSans(
        color: muted.withValues(alpha: 0.8),
        fontSize: 14,
        fontWeight: FontWeight.w500,
      ),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppStyle.rMd),
        borderSide: BorderSide(color: border, width: 1.4),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppStyle.rMd),
        borderSide: BorderSide(color: border, width: 1.4),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppStyle.rMd),
        borderSide: const BorderSide(color: AppStyle.spark, width: 1.8),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppStyle.rMd),
        borderSide: const BorderSide(color: AppStyle.danger, width: 1.6),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppStyle.rMd),
        borderSide: const BorderSide(color: AppStyle.danger, width: 2),
      ),
    ),

    // Brand blue is the only filled action colour, so "primary" is unambiguous
    // across every screen.
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: AppStyle.spark,
        foregroundColor: Colors.white,
        minimumSize: const Size.fromHeight(52),
        shape: const StadiumBorder(),
        textStyle: GoogleFonts.plusJakartaSans(
          fontWeight: FontWeight.w800,
          fontSize: 15,
        ),
      ),
    ),

    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        elevation: 0,
        backgroundColor: AppStyle.spark,
        foregroundColor: Colors.white,
        minimumSize: const Size.fromHeight(52),
        shape: const StadiumBorder(),
        textStyle: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w800),
      ),
    ),

    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        minimumSize: const Size.fromHeight(52),
        foregroundColor: onSurface,
        side: BorderSide(color: border, width: 1.4),
        shape: const StadiumBorder(),
        textStyle: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700),
      ),
    ),

    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: AppStyle.spark,
        textStyle: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700),
      ),
    ),

    switchTheme: SwitchThemeData(
      thumbColor: WidgetStateProperty.resolveWith(
        (states) => states.contains(WidgetState.selected)
            ? Colors.black
            : (dark ? Colors.white70 : Colors.white),
      ),
      trackColor: WidgetStateProperty.resolveWith(
        (states) => states.contains(WidgetState.selected)
            ? AppStyle.spark.withValues(alpha: 0.6)
            : (dark ? const Color(0xFF1A1A1A) : const Color(0xFFD0D0D0)),
      ),
      trackOutlineColor: WidgetStateProperty.all(Colors.transparent),
    ),

    listTileTheme: ListTileThemeData(
      iconColor: muted,
      textColor: onSurface,
      titleTextStyle: GoogleFonts.plusJakartaSans(
        fontSize: 14.5,
        fontWeight: FontWeight.w700,
        color: onSurface,
      ),
      subtitleTextStyle: GoogleFonts.plusJakartaSans(
        fontSize: 12,
        fontWeight: FontWeight.w500,
        color: muted,
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppStyle.rMd),
      ),
    ),

    tooltipTheme: TooltipThemeData(
      decoration: BoxDecoration(
        color: dark ? AppStyle.sandDark : AppStyle.ink,
        borderRadius: BorderRadius.circular(AppStyle.rSm),
      ),
      textStyle: GoogleFonts.plusJakartaSans(
        color: Colors.white,
        fontSize: 11.5,
        fontWeight: FontWeight.w600,
      ),
    ),

    progressIndicatorTheme: const ProgressIndicatorThemeData(
      color: AppStyle.spark,
      linearTrackColor: AppStyle.sand,
      circularTrackColor: AppStyle.sand,
    ),

    pageTransitionsTheme: const PageTransitionsTheme(
      builders: <TargetPlatform, PageTransitionsBuilder>{
        TargetPlatform.android: PredictiveBackPageTransitionsBuilder(),
        TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
      },
    ),
  );
}
