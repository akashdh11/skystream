/// Internal controller hooks used by `VlcPlayer`.
///
/// This file is intentionally not exported from `package:vlc_player/vlc_player.dart`.
abstract interface class VlcPlayerControllerInternals {
  /// Attaches the controller to a platform-view backed native player.
  Future<void> attach(int viewId);

  /// Attaches the controller to a texture-backed native player.
  Future<int> attachTexturePlayer();

  /// Detaches and disposes the currently attached native player.
  Future<void> detach();
}
