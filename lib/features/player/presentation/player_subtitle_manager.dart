/// Subtitle concerns lifted out of `PlayerController`.
///
/// This file existed on the `fvp_test` branch (2026-05-03) as a 101-line
/// `PlayerSubtitleManager` and was lost when that experiment was abandoned —
/// the concern was reabsorbed into the controller, which has since grown past
/// 5,200 lines. Restoring it is the cheapest structural win available: none of
/// what follows needs the controller's state machine.
///
/// Deliberately free functions over a class. There is no state to hold; a class
/// would only add a lifetime to manage.
library;

import 'dart:io';

import 'package:media_kit/media_kit.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../../../core/domain/entity/multimedia_item.dart';
import '../../settings/presentation/player_settings_provider.dart';

/// Writes the user's subtitle appearance settings onto a libmpv player.
///
/// Pure in the sense that matters: it takes the player handle and the settings
/// and touches nothing else. The caller owns the "should we even do this"
/// decision (disposal, whether the active engine supports styling).
///
/// Note these are all mpv `sub-*` properties. They have no libVLC equivalent —
/// VLC 3.x fixes subtitle styling at instance creation and burns subtitles into
/// the video surface. See docs/PLAYER_MIGRATION.md section 3; this whole
/// function is expected to be deleted along with media_kit in Phase 8.
Future<void> applySubtitleSettings(
  NativePlayer native,
  PlayerSettings settings,
) async {

  // Colors are in MPV hex format (e.g. #AARRGGBB)
  String colorToMpvHex(int color, [double opacity = 1.0]) {
    final alpha = (opacity * 255)
        .round()
        .clamp(0, 255)
        .toRadixString(16)
        .padLeft(2, '0');
    final rgb = color.toRadixString(16).padLeft(8, '0').substring(2);
    return '#$alpha$rgb';
  }

  // 1. Font Size
  final fontSize = settings.subFixedTextSize ?? settings.subtitleSize;
  await native.setProperty('sub-font-size', fontSize.toString());

  // 2. Font Family / Custom Typeface
  const List<String> builtInFonts = [
    'sans-serif',
    'Trebuchet MS',
    'Netflix Sans',
    'Google Sans',
    'Open Sans',
    'Futura',
    'Consolas',
    'Gotham',
    'Lucida Grande',
    'STIX General',
    'Times New Roman',
    'Verdana',
    'Ubuntu',
    'Comic Sans MS',
    'Poppins',
  ];

  if (settings.subTypefaceFilePath != null &&
      settings.subTypefaceFilePath!.isNotEmpty) {
    final file = File(settings.subTypefaceFilePath!);
    if (file.existsSync()) {
      await native.setProperty('sub-fonts-dir', file.parent.path);
      await native.setProperty(
        'sub-font',
        p.basenameWithoutExtension(file.path),
      );
    }
  } else if (settings.subTypeface != null &&
      settings.subTypeface! >= 0 &&
      settings.subTypeface! < builtInFonts.length) {
    await native.setProperty(
      'sub-font',
      builtInFonts[settings.subTypeface!],
    );
  } else {
    await native.setProperty('sub-font', 'sans-serif');
  }

  // 3. Bold & Italic
  await native.setProperty('sub-bold', settings.subBold ? 'yes' : 'no');
  await native.setProperty('sub-italic', settings.subItalic ? 'yes' : 'no');

  // 4. Foreground Text Color
  final fgColor = settings.subForegroundColor != 0xFFFFFFFF
      ? settings.subForegroundColor
      : settings.subtitleColor;
  await native.setProperty('sub-color', colorToMpvHex(fgColor));

  // 5. Edge / Outline / Shadow
  final edgeColorHex = colorToMpvHex(settings.subEdgeColor);
  final edgeSize = settings.subEdgeSize ?? 2.5;

  switch (settings.subEdgeType) {
    case 0: // None
      await native.setProperty('sub-border-size', '0');
      await native.setProperty('sub-shadow-offset', '0');
      break;
    case 1: // Outline
      await native.setProperty('sub-border-size', edgeSize.toString());
      await native.setProperty('sub-border-color', edgeColorHex);
      await native.setProperty('sub-shadow-offset', '0');
      break;
    case 2: // Raised
      await native.setProperty('sub-border-size', '1');
      await native.setProperty('sub-border-color', edgeColorHex);
      await native.setProperty('sub-shadow-offset', '1.5');
      await native.setProperty('sub-shadow-color', edgeColorHex);
      break;
    case 3: // Shadow / Drop Shadow
      await native.setProperty('sub-border-size', '0');
      await native.setProperty('sub-shadow-offset', edgeSize.toString());
      await native.setProperty('sub-shadow-color', edgeColorHex);
      break;
    case 4: // Uniform Drop Shadow
      await native.setProperty('sub-border-size', '1');
      await native.setProperty('sub-border-color', edgeColorHex);
      await native.setProperty('sub-shadow-offset', '2.0');
      await native.setProperty('sub-shadow-color', edgeColorHex);
      break;
  }

  // 6. Background Color & Opacity
  final bgColor = settings.subBackgroundColor != 0x00000000
      ? settings.subBackgroundColor
      : settings.subtitleBackgroundColor;
  if (bgColor != 0x00000000 && settings.subBackgroundOpacity > 0.0) {
    await native.setProperty(
      'sub-back-color',
      colorToMpvHex(bgColor, settings.subBackgroundOpacity),
    );
  } else {
    await native.setProperty('sub-back-color', '#00000000');
  }

  // 7. Alignment
  final alignmentCode = settings.subAlignment ?? 2;
  final alignX = switch (alignmentCode) {
    1 || 4 || 7 => 'left',
    3 || 6 || 9 => 'right',
    _ => 'center',
  };
  final alignY = switch (alignmentCode) {
    7 || 8 || 9 => 'top',
    4 || 5 || 6 => 'center',
    _ => 'bottom',
  };
  await native.setProperty('sub-align-x', alignX);
  await native.setProperty('sub-align-y', alignY);

  // 8. Position & Margin
  final subPos = settings.subtitlePosition.clamp(0.0, 100.0).round();
  await native.setProperty('sub-pos', subPos.toString());
  await native.setProperty(
    'sub-margin-y',
    (settings.subElevation * 1.5).round().toString(),
  );

  // 9. ASS styling override & keep MPV direct painting disabled (handled by SubtitleViewConfiguration)
  await native.setProperty('sub-ass-override', 'yes');
  await native.setProperty('sub-visibility', 'no');
}

/// Merges the subtitles a stream advertised with the ones the user added by
/// hand, de-duplicated by URL, preserving stream order first.
List<SubtitleFile> effectiveExternalSubtitles(
  List<SubtitleFile>? streamSubtitles,
  List<SubtitleFile> userAdded,
) {
  final merged = <SubtitleFile>[];
  final seen = <String>{};
  for (final sub in [...?streamSubtitles, ...userAdded]) {
    if (seen.add(sub.url)) merged.add(sub);
  }
  return merged;
}

/// Deletes downloaded subtitle files left in the system temp directory.
///
/// Sweeps by filename prefix rather than tracking what this session wrote:
/// handoff between sessions is fragile, and another session may have died
/// before cleaning up after itself. Best-effort throughout — a failure here
/// must never surface to the user or interrupt teardown.
Future<void> cleanupSubtitleTempFiles({void Function(Object)? onError}) async {
  try {
    final tempDir = await getTemporaryDirectory();
    if (!await tempDir.exists()) return;
    await for (final entity in tempDir.list(followLinks: false)) {
      if (entity is! File) continue;
      final name = p.basename(entity.path);
      if (name.startsWith('sub_') || name.startsWith('temp_sub_')) {
        try {
          await entity.delete();
        } catch (_) {
          // Another player session may already have deleted it. Ignore.
        }
      }
    }
  } catch (e) {
    onError?.call(e);
  }
}
