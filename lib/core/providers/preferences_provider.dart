import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

final sharedPreferencesProvider = Provider<SharedPreferences>((ref) {
  throw UnimplementedError('sharedPreferencesProvider must be overridden in ProviderScope');
});

class PreferencesNotifier extends Notifier<bool> {
  @override
  bool build() {
    final prefs = ref.read(sharedPreferencesProvider);
    return prefs.getBool('isKm') ?? true;
  }

  void setKm(bool isKm) {
    state = isKm;
    ref.read(sharedPreferencesProvider).setBool('isKm', isKm);
  }
}

final isKmProvider = NotifierProvider<PreferencesNotifier, bool>(() {
  return PreferencesNotifier();
});
