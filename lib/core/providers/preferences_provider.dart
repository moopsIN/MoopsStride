import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:stride/core/database/local_db.dart';
import 'package:stride/features/sync/providers/sync_engine.dart';

final sharedPreferencesProvider = Provider<SharedPreferences>((ref) {
  throw UnimplementedError('sharedPreferencesProvider must be overridden in ProviderScope');
});

class PreferencesNotifier extends Notifier<bool> {
  @override
  bool build() {
    final prefs = ref.read(sharedPreferencesProvider);
    return prefs.getBool('isKm') ?? true;
  }

  /// A user's choice: saved to the synced profile so other devices follow.
  Future<void> setKm(bool isKm) async {
    applyFromProfile(isKm);
    if (await LocalDatabase.instance.setUnitsPreference(isKm ? 'km' : 'mi')) {
      ref.read(syncEngineProvider).syncUnsyncedActivities();
    }
  }

  /// Adopts the unit from a synced profile without writing it back.
  void applyFromProfile(bool isKm) {
    state = isKm;
    ref.read(sharedPreferencesProvider).setBool('isKm', isKm);
  }
}

/// Before units synced, onboarding always stored 'km' in the profile. Copy
/// the device's real choice in once, so the first pull can't flip a miles
/// user back to km.
Future<void> migrateUnitsToProfile(SharedPreferences prefs) async {
  if (prefs.getBool('units_in_profile') == true) return;
  final isKm = prefs.getBool('isKm') ?? true;
  await LocalDatabase.instance.setUnitsPreference(isKm ? 'km' : 'mi');
  await prefs.setBool('units_in_profile', true);
}

final isKmProvider = NotifierProvider<PreferencesNotifier, bool>(() {
  return PreferencesNotifier();
});

class KgNotifier extends Notifier<bool> {
  @override
  bool build() {
    final prefs = ref.read(sharedPreferencesProvider);
    return prefs.getBool('isKg') ?? true;
  }

  void setKg(bool isKg) {
    state = isKg;
    ref.read(sharedPreferencesProvider).setBool('isKg', isKg);
  }
}

final isKgProvider = NotifierProvider<KgNotifier, bool>(() {
  return KgNotifier();
});
