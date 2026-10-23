import 'dart:ui' show PlatformDispatcher;

import 'package:flutter/material.dart';
import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';
import 'firebase_options.dart';

import 'package:stride/theme/app_theme.dart';
import 'package:stride/theme/theme_provider.dart';
import 'package:stride/features/splash/splash_screen.dart';

import 'package:shared_preferences/shared_preferences.dart';
import 'package:stride/core/providers/preferences_provider.dart';
import 'package:stride/features/sync/providers/sync_engine.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  await _setUpCrashReporting();
  await _setUpAppCheck();
  await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  final prefs = await SharedPreferences.getInstance();
  await migrateUnitsToProfile(prefs);

  runApp(
    ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
      ],
      child: const MyApp(),
    ),
  );
}

/// Release builds report crashes to Crashlytics; debug builds keep the
/// normal console output and send nothing.
Future<void> _setUpCrashReporting() async {
  await FirebaseCrashlytics.instance.setCrashlyticsCollectionEnabled(!kDebugMode);
  if (kDebugMode) return;
  FlutterError.onError = FirebaseCrashlytics.instance.recordFlutterFatalError;
  PlatformDispatcher.instance.onError = (error, stack) {
    FirebaseCrashlytics.instance.recordError(error, stack, fatal: true);
    return true;
  };
}

/// Attests that Firestore/Auth requests come from the real app. Has no
/// effect until enforcement is turned on in the Firebase console; debug
/// builds use the debug provider (register its token in the console).
Future<void> _setUpAppCheck() async {
  try {
    await FirebaseAppCheck.instance.activate(
      providerAndroid: kDebugMode ? const AndroidDebugProvider() : const AndroidPlayIntegrityProvider(),
      providerApple:
          kDebugMode ? const AppleDebugProvider() : const AppleAppAttestWithDeviceCheckFallbackProvider(),
    );
  } catch (e) {
    // Never block startup on attestation; enforcement (if on) will reject
    // requests and sync will retry later.
    debugPrint('App Check activation failed: $e');
  }
}

class MyApp extends ConsumerWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeModeProvider);
    // Created eagerly so its login listener exists before anyone signs in.
    ref.watch(syncEngineProvider);

    return MaterialApp(
      title: 'Stride by Moops',
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: themeMode,
      home: const SplashScreen(),
    );
  }
}
