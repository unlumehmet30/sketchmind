import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'data/services/auth_service.dart';
import 'data/services/family_settings_service.dart';
import 'data/services/screen_time_service.dart';
import 'presentation/theme/app_theme_controller.dart';
import 'presentation/theme/playful_theme.dart';
import 'router/app_router.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final bootstrapStatus = await _bootstrapApp();
  runApp(SketchMindApp(bootstrapStatus: bootstrapStatus));
}

Future<AppBootstrapStatus> _bootstrapApp() async {
  const envLoaded = true;
  var firebaseReady = false;
  var authReady = false;
  String? startupError;

  try {
    await Firebase.initializeApp();
    FirebaseFirestore.instance.settings = const Settings(
      persistenceEnabled: true,
    );
    firebaseReady = true;
    if (kDebugMode) {
      debugPrint('Firebase initialized');
    }
  } catch (error) {
    startupError ??= 'Firebase başlatılamadı: $error';
    if (kDebugMode) {
      debugPrint('Firebase initialization failed: $error');
    }
  }

  if (firebaseReady) {
    try {
      await AuthService().ensureSignedInAnonymously();
      authReady = true;
    } catch (error) {
      startupError ??= 'Güvenli oturum başlatılamadı: $error';
      if (kDebugMode) {
        debugPrint('Auth initialization failed: $error');
      }
    }
  }

  return AppBootstrapStatus(
    envLoaded: envLoaded,
    firebaseReady: firebaseReady,
    authReady: authReady,
    startupError: startupError,
  );
}

class AppBootstrapStatus {
  const AppBootstrapStatus({
    required this.envLoaded,
    required this.firebaseReady,
    required this.authReady,
    this.startupError,
  });

  const AppBootstrapStatus.readyForTests()
      : envLoaded = true,
        firebaseReady = true,
        authReady = true,
        startupError = null;

  final bool envLoaded;
  final bool firebaseReady;
  final bool authReady;
  final String? startupError;

  bool get canUseCloud => firebaseReady && authReady;
}

class SketchMindApp extends StatefulWidget {
  const SketchMindApp({
    super.key,
    this.bootstrapStatus = const AppBootstrapStatus.readyForTests(),
  });

  final AppBootstrapStatus bootstrapStatus;

  @override
  State<SketchMindApp> createState() => _SketchMindAppState();
}

class _SketchMindAppState extends State<SketchMindApp>
    with WidgetsBindingObserver {
  final AppThemeController _themeController = AppThemeController.instance;
  final ScreenTimeService _screenTimeService = ScreenTimeService();
  final FamilySettingsService _familySettingsService = FamilySettingsService();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    unawaited(_themeController.loadFromStorage());
    unawaited(_screenTimeService.onAppResumed());
    if (widget.bootstrapStatus.canUseCloud) {
      unawaited(_familySettingsService.syncFromCloudAndMerge());
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      unawaited(_screenTimeService.onAppResumed());
      if (widget.bootstrapStatus.canUseCloud) {
        unawaited(_familySettingsService.syncFromCloudAndMerge());
      }
      return;
    }

    if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached ||
        state == AppLifecycleState.hidden) {
      unawaited(_screenTimeService.onAppPaused());
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    unawaited(_screenTimeService.onAppPaused());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.bootstrapStatus.canUseCloud) {
      return MaterialApp(
        title: 'SketchMind',
        debugShowCheckedModeBanner: false,
        home: _StartupErrorScreen(
          message: widget.bootstrapStatus.startupError ??
              'Uygulama güvenli şekilde başlatılamadı.',
        ),
      );
    }

    return ValueListenableBuilder<AppThemePalette>(
      valueListenable: _themeController,
      builder: (context, _, __) {
        final colorScheme = ColorScheme.fromSeed(
          seedColor: PlayfulPalette.sky,
          primary: PlayfulPalette.sky,
          secondary: PlayfulPalette.coral,
          tertiary: PlayfulPalette.grape,
          brightness: Brightness.light,
        );

        return MaterialApp.router(
          title: 'SketchMind',
          debugShowCheckedModeBanner: false,
          theme: ThemeData(
            useMaterial3: true,
            colorScheme: colorScheme,
            scaffoldBackgroundColor: PlayfulPalette.cloud,
            textTheme: GoogleFonts.nunitoTextTheme().copyWith(
              headlineLarge: GoogleFonts.baloo2(
                fontSize: 32,
                fontWeight: FontWeight.w700,
                color: PlayfulPalette.ink,
              ),
              headlineMedium: GoogleFonts.baloo2(
                fontSize: 28,
                fontWeight: FontWeight.w700,
                color: PlayfulPalette.ink,
              ),
              titleLarge: GoogleFonts.baloo2(
                fontSize: 22,
                fontWeight: FontWeight.w700,
                color: PlayfulPalette.ink,
              ),
              bodyLarge: GoogleFonts.nunito(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: const Color(0xFF314865),
              ),
              bodyMedium: GoogleFonts.nunito(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: const Color(0xFF47627E),
              ),
            ),
            appBarTheme: AppBarTheme(
              centerTitle: false,
              elevation: 0,
              backgroundColor: Colors.transparent,
              foregroundColor: colorScheme.onSurface,
              surfaceTintColor: Colors.transparent,
              titleTextStyle: GoogleFonts.baloo2(
                fontSize: 26,
                fontWeight: FontWeight.w700,
                color: PlayfulPalette.ink,
              ),
            ),
            cardTheme: CardThemeData(
              color: PlayfulPalette.card,
              elevation: 6,
              shadowColor: const Color(0x1D4E4A7E),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(22),
                side: const BorderSide(color: Color(0xFFE0DDF7), width: 1.2),
              ),
            ),
            elevatedButtonTheme: ElevatedButtonThemeData(
              style: ElevatedButton.styleFrom(
                backgroundColor: PlayfulPalette.grape,
                foregroundColor: Colors.white,
                minimumSize: const Size(140, 48),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                textStyle: GoogleFonts.nunito(
                  fontWeight: FontWeight.w800,
                  fontSize: 15,
                ),
              ),
            ),
            outlinedButtonTheme: OutlinedButtonThemeData(
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFF3F4F7A),
                side: const BorderSide(color: Color(0xFFB9B8F1), width: 1.2),
                minimumSize: const Size(130, 46),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
            ),
            chipTheme: ChipThemeData(
              backgroundColor: const Color(0xFFF0EEFF),
              selectedColor: const Color(0xFFE5DEFF),
              disabledColor: const Color(0xFFEDEFF2),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(24),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              side: const BorderSide(color: Color(0xFFD4D0F7)),
              labelStyle: GoogleFonts.nunito(
                fontWeight: FontWeight.w700,
                color: const Color(0xFF4F4A8B),
              ),
            ),
            navigationBarTheme: NavigationBarThemeData(
              indicatorColor: const Color(0xFFE8E4FF),
              backgroundColor: Colors.white,
              labelTextStyle: WidgetStateProperty.resolveWith((states) {
                final active = states.contains(WidgetState.selected);
                return GoogleFonts.nunito(
                  fontWeight: active ? FontWeight.w900 : FontWeight.w700,
                  color: active
                      ? const Color(0xFF4B4F9B)
                      : const Color(0xFF6E7799),
                );
              }),
              iconTheme: WidgetStateProperty.resolveWith((states) {
                final active = states.contains(WidgetState.selected);
                return IconThemeData(
                  color: active
                      ? const Color(0xFF4B4F9B)
                      : const Color(0xFF7A84AA),
                  size: active ? 26 : 24,
                );
              }),
            ),
            progressIndicatorTheme: ProgressIndicatorThemeData(
              color: PlayfulPalette.grape,
              linearTrackColor: const Color(0xFFECE9F9),
            ),
            snackBarTheme: SnackBarThemeData(
              behavior: SnackBarBehavior.floating,
              backgroundColor: colorScheme.onSurface,
              contentTextStyle: TextStyle(color: colorScheme.surface),
            ),
          ),
          routerConfig: router,
        );
      },
    );
  }
}

class _StartupErrorScreen extends StatelessWidget {
  const _StartupErrorScreen({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.error_outline, size: 72, color: Colors.red),
                const SizedBox(height: 16),
                const Text(
                  'Başlatma Hatası',
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 8),
                Text(
                  message,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 15),
                ),
                const SizedBox(height: 14),
                const Text(
                  'Lütfen uygulamayı yeniden başlatın ve bağlantı/Firebase ayarlarınızı kontrol edin.',
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
