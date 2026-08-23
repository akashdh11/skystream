import 'dart:ui' as ui;
import 'dart:io';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'device_info_provider.g.dart';

/// How much work this device can reasonably be asked to do.
///
/// Kept deliberately coarse — three buckets, not a score. Callers should branch
/// on this rather than re-deriving their own idea of "weak device" from
/// [DeviceProfile.isTv], which conflates form factor with capability: a Shield
/// and a 1 GB stick are both TVs.
enum DeviceTier {
  /// Cheap sticks and old phones. Android's own low-RAM flag, or under ~2 GB.
  low,

  /// Ordinary phones, tablets and TV boxes.
  standard,

  /// Desktops and anything with plenty of memory.
  high,
}

class DeviceProfile {
  final bool isTv;
  final bool isTablet;

  /// Indicates if running on a desktop operating system (macOS, Windows, Linux)
  /// Use this for capability checks (e.g. window controls, mouse hovers),
  /// NOT for layout sizing. Use [ResponsiveBreakpoints] for layout sizing.
  final bool isDesktopOS;

  /// Total physical RAM in megabytes, or null where the platform does not
  /// report it (desktop). Null is not "small" — check [tier] instead.
  final int? physicalRamMb;

  /// Coarse capability bucket. See [DeviceTier].
  final DeviceTier tier;

  const DeviceProfile({
    this.isTv = false,
    this.isTablet = false,
    this.isDesktopOS = false,
    this.physicalRamMb,
    this.tier = DeviceTier.standard,
  });

  bool get isLargeScreen => isTv || isTablet || isDesktopOS;

  /// Convenience for the common "be careful here" check.
  bool get isLowEnd => tier == DeviceTier.low;
}

@riverpod
Future<DeviceProfile> deviceProfile(Ref ref) async {
  bool isTv = false;
  bool isTablet = false;
  bool isDesktopOS = false;
  int? physicalRamMb;
  var tier = DeviceTier.standard;

  if (!kIsWeb) {
    if (Platform.isAndroid || Platform.isIOS) {
      final view = ui.PlatformDispatcher.instance.views.first;
      final size = view.physicalSize / view.devicePixelRatio;
      if (size.shortestSide >= 600) {
        isTablet = true;
      }
      final deviceInfo = DeviceInfoPlugin();
      if (Platform.isAndroid) {
        final androidInfo = await deviceInfo.androidInfo;
        isTv = androidInfo.systemFeatures.contains('android.software.leanback');
        physicalRamMb = androidInfo.physicalRamSize;
        // Trust Android's own verdict first — ActivityManager.isLowRamDevice()
        // is set by the OEM and accounts for more than raw megabytes.
        tier = androidInfo.isLowRamDevice
            ? DeviceTier.low
            : _tierFromRam(androidInfo.physicalRamSize);
      } else if (Platform.isIOS) {
        final iosInfo = await deviceInfo.iosInfo;
        physicalRamMb = iosInfo.physicalRamSize;
        tier = _tierFromRam(iosInfo.physicalRamSize);
      }
    }

    if (Platform.isMacOS || Platform.isWindows || Platform.isLinux) {
      isDesktopOS = true;
      // Desktops are not the constrained case this tier exists to protect.
      tier = DeviceTier.high;
    }
  }

  return DeviceProfile(
    isTv: isTv,
    isTablet: isTablet,
    isDesktopOS: isDesktopOS,
    physicalRamMb: physicalRamMb,
    tier: tier,
  );
}

/// Buckets raw megabytes. Thresholds are deliberately generous: the cost of
/// treating a capable device as low-end is a slightly smaller buffer, while the
/// cost of the reverse is the stutter and thermal behaviour this exists to avoid.
DeviceTier _tierFromRam(int mb) {
  if (mb <= 0) return DeviceTier.standard; // unreported — do not guess
  if (mb < 2048) return DeviceTier.low;
  if (mb >= 6144) return DeviceTier.high;
  return DeviceTier.standard;
}
