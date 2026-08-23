import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../../core/storage/storage_service.dart';

part 'vlc_engine_flag.g.dart';

/// Whether playback should route to the experimental VLC engine.
///
/// Phase 5 of docs/PLAYER_MIGRATION.md. Both engines coexist behind this flag
/// until Phase 8 deletes the old one, so the shipping path stays untouched
/// while the new one is built out.
///
/// Deliberately a standalone provider rather than a field on GeneralSettings or
/// PlayerSettings: it is temporary. When Phase 8 lands, deleting this file and
/// its two call sites removes the flag entirely, instead of leaving a dead
/// field threaded through the settings state, notifier, repository and UI.
///
/// Defaults to false. Nothing selects VLC unless a developer turns it on.
const String kVlcEngineSettingKey = 'player_use_vlc_engine_experimental';

@riverpod
class VlcEngineEnabled extends _$VlcEngineEnabled {
  @override
  bool build() {
    return ref
            .read(storageServiceProvider)
            .getPlayerSetting<bool>(kVlcEngineSettingKey) ??
        false;
  }

  Future<void> set(bool enabled) async {
    await ref
        .read(storageServiceProvider)
        .setPlayerSetting(kVlcEngineSettingKey, enabled);
    state = enabled;
  }

  Future<void> toggle() => set(!state);
}
