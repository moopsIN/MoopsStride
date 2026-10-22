import 'dart:io';
import 'dart:ui' as ui;

import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:stride/core/database/local_db.dart';
import 'package:stride/core/providers/preferences_provider.dart';
import 'package:stride/features/auth/providers/auth_provider.dart';
import 'package:stride/features/sync/providers/sync_engine.dart';
import 'package:stride/features/tracking/providers/tracking_provider.dart';
import 'package:stride/theme/app_theme.dart';

/// Auth without Firebase: a fixed user (or guest).
class FakeAuth extends AuthNotifier {
  final User? user;
  FakeAuth(this.user);
  @override
  User? build() => user;
}

/// Tracking without GPS/pedometer plugins: a fixed state.
class FakeTracking extends TrackingNotifier {
  final TrackingState initial;
  FakeTracking(this.initial);
  @override
  TrackingState build() => initial;
}

bool _fontsLoaded = false;

/// Loads the bundled brand fonts and Material icons so text and icons render
/// as real glyphs (tests otherwise use a blocky placeholder font).
Future<void> loadAppFonts() async {
  if (_fontsLoaded) return;
  Future<void> family(String name, List<String> assets) async {
    final loader = FontLoader(name);
    for (final a in assets) {
      loader.addFont(rootBundle.load(a));
    }
    await loader.load();
  }

  await family('Fraunces', ['assets/fonts/Fraunces-SemiBold.ttf', 'assets/fonts/Fraunces-Bold.ttf', 'assets/fonts/Fraunces-ExtraBold.ttf']);
  await family('Geist', ['assets/fonts/Geist-Regular.ttf', 'assets/fonts/Geist-Medium.ttf', 'assets/fonts/Geist-SemiBold.ttf', 'assets/fonts/Geist-Bold.ttf']);
  await family('GeistMono', ['assets/fonts/GeistMono-SemiBold.ttf']);

  // flutter_tester lives under <flutter>/bin/cache/..., next to the icon font.
  final exe = Platform.resolvedExecutable;
  final cache = exe.substring(0, exe.indexOf('/bin/cache/') + '/bin/cache/'.length);
  final icons = File('${cache}artifacts/material_fonts/MaterialIcons-Regular.otf');
  if (icons.existsSync()) {
    final loader = FontLoader('MaterialIcons')
      ..addFont(Future.value(ByteData.sublistView(icons.readAsBytesSync())));
    await loader.load();
  }
  _fontsLoaded = true;
}

/// One-time setup for screen tests: in-memory DB, mock prefs, fonts.
Future<void> setUpScreenTests() async {
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;
  LocalDatabase.pathOverride = inMemoryDatabasePath;
  // flutter_map's tile cache asks path_provider for a directory.
  final tmp = Directory.systemTemp.createTempSync('stride_test').path;
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
    const MethodChannel('plugins.flutter.io/path_provider'),
    (call) async => tmp,
  );
  await loadAppFonts();
}

final _shotKey = GlobalKey();

/// Pumps [screen] inside the real app theme at phone size with all
/// platform-bound providers stubbed.
Future<void> pumpScreen(
  WidgetTester tester,
  Widget screen, {
  bool dark = false,
  Size size = const Size(390, 844),
  TrackingState? tracking,
  User? user,
  List<Override> overrides = const [],
}) async {
  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();

  tester.view.physicalSize = size * 2;
  tester.view.devicePixelRatio = 2;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(ProviderScope(
    overrides: [
      sharedPreferencesProvider.overrideWithValue(prefs),
      authProvider.overrideWith(() => FakeAuth(user)),
      trackingProvider.overrideWith(() => FakeTracking(tracking ?? TrackingState())),
      syncEngineProvider.overrideWithValue(
        SyncEngine(auth: MockFirebaseAuth(), firestore: FakeFirebaseFirestore()),
      ),
      ...overrides,
    ],
    child: RepaintBoundary(
      key: _shotKey,
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: AppTheme.lightTheme,
        darkTheme: AppTheme.darkTheme,
        themeMode: dark ? ThemeMode.dark : ThemeMode.light,
        home: screen,
      ),
    ),
  ));
}

/// When STRIDE_SHOTS points at a directory, saves the current frame there as
/// [name].png, for eyeballing layouts during design work. No-op otherwise.
Future<void> screenshot(WidgetTester tester, String name) async {
  final dir = Platform.environment['STRIDE_SHOTS'];
  if (dir == null) return;
  await tester.runAsync(() async {
    final boundary = _shotKey.currentContext!.findRenderObject() as RenderRepaintBoundary;
    final image = await boundary.toImage(pixelRatio: 1);
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    File('$dir/$name.png').writeAsBytesSync(bytes!.buffer.asUint8List());
  });
}

/// Unmounts the screen and runs fake time past any outstanding timers
/// (entrance-animation delays, the sync engine's commit timeout).
Future<void> disposeScreen(WidgetTester tester) async {
  await flushRealAsync(tester);
  await tester.pumpWidget(const SizedBox());
  await tester.pump(const Duration(seconds: 30));
}

/// Steps frames so entrance animations (which start on the first frame and
/// then tick) actually run; one long pump would only advance a single frame.
Future<void> settleFrames(WidgetTester tester, {int frames = 20}) async {
  await flushRealAsync(tester);
  for (var i = 0; i < frames; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

/// Gives real (non-fake) async work, chiefly sqflite calls on its isolate,
/// time to finish and delivers the results. Without this a DB transaction
/// started inside a test can stay open and block the next test forever.
Future<void> flushRealAsync(WidgetTester tester) async {
  for (var i = 0; i < 3; i++) {
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 60)));
    await tester.pump();
  }
}
