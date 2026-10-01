import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../storage/settings_repository.dart';

/// The global UI scale multiplier across the app (e.g. 0.85, 1.0, 1.15, 1.30).
final uiScaleProvider = NotifierProvider<UiScaleNotifier, double>(
  UiScaleNotifier.new,
);

class UiScaleNotifier extends Notifier<double> {
  @override
  double build() {
    final repository = ref.watch(settingsRepositoryProvider);
    return repository.getUiScale() ?? 1.0;
  }

  Future<void> setScale(double scale) async {
    state = scale;
    await ref.read(settingsRepositoryProvider).setUiScale(scale);
  }
}
