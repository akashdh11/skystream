import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Local playback and library writes call [onLocalChange] so profile sync can
/// push without those providers importing the sync service.
class ProfileSyncHooks {
  void Function()? onLocalChange;
}

final profileSyncHooksProvider = Provider<ProfileSyncHooks>((ref) {
  ref.keepAlive();
  return ProfileSyncHooks();
});
