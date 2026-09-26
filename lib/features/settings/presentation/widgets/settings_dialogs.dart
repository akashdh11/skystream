import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../../../shared/widgets/custom_widgets.dart';
import '../../../../core/services/external_player_service.dart';
import '../../../../core/config/tmdb_config.dart';
import '../../../../core/network/dio_client_provider.dart';
import '../../../../core/network/doh_service.dart';
import '../../../../core/storage/settings_repository.dart';
import '../../../../core/services/download_service.dart';
import '../../../../core/theme/theme_provider.dart';
import '../../../../core/utils/app_utils.dart';
import '../../../../shared/widgets/loading_indicator.dart';
import '../../../player/domain/network_buffer.dart';
import '../player_settings_provider.dart';
import '../../../../core/utils/stream_quality_sorter.dart';
import '../general_settings_provider.dart';
import '../../../../core/providers/device_info_provider.dart';
import '../../../../core/providers/locale_provider.dart';
import '../../../player/presentation/player_platform_service.dart';

import 'package:skystream/l10n/generated/app_localizations.dart';

import '../../../../core/services/notification_service.dart';
import '../cache_provider.dart';

/// Returns a localized label for a player gesture.
String getGestureLabel(PlayerGesture gesture, AppLocalizations l10n) {
  switch (gesture) {
    case PlayerGesture.volume:
      return l10n.volume;
    case PlayerGesture.brightness:
      return l10n.brightness;
    case PlayerGesture.none:
      return l10n.none;
  }
}

/// Returns a localized label for the subtitle default.
///
/// Off reuses the player's own `off` key rather than a second word for the
/// same state: the Subtitles tab already labels its no-subtitle row with it,
/// and this setting is a default for exactly that row.
String subtitleDefaultLabel(SubtitleDefault value, AppLocalizations l10n) =>
    switch (value) {
      SubtitleDefault.auto => l10n.subtitleDefaultAuto,
      SubtitleDefault.off => l10n.off,
    };

/// Returns a localized label for a resize mode string.
String getResizeModeLabel(String mode, AppLocalizations l10n) {
  switch (mode.toLowerCase()) {
    case 'fit':
      return l10n.fit;
    case 'zoom':
      return l10n.zoom;
    case 'stretch':
      return l10n.stretch;
    default:
      return mode;
  }
}

/// Returns a human-readable label for a home screen route.
String getHomeScreenLabel(String route, AppLocalizations l10n) {
  switch (route) {
    case '/home':
      return l10n.home;
    case '/explore':
      return l10n.explore;
    case '/search':
      return l10n.search;
    case '/library':
      return l10n.library;
    default:
      return l10n.home;
  }
}

/// Scrolls its child into view once, on the frame after the picker is laid
/// out.
///
/// [ListTile.autofocus] gives the current value the focus but does not move a
/// [Scrollable]. In a picker taller than its dialog — the language list is
/// thirty-odd rows — that would focus the right row off screen and still open
/// the list on row one, which is the bug this is here to close. A no-op when
/// the list already fits, since there is then nothing to scroll.
class _ScrollIntoView extends StatefulWidget {
  const _ScrollIntoView({required this.child});

  final Widget child;

  @override
  State<_ScrollIntoView> createState() => _ScrollIntoViewState();
}

class _ScrollIntoViewState extends State<_ScrollIntoView> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || Scrollable.maybeOf(context) == null) return;
      // Duration.zero jumps rather than animating: the picker should already
      // be showing the current value on the first frame the viewer sees.
      unawaited(
        Scrollable.ensureVisible(
          context,
          alignment: 0.5,
          duration: Duration.zero,
        ),
      );
    });
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

/// Wraps the one option row that matches the current value so it is scrolled
/// into view. Pair with `autofocus: isCurrent` on the row itself.
Widget _currentOption({required bool isCurrent, required Widget child}) =>
    isCurrent ? _ScrollIntoView(child: child) : child;

/// Shows a dialog to pick the default home screen.
void showDefaultHomeScreenDialog(
  BuildContext context,
  WidgetRef ref,
  String current,
) {
  final l10n = AppLocalizations.of(context)!;
  final options = <Map<String, String>>[
    {'label': l10n.home, 'route': '/home'},
    {'label': l10n.explore, 'route': '/explore'},
    {'label': l10n.search, 'route': '/search'},
    {'label': l10n.library, 'route': '/library'},
  ];

  showDialog<void>(
    context: context,
    builder: (context) => AlertDialog(
      surfaceTintColor: Colors.transparent,
      title: Text(l10n.defaultHomeScreen),
      content: RadioGroup<String>(
        groupValue: current,
        onChanged: (val) {
          if (val == null) return;
          ref.read(generalSettingsProvider.notifier).setDefaultHomeScreen(val);
          Navigator.pop<void>(context);
        },
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: options.map((opt) {
              final bool isCurrent = opt['route'] == current;
              return _currentOption(
                isCurrent: isCurrent,
                child: ListTile(
                  autofocus: isCurrent,
                  title: Text(opt['label']!),
                  leading: Radio<String>(value: opt['route']!),
                  onTap: () {
                    ref
                        .read(generalSettingsProvider.notifier)
                        .setDefaultHomeScreen(opt['route']!);
                    Navigator.pop<void>(context);
                  },
                ),
              );
            }).toList(),
          ),
        ),
      ),
    ),
  );
}

/// Returns a localized label for a title position.
String getTitlePositionLabel(String position, AppLocalizations l10n) {
  switch (position) {
    case 'inside':
      return l10n.titlePositionInsidePoster;
    case 'below':
    default:
      return l10n.titlePositionBelowPoster;
  }
}

/// Shows a dialog to pick the title position on poster cards.
void showTitlePositionDialog(
  BuildContext context,
  WidgetRef ref,
  String current,
) {
  final l10n = AppLocalizations.of(context)!;
  final options = <Map<String, String>>[
    {'label': l10n.titlePositionBelowPoster, 'value': 'below'},
    {'label': l10n.titlePositionInsidePoster, 'value': 'inside'},
  ];

  showDialog<void>(
    context: context,
    builder: (context) => AlertDialog(
      surfaceTintColor: Colors.transparent,
      title: Text(l10n.titlePosition),
      content: RadioGroup<String>(
        groupValue: current,
        onChanged: (val) {
          if (val == null) return;
          ref.read(generalSettingsProvider.notifier).setTitlePosition(val);
          Navigator.pop<void>(context);
        },
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: options.map((opt) {
              final bool isCurrent = opt['value'] == current;
              return _currentOption(
                isCurrent: isCurrent,
                child: ListTile(
                  autofocus: isCurrent,
                  title: Text(opt['label']!),
                  leading: Radio<String>(value: opt['value']!),
                  onTap: () {
                    ref
                        .read(generalSettingsProvider.notifier)
                        .setTitlePosition(opt['value']!);
                    Navigator.pop<void>(context);
                  },
                ),
              );
            }).toList(),
          ),
        ),
      ),
    ),
  );
}

Future<void> showDownloadSettingsDialog(
  BuildContext context,
  WidgetRef ref,
  GeneralSettings settings,
) async {
  int concurrency = settings.downloadConcurrency;
  int chunks = settings.downloadChunks;
  String? directory = settings.downloadDirectory;

  await showDialog<void>(
    context: context,
    builder: (dialogContext) {
      return StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            title: const Text('Downloads'),
            content: SizedBox(
              width: 420,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(Icons.folder_open_rounded),
                      title: const Text('Download location'),
                      subtitle: Text(
                        directory ?? 'System Downloads/Skystream',
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      trailing: const Icon(Icons.edit),
                      onTap: () async {
                        final picked = await ref
                            .read(downloadServiceProvider)
                            .pickDownloadDirectory();
                        if (picked != null) {
                          setDialogState(() => directory = picked);
                        }
                      },
                    ),
                    if (directory != null)
                      Align(
                        alignment: Alignment.centerLeft,
                        child: TextButton.icon(
                          onPressed: () {
                            ref
                                .read(generalSettingsProvider.notifier)
                                .setDownloadDirectory(null);
                            setDialogState(() => directory = null);
                          },
                          icon: const Icon(Icons.restart_alt),
                          label: const Text('Reset to default'),
                        ),
                      ),
                    const SizedBox(height: 12),
                    Text('Queue limit: $concurrency at once'),
                    CustomSlider(
                      value: concurrency.toDouble(),
                      min: 1,
                      max: 10,
                      divisions: 9,
                      step: 1.0,
                      onChanged: (v) =>
                          setDialogState(() => concurrency = v.round()),
                    ),
                    Text('Segments per file: $chunks'),
                    CustomSlider(
                      value: chunks.toDouble(),
                      min: 1,
                      max: 8,
                      divisions: 7,
                      step: 1.0,
                      onChanged: (v) =>
                          setDialogState(() => chunks = v.round()),
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () async {
                  final notifier = ref.read(generalSettingsProvider.notifier);
                  await notifier.setDownloadDirectory(directory);
                  await notifier.setDownloadConcurrency(concurrency);
                  await notifier.setDownloadChunks(chunks);
                  await ref
                      .read(downloadServiceProvider)
                      .applyQueueSettings(
                        maxConcurrent: concurrency,
                        chunks: chunks,
                      );
                  if (context.mounted) Navigator.pop(context);
                },
                child: const Text('Save'),
              ),
            ],
          );
        },
      );
    },
  );
}

Future<void> showDownloadLocationDialog(
  BuildContext context,
  WidgetRef ref,
  GeneralSettings settings,
) async {
  String? directory = settings.downloadDirectory;

  await showDialog<void>(
    context: context,
    builder: (dialogContext) {
      return StatefulBuilder(
        builder: (ctx, setState) {
          return AlertDialog(
            surfaceTintColor: Colors.transparent,
            title: const Text('Download Location'),
            content: SizedBox(
              width: 420,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.folder_open_rounded),
                    title: const Text('Target Directory'),
                    subtitle: Text(
                      directory ?? 'System Downloads/Skystream',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    trailing: const Icon(Icons.edit_rounded),
                    onTap: () async {
                      final picked = await ref
                          .read(downloadServiceProvider)
                          .pickDownloadDirectory();
                      if (picked != null) {
                        setState(() => directory = picked);
                      }
                    },
                  ),
                  if (directory != null)
                    Align(
                      alignment: Alignment.centerLeft,
                      child: TextButton.icon(
                        onPressed: () {
                          setState(() => directory = null);
                        },
                        icon: const Icon(Icons.restart_alt_rounded),
                        label: const Text('Reset to default'),
                      ),
                    ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () async {
                  await ref
                      .read(generalSettingsProvider.notifier)
                      .setDownloadDirectory(directory);
                  if (ctx.mounted) Navigator.pop(ctx);
                },
                child: const Text('Save'),
              ),
            ],
          );
        },
      );
    },
  );
}

void showDownloadConcurrencyDialog(
  BuildContext context,
  WidgetRef ref,
  GeneralSettings settings,
) {
  showDialog<void>(
    context: context,
    builder: (ctx) {
      var concurrency = settings.downloadConcurrency.clamp(1, 10);
      return StatefulBuilder(
        builder: (ctx, setState) => AlertDialog(
          surfaceTintColor: Colors.transparent,
          title: const Text('Parallel Downloads'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '$concurrency simultaneous download${concurrency > 1 ? 's' : ''}',
                style: Theme.of(ctx).textTheme.headlineSmall
                    ?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              CustomSlider(
                value: concurrency.toDouble(),
                min: 1,
                max: 10,
                divisions: 9,
                step: 1.0,
                onChanged: (v) => setState(() => concurrency = v.round()),
              ),
              const SizedBox(height: 4),
              Text(
                'Controls how many active downloads run concurrently before queueing.',
                style: Theme.of(ctx).textTheme.bodySmall?.copyWith(
                  color: Theme.of(ctx).colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () async {
                await ref
                    .read(generalSettingsProvider.notifier)
                    .setDownloadConcurrency(concurrency);
                await ref
                    .read(downloadServiceProvider)
                    .applyQueueSettings(
                      maxConcurrent: concurrency,
                      chunks: settings.downloadChunks,
                    );
                if (ctx.mounted) Navigator.pop(ctx);
              },
              child: const Text('Save'),
            ),
          ],
        ),
      );
    },
  );
}

void showDownloadChunksDialog(
  BuildContext context,
  WidgetRef ref,
  GeneralSettings settings,
) {
  showDialog<void>(
    context: context,
    builder: (ctx) {
      var chunks = settings.downloadChunks.clamp(1, 8);
      return StatefulBuilder(
        builder: (ctx, setState) => AlertDialog(
          surfaceTintColor: Colors.transparent,
          title: const Text('Download Connections (Segments)'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                chunks == 1
                    ? 'Single connection (Off)'
                    : '$chunks parallel segments',
                style: Theme.of(ctx).textTheme.headlineSmall
                    ?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              CustomSlider(
                value: chunks.toDouble(),
                min: 1,
                max: 8,
                divisions: 7,
                step: 1.0,
                onChanged: (v) => setState(() => chunks = v.round()),
              ),
              const SizedBox(height: 4),
              Text(
                'Splits large files into parallel chunks to accelerate download speed on high-bandwidth connections.',
                style: Theme.of(ctx).textTheme.bodySmall?.copyWith(
                  color: Theme.of(ctx).colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () async {
                await ref
                    .read(generalSettingsProvider.notifier)
                    .setDownloadChunks(chunks);
                await ref
                    .read(downloadServiceProvider)
                    .applyQueueSettings(
                      maxConcurrent: settings.downloadConcurrency,
                      chunks: chunks,
                    );
                if (ctx.mounted) Navigator.pop(ctx);
              },
              child: const Text('Save'),
            ),
          ],
        ),
      );
    },
  );
}

// Must be used inside a RadioGroup<ThemeMode> ancestor.
Widget _buildThemeOption(
  String title,
  ThemeMode value,
  ThemeMode current,
  VoidCallback onSelect,
) {
  final bool isCurrent = value == current;
  return _currentOption(
    isCurrent: isCurrent,
    child: ListTile(
      autofocus: isCurrent,
      title: Text(title),
      leading: Radio<ThemeMode>(value: value),
      onTap: onSelect,
    ),
  );
}

/// Formats seek duration for display (e.g. "10 sec", "2 min").
/// Plain megabytes. The buffer holds bytes, so this is the whole truth about
/// it - how many seconds those buy depends on the bitrate, which is not known
/// until a stream is open and differs per rendition anyway.
String formatNetworkBuffer(int megabytes) => '$megabytes MB';

String formatSeekDuration(int seconds, AppLocalizations l10n) {
  if (seconds >= 60) {
    return '${seconds ~/ 60} ${l10n.min}';
  }
  return '$seconds ${l10n.sec}';
}

/// Returns a human-readable name for a player ID.
String getPlayerDisplayName(String? playerId, AppLocalizations l10n) {
  if (playerId == null) return l10n.internalPlayer;
  final player = ExternalPlayerService.instance.getPlayerById(playerId);
  return player?.displayName ?? playerId;
}

/// Returns a human-readable label for a DoH provider.
String getDohProviderLabel(
  DohProvider provider,
  String customUrl,
  AppLocalizations l10n,
) {
  switch (provider) {
    case DohProvider.cloudflare:
      return l10n.cloudflare;
    case DohProvider.google:
      return l10n.google;
    case DohProvider.adguard:
      return l10n.adguard;
    case DohProvider.dnsWatch:
      return l10n.dnsWatch;
    case DohProvider.quad9:
      return l10n.quad9;
    case DohProvider.dnsSb:
      return l10n.dnsSb;
    case DohProvider.canadianShield:
      return l10n.canadianShield;
    case DohProvider.custom:
      return customUrl.isNotEmpty ? customUrl : l10n.customNotSet;
  }
}

/// Shows a dialog to pick the left/right swipe gesture.
void showGestureDialog(
  BuildContext context,
  WidgetRef ref,
  bool isLeft,
  PlayerGesture current,
) {
  final l10n = AppLocalizations.of(context)!;
  showDialog<void>(
    context: context,
    builder: (context) => AlertDialog(
      surfaceTintColor: Colors.transparent,
      title: Text(l10n.selectGesture(isLeft ? l10n.left : l10n.right)),
      content: RadioGroup<PlayerGesture>(
        groupValue: current,
        onChanged: (val) {
          if (val == null) return;
          if (isLeft) {
            ref.read(playerSettingsProvider.notifier).setLeftGesture(val);
          } else {
            ref.read(playerSettingsProvider.notifier).setRightGesture(val);
          }
          Navigator.pop<void>(context);
        },
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: PlayerGesture.values.map((g) {
              final String label = getGestureLabel(g, l10n);
              final bool isCurrent = g == current;
              return _currentOption(
                isCurrent: isCurrent,
                child: ListTile(
                  autofocus: isCurrent,
                  title: Text(label),
                  leading: Radio<PlayerGesture>(value: g),
                  onTap: () {
                    if (isLeft) {
                      ref
                          .read(playerSettingsProvider.notifier)
                          .setLeftGesture(g);
                    } else {
                      ref
                          .read(playerSettingsProvider.notifier)
                          .setRightGesture(g);
                    }
                    Navigator.pop<void>(context);
                  },
                ),
              );
            }).toList(),
          ),
        ),
      ),
    ),
  );
}

/// Shows a dialog to pick the seek duration.
/// Picks how much of a stream to hold in memory.
///
/// [current] is the size in force, which is this device's default until the
/// viewer picks something. Picking stores the number, so it then follows them
/// rather than the hardware.
void showNetworkBufferDialog(BuildContext context, WidgetRef ref, int current) {
  final l10n = AppLocalizations.of(context)!;
  const options = kNetworkBufferChoicesMb;

  showDialog<void>(
    context: context,
    builder: (context) => AlertDialog(
      surfaceTintColor: Colors.transparent,
      title: Text(l10n.selectNetworkBuffer),
      content: RadioGroup<int>(
        groupValue: current,
        onChanged: (val) {
          if (val == null) return;
          ref.read(playerSettingsProvider.notifier).setNetworkBufferMb(val);
          Navigator.pop<void>(context);
        },
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: options.map((mb) {
              final bool isCurrent = mb == current;
              return _currentOption(
                isCurrent: isCurrent,
                child: ListTile(
                  autofocus: isCurrent,
                  title: Text(formatNetworkBuffer(mb)),
                  leading: Radio<int>(value: mb),
                  onTap: () {
                    ref
                        .read(playerSettingsProvider.notifier)
                        .setNetworkBufferMb(mb);
                    Navigator.pop<void>(context);
                  },
                ),
              );
            }).toList(),
          ),
        ),
      ),
    ),
  );
}

void showDurationDialog(BuildContext context, WidgetRef ref, int current) {
  final l10n = AppLocalizations.of(context)!;
  final options = <int>[5, 10, 15, 20, 30, 60, 120];

  showDialog<void>(
    context: context,
    builder: (context) => AlertDialog(
      surfaceTintColor: Colors.transparent,
      title: Text(l10n.selectSeekDuration),
      content: RadioGroup<int>(
        groupValue: current,
        onChanged: (val) {
          if (val == null) return;
          ref.read(playerSettingsProvider.notifier).setSeekDuration(val);
          Navigator.pop<void>(context);
        },
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: options.map((sec) {
              final bool isCurrent = sec == current;
              return _currentOption(
                isCurrent: isCurrent,
                child: ListTile(
                  autofocus: isCurrent,
                  title: Text(formatSeekDuration(sec, l10n)),
                  leading: Radio<int>(value: sec),
                  onTap: () {
                    ref
                        .read(playerSettingsProvider.notifier)
                        .setSeekDuration(sec);
                    Navigator.pop<void>(context);
                  },
                ),
              );
            }).toList(),
          ),
        ),
      ),
    ),
  );
}

/// Shows a dialog to pick the default resize mode.
void showResizeDialog(BuildContext context, WidgetRef ref, String current) {
  final l10n = AppLocalizations.of(context)!;
  final options = <Map<String, String>>[
    {'label': l10n.fit, 'value': 'Fit'},
    {'label': l10n.zoom, 'value': 'Zoom'},
    {'label': l10n.stretch, 'value': 'Stretch'},
  ];
  showDialog<void>(
    context: context,
    builder: (ctx) => AlertDialog(
      surfaceTintColor: Colors.transparent,
      title: Text(l10n.defaultResizeMode),
      content: RadioGroup<String>(
        groupValue: current,
        onChanged: (val) {
          if (val == null) return;
          ref.read(playerSettingsProvider.notifier).setDefaultResizeMode(val);
          Navigator.pop<void>(ctx);
        },
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: options.map((e) {
              final bool isCurrent = e['value'] == current;
              return _currentOption(
                isCurrent: isCurrent,
                child: ListTile(
                  autofocus: isCurrent,
                  title: Text(e['label']!),
                  leading: Radio<String>(value: e['value']!),
                  onTap: () {
                    ref
                        .read(playerSettingsProvider.notifier)
                        .setDefaultResizeMode(e['value']!);
                    Navigator.pop<void>(ctx);
                  },
                ),
              );
            }).toList(),
          ),
        ),
      ),
    ),
  );
}

/// Shows a dialog to pick whether videos start with a subtitle showing.
///
/// Each choice carries a line of its own because the word alone is misread:
/// "Off" here is the *starting* state of every video, not a switch that takes
/// the Subtitles menu away, and the detail line is the only place that says so.
void showSubtitleDefaultDialog(
  BuildContext context,
  WidgetRef ref,
  SubtitleDefault current,
) {
  final l10n = AppLocalizations.of(context)!;
  final options = <({SubtitleDefault value, String label, String detail})>[
    (
      value: SubtitleDefault.auto,
      label: l10n.subtitleDefaultAuto,
      detail: l10n.subtitleDefaultAutoDetail,
    ),
    (
      value: SubtitleDefault.off,
      label: l10n.off,
      detail: l10n.subtitleDefaultOffDetail,
    ),
  ];
  showDialog<void>(
    context: context,
    builder: (ctx) => AlertDialog(
      surfaceTintColor: Colors.transparent,
      title: Text(l10n.subtitleDefault),
      content: RadioGroup<SubtitleDefault>(
        groupValue: current,
        onChanged: (val) {
          if (val == null) return;
          ref.read(playerSettingsProvider.notifier).setSubtitleDefault(val);
          Navigator.pop<void>(ctx);
        },
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: options.map((opt) {
              final bool isCurrent = opt.value == current;
              return _currentOption(
                isCurrent: isCurrent,
                child: ListTile(
                  autofocus: isCurrent,
                  title: Text(opt.label),
                  subtitle: Text(opt.detail),
                  leading: Radio<SubtitleDefault>(value: opt.value),
                  onTap: () {
                    ref
                        .read(playerSettingsProvider.notifier)
                        .setSubtitleDefault(opt.value);
                    Navigator.pop<void>(ctx);
                  },
                ),
              );
            }).toList(),
          ),
        ),
      ),
    ),
  );
}

/// Shows a dialog for subtitle size + background settings.
void showSubtitleDialog(
  BuildContext context,
  WidgetRef ref,
  PlayerSettings settings,
) {
  final l10n = AppLocalizations.of(context)!;
  double size = settings.subtitleSize;
  bool showBackground = settings.subtitleBackgroundColor != 0;

  showDialog<void>(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (context, setState) {
        return AlertDialog(
          surfaceTintColor: Colors.transparent,
          title: Text(l10n.subtitleSettings),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(l10n.size(size.toInt())),
                CustomSlider(
                  value: size,
                  min: 10,
                  max: 80,
                  divisions: 70,
                  step: 1.0,
                  onChanged: (v) => setState(() => size = v),
                ),
                const SizedBox(height: 8),
                SwitchListTile(
                  title: Text(l10n.background),
                  value: showBackground,
                  onChanged: (v) => setState(() => showBackground = v),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop<void>(ctx),
              child: Text(
                l10n.cancel,
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ),
            CustomButton(
              isPrimary: true,
              onPressed: () {
                final bg = showBackground ? 0x99000000 : 0x00000000;
                ref
                    .read(playerSettingsProvider.notifier)
                    .setSubtitleSettings(size, settings.subtitleColor, bg);
                Navigator.pop<void>(ctx);
              },
              child: Text(l10n.save),
            ),
          ],
        );
      },
    ),
  );
}

/// Shows a dialog to pick the default player (internal or external).
void showDefaultPlayerDialog(
  BuildContext context,
  WidgetRef ref,
  String? currentPlayerId,
) {
  final l10n = AppLocalizations.of(context)!;
  final service = ExternalPlayerService.instance;
  final platformPlayers = service.getPlayersForPlatform();

  // A stored id this platform does not list - a build that dropped the player,
  // or a settings box carried over - matches no row, so the group opens with
  // nothing selected and Cancel leaves that same id in place. Give it a row of
  // its own instead, saying why it is not among the others.
  final unavailable =
      currentPlayerId != null &&
          !platformPlayers.any((p) => p.id == currentPlayerId)
      ? currentPlayerId
      : null;

  showDialog<void>(
    context: context,
    builder: (context) => AlertDialog(
      surfaceTintColor: Colors.transparent,
      title: Text(l10n.defaultPlayer),
      content: SingleChildScrollView(
        child: RadioGroup<String?>(
          groupValue: currentPlayerId,
          onChanged: (val) async {
            // Close only once the choice is on disk: a relaunch in the gap
            // would read the old player back and the "Default Player" row
            // would lie until the next launch.
            await ref
                .read(playerSettingsProvider.notifier)
                .setPreferredPlayer(val);
            if (context.mounted) Navigator.pop<void>(context);
          },
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _currentOption(
                isCurrent: currentPlayerId == null,
                child: ListTile(
                  autofocus: currentPlayerId == null,
                  title: Text(l10n.internalPlayer),
                  subtitle: Text(l10n.builtInPlayer),
                  leading: const Radio<String?>(value: null),
                  trailing: const Icon(Icons.play_circle_filled_rounded),
                  onTap: () async {
                    await ref
                        .read(playerSettingsProvider.notifier)
                        .setPreferredPlayer(null);
                    if (context.mounted) Navigator.pop<void>(context);
                  },
                ),
              ),
              const Divider(),
              ...platformPlayers.map((player) {
                final bool isCurrent = player.id == currentPlayerId;
                return _currentOption(
                  isCurrent: isCurrent,
                  child: ListTile(
                    autofocus: isCurrent,
                    title: Text(player.displayName),
                    leading: Radio<String?>(value: player.id),
                    trailing: Icon(player.icon),
                    onTap: () async {
                      await ref
                          .read(playerSettingsProvider.notifier)
                          .setPreferredPlayer(player.id);
                      if (context.mounted) Navigator.pop<void>(context);
                    },
                  ),
                );
              }),
              if (unavailable != null)
                _currentOption(
                  isCurrent: true,
                  child: ListTile(
                    autofocus: true,
                    enabled: false,
                    title: Text(
                      service.getPlayerById(unavailable)?.displayName ??
                          unavailable,
                    ),
                    subtitle: Text(l10n.playerNotOnThisDevice),
                    leading: Radio<String?>(value: unavailable),
                    trailing: const Icon(Icons.block_rounded),
                  ),
                ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop<void>(context),
          child: Text(
            l10n.cancel,
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ),
      ],
    ),
  );
}

/// Shows a dialog to pick the DNS-over-HTTPS provider.
void showDohProviderDialog(BuildContext context, WidgetRef ref) {
  showDialog<void>(
    context: context,
    builder: (_) => const _DohProviderDialog(),
  );
}

class _DohProviderDialog extends ConsumerStatefulWidget {
  const _DohProviderDialog();

  @override
  ConsumerState<_DohProviderDialog> createState() => _DohProviderDialogState();
}

class _DohProviderDialogState extends ConsumerState<_DohProviderDialog> {
  late DohProvider _currentProvider;
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    final initialSettings = ref.read(dohSettingsProvider).asData?.value;
    _currentProvider = initialSettings?.provider ?? DohProvider.cloudflare;
    _controller = TextEditingController(text: initialSettings?.customUrl ?? '');
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _saveAndClose(DohProvider p, [String? customUrl]) {
    ref.read(dohSettingsProvider.notifier).setProvider(p);
    if (p == DohProvider.custom && customUrl != null) {
      ref.read(dohSettingsProvider.notifier).setCustomUrl(customUrl);
    }
    ref.read(dohSettingsProvider.notifier).clearCache();
    Navigator.pop<void>(context);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return AlertDialog(
      surfaceTintColor: Colors.transparent,
      title: Text(l10n.dohProvider),
      content: SingleChildScrollView(
        child: RadioGroup<DohProvider>(
          groupValue: _currentProvider,
          onChanged: (val) {
            if (val == null) return;
            if (val == DohProvider.custom) {
              setState(() => _currentProvider = val);
            } else {
              _saveAndClose(val);
            }
          },
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _currentOption(
                isCurrent: _currentProvider == DohProvider.cloudflare,
                child: ListTile(
                  autofocus: _currentProvider == DohProvider.cloudflare,
                  title: Text(l10n.cloudflare),
                  subtitle: const Text('1.1.1.1'),
                  leading: const Radio<DohProvider>(
                    value: DohProvider.cloudflare,
                  ),
                  onTap: () => _saveAndClose(DohProvider.cloudflare),
                ),
              ),
              _currentOption(
                isCurrent: _currentProvider == DohProvider.google,
                child: ListTile(
                  autofocus: _currentProvider == DohProvider.google,
                  title: Text(l10n.google),
                  subtitle: const Text('8.8.8.8'),
                  leading: const Radio<DohProvider>(value: DohProvider.google),
                  onTap: () => _saveAndClose(DohProvider.google),
                ),
              ),
              _currentOption(
                isCurrent: _currentProvider == DohProvider.adguard,
                child: ListTile(
                  autofocus: _currentProvider == DohProvider.adguard,
                  title: Text(l10n.adguard),
                  subtitle: const Text('dns.adguard.com'),
                  leading: const Radio<DohProvider>(value: DohProvider.adguard),
                  onTap: () => _saveAndClose(DohProvider.adguard),
                ),
              ),
              _currentOption(
                isCurrent: _currentProvider == DohProvider.dnsWatch,
                child: ListTile(
                  autofocus: _currentProvider == DohProvider.dnsWatch,
                  title: Text(l10n.dnsWatch),
                  subtitle: const Text('resolver2.dns.watch'),
                  leading: const Radio<DohProvider>(
                    value: DohProvider.dnsWatch,
                  ),
                  onTap: () => _saveAndClose(DohProvider.dnsWatch),
                ),
              ),
              _currentOption(
                isCurrent: _currentProvider == DohProvider.quad9,
                child: ListTile(
                  autofocus: _currentProvider == DohProvider.quad9,
                  title: Text(l10n.quad9),
                  subtitle: const Text('9.9.9.9'),
                  leading: const Radio<DohProvider>(value: DohProvider.quad9),
                  onTap: () => _saveAndClose(DohProvider.quad9),
                ),
              ),
              _currentOption(
                isCurrent: _currentProvider == DohProvider.dnsSb,
                child: ListTile(
                  autofocus: _currentProvider == DohProvider.dnsSb,
                  title: Text(l10n.dnsSb),
                  subtitle: const Text('doh.dns.sb'),
                  leading: const Radio<DohProvider>(value: DohProvider.dnsSb),
                  onTap: () => _saveAndClose(DohProvider.dnsSb),
                ),
              ),
              _currentOption(
                isCurrent: _currentProvider == DohProvider.canadianShield,
                child: ListTile(
                  autofocus: _currentProvider == DohProvider.canadianShield,
                  title: Text(l10n.canadianShield),
                  subtitle: const Text('private.canadianshield.cira.ca'),
                  leading: const Radio<DohProvider>(
                    value: DohProvider.canadianShield,
                  ),
                  onTap: () => _saveAndClose(DohProvider.canadianShield),
                ),
              ),
              ListTile(
                title: Text(l10n.custom),
                subtitle: Text(l10n.enterCustomDohUrl),
                leading: const Radio<DohProvider>(value: DohProvider.custom),
                onTap: () =>
                    setState(() => _currentProvider = DohProvider.custom),
              ),
              if (_currentProvider == DohProvider.custom)
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16.0,
                    vertical: 8.0,
                  ),
                  child: CustomTextField(
                    controller: _controller,
                    autofocus: true,
                    decoration: InputDecoration(
                      labelText: l10n.customDohUrlLabel,
                      hintText: 'https://...',
                      prefixIcon: const Icon(Icons.link_rounded, size: 20),
                    ),
                    keyboardType: TextInputType.url,
                  ),
                ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop<void>(context),
          child: Text(
            l10n.cancel,
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ),
        if (_currentProvider == DohProvider.custom)
          CustomButton(
            isPrimary: true,
            onPressed: () {
              final url = _controller.text.trim();
              if (url.isNotEmpty) {
                _saveAndClose(DohProvider.custom, url);
              }
            },
            child: Text(l10n.save),
          ),
      ],
    );
  }
}

/// Shows a dialog to pick the app theme mode.
void showThemeDialog(
  BuildContext context,
  WidgetRef ref,
  ThemeMode currentTheme,
) {
  final l10n = AppLocalizations.of(context)!;
  showDialog<void>(
    context: context,
    builder: (context) => AlertDialog(
      surfaceTintColor: Colors.transparent,
      title: Text(l10n.chooseTheme),
      content: RadioGroup<ThemeMode>(
        groupValue: currentTheme,
        onChanged: (val) {
          if (val == null) return;
          ref.read(appThemeModeProvider.notifier).setThemeMode(val);
          Navigator.pop<void>(context);
        },
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildThemeOption(
                l10n.system,
                ThemeMode.system,
                currentTheme,
                () {
                  ref
                      .read(appThemeModeProvider.notifier)
                      .setThemeMode(ThemeMode.system);
                  Navigator.pop<void>(context);
                },
              ),
              _buildThemeOption(l10n.dark, ThemeMode.dark, currentTheme, () {
                ref
                    .read(appThemeModeProvider.notifier)
                    .setThemeMode(ThemeMode.dark);
                Navigator.pop<void>(context);
              }),
              _buildThemeOption(l10n.light, ThemeMode.light, currentTheme, () {
                ref
                    .read(appThemeModeProvider.notifier)
                    .setThemeMode(ThemeMode.light);
                Navigator.pop<void>(context);
              }),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop<void>(context),
          child: Text(
            l10n.cancel,
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ),
      ],
    ),
  );
}

/// Shows a dialog to reset data.
void showResetDataDialog(BuildContext context, WidgetRef ref) {
  final l10n = AppLocalizations.of(context)!;
  final callerContext = context;
  showDialog<void>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      surfaceTintColor: Colors.transparent,
      title: Text(l10n.resetDataDialogTitle),
      content: Text(l10n.resetDataDialogContent),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop<void>(dialogContext),
          child: Text(
            l10n.cancel,
            style: TextStyle(
              color: Theme.of(dialogContext).colorScheme.onSurfaceVariant,
            ),
          ),
        ),
        TextButton(
          onPressed: () async {
            Navigator.pop<void>(dialogContext);

            // Clear Preferences ONLY. The box takes both account usernames
            // with it and `clearPreferences` takes the matching passwords out
            // of the secure store; this drops the copies already in memory,
            // so nothing renders a signed-in account between here and the
            // restart.
            await ref.read(playerSettingsProvider.notifier).clearCredentials();
            await ref.read(settingsRepositoryProvider).clearPreferences();

            // Restart App - use caller's context; dialog context may be disposed after pop
            if (callerContext.mounted) {
              await AppUtils.restartApp(callerContext);
            }
          },
          style: TextButton.styleFrom(
            foregroundColor: Theme.of(dialogContext).colorScheme.tertiary,
          ),
          child: Text(l10n.resetDataKeepExtensions),
        ),
      ],
    ),
  );
}

/// Shows a dialog to factory reset.
void showFactoryResetDialog(BuildContext context, WidgetRef ref) {
  final l10n = AppLocalizations.of(context)!;
  final callerContext = context;
  showDialog<void>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      surfaceTintColor: Colors.transparent,
      title: Text(l10n.factoryResetDialogTitle),
      content: Text(l10n.factoryResetDialogContent),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop<void>(dialogContext),
          child: Text(
            l10n.cancel,
            style: TextStyle(
              color: Theme.of(dialogContext).colorScheme.onSurfaceVariant,
            ),
          ),
        ),
        TextButton(
          onPressed: () async {
            Navigator.pop<void>(dialogContext);
            // Deep Clean (Extensions, Prefs, Hive)
            await ref.read(settingsRepositoryProvider).deleteAllData();

            // Restart App - use caller's context; dialog context may be disposed after pop
            if (callerContext.mounted) {
              await AppUtils.restartApp(callerContext);
            }
          },
          style: TextButton.styleFrom(
            foregroundColor: Theme.of(dialogContext).colorScheme.error,
          ),
          child: Text(l10n.factoryReset),
        ),
      ],
    ),
  );
}

/// Shows a dialog to clear the image & video cache.
void showClearCacheDialog(BuildContext context, WidgetRef ref) {
  final l10n = AppLocalizations.of(context)!;
  showDialog<void>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      surfaceTintColor: Colors.transparent,
      title: Text(l10n.clearCacheDialogTitle),
      content: Text(l10n.clearCacheDialogContent),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop<void>(dialogContext),
          child: Text(
            l10n.cancel,
            style: TextStyle(
              color: Theme.of(dialogContext).colorScheme.onSurfaceVariant,
            ),
          ),
        ),
        TextButton(
          onPressed: () async {
            Navigator.pop<void>(dialogContext);
            await ref.read(settingsRepositoryProvider).clearImageVideoCache();
            ref.invalidate(cacheSizeProvider);
            ref
                .read(notificationServiceProvider)
                .showSuccess(
                  l10n.cacheCleared,
                  title: 'Storage',
                  icon: Icons.cleaning_services_rounded,
                );
          },
          style: TextButton.styleFrom(
            foregroundColor: Theme.of(dialogContext).colorScheme.error,
          ),
          child: Text(l10n.clearCacheNow),
        ),
      ],
    ),
  );
}

/// Shows a dialog to pick the application language.
void showLanguageDialog(
  BuildContext context,
  WidgetRef ref,
  Locale currentLocale,
) {
  final l10n = AppLocalizations.of(context)!;

  showDialog<void>(
    context: context,
    builder: (context) => AlertDialog(
      surfaceTintColor: Colors.transparent,
      title: Text(l10n.selectLanguage),
      content: FutureBuilder<List<Map<String, dynamic>>>(
        future: Future.wait(
          AppLocalizations.supportedLocales.map((locale) async {
            final localL10n = await AppLocalizations.delegate.load(locale);
            return {'label': localL10n.languageName, 'locale': locale};
          }),
        ),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const SizedBox(
              height: 100,
              child: Center(child: AppLoadingIndicator()),
            );
          }

          final options = snapshot.data!;

          return RadioGroup<Locale>(
            groupValue: currentLocale,
            onChanged: (val) {
              if (val == null) return;
              ref.read(localeProvider.notifier).setLocale(val);
              Navigator.pop<void>(context);
            },
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: options.map((opt) {
                  final locale = opt['locale'] as Locale;
                  final bool isCurrent = locale == currentLocale;
                  return _currentOption(
                    isCurrent: isCurrent,
                    child: ListTile(
                      autofocus: isCurrent,
                      title: Text(opt['label'] as String),
                      leading: Radio<Locale>(value: locale),
                      onTap: () {
                        ref.read(localeProvider.notifier).setLocale(locale);
                        Navigator.pop<void>(context);
                      },
                    ),
                  );
                }).toList(),
              ),
            ),
          );
        },
      ),
    ),
  );
}

/// Shows a beautiful dialog with information about the developer.
void showDeveloperDialog(BuildContext context) {
  final l10n = AppLocalizations.of(context)!;
  final colorScheme = Theme.of(context).colorScheme;

  showDialog<void>(
    context: context,
    builder: (context) => AlertDialog(
      surfaceTintColor: Colors.transparent,
      contentPadding: const EdgeInsets.all(24),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Profile Picture
            Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: colorScheme.primary.withValues(alpha: 0.2),
                  width: 4,
                ),
                boxShadow: [
                  BoxShadow(
                    color: colorScheme.primary.withValues(alpha: 0.1),
                    blurRadius: 20,
                    spreadRadius: 5,
                  ),
                ],
              ),
              child: ClipOval(
                child: Image.network(
                  'https://avatars.githubusercontent.com/u/74624467?v=4',
                  loadingBuilder: (context, child, loadingProgress) {
                    if (loadingProgress == null) return child;
                    return const Center(child: AppLoadingIndicator());
                  },
                  errorBuilder: (context, error, stackTrace) =>
                      const Icon(Icons.person_rounded, size: 50),
                ),
              ),
            ),
            const SizedBox(height: 20),
            // Name and Title
            Text(
              'Akash',
              style: Theme.of(context).textTheme.headlineSmall
                  ?.copyWith(fontWeight: FontWeight.bold, letterSpacing: 0.5),
            ),
            const SizedBox(height: 24),
            // Social Links
            Wrap(
              alignment: WrapAlignment.center,
              spacing: 12,
              runSpacing: 12,
              children: [
                _SocialButton(
                  svgUrl: 'https://raw.githubusercontent.com/simple-icons/simple-icons/11.10.0/icons/github.svg',
                  color: const Color(
                    0xFF909692,
                  ), // GitHub Official Black/Dark Grey
                  onTap: () => launchUrl(
                    Uri.parse('https://github.com/akashdh11'),
                    mode: LaunchMode.externalApplication,
                  ),
                ),
                _SocialButton(
                  svgUrl: 'https://raw.githubusercontent.com/simple-icons/simple-icons/11.10.0/icons/linkedin.svg',
                  color: const Color(0xFF2d65bc), // LinkedIn Official Blue
                  onTap: () => launchUrl(
                    Uri.parse('https://www.linkedin.com/in/akashdh11'),
                    mode: LaunchMode.externalApplication,
                  ),
                ),
                _SocialButton(
                  svgUrl: 'https://raw.githubusercontent.com/simple-icons/simple-icons/11.10.0/icons/discord.svg',
                  color: const Color(0xFF5865F2), // Discord Blurple
                  onTap: () => launchUrl(
                    Uri.parse('https://discord.gg/73XGA8Mxn9'),
                    mode: LaunchMode.externalApplication,
                  ),
                ),
                _SocialButton(
                  svgUrl: 'https://raw.githubusercontent.com/simple-icons/simple-icons/11.10.0/icons/telegram.svg',
                  color: const Color(0xFF5baae3), // Telegram Official Blue
                  onTap: () => launchUrl(
                    Uri.parse('https://t.me/+Ez5Vsv2pUUFjZmNl'),
                    mode: LaunchMode.externalApplication,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop<void>(context),
          child: Text(l10n.close),
        ),
      ],
    ),
  );
}

class _SocialButton extends StatelessWidget {
  final String svgUrl;
  final Color color;
  final VoidCallback onTap;

  const _SocialButton({
    required this.svgUrl,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Material(
      color: color.withValues(alpha: 0.15),
      shape: const CircleBorder(),
      child: IconButton(
        icon: SvgPicture.network(
          svgUrl,
          colorFilter: ColorFilter.mode(color, BlendMode.srcIn),
          width: 24,
          height: 24,
          placeholderBuilder: (context) => AppLoadingIndicator(
            color: color.withValues(alpha: 0.5),
            constraints: BoxConstraints.tight(const Size(24, 24)),
          ),
        ),
        onPressed: onTap,
        tooltip: l10n.openLink,
      ),
    );
  }
}

/// Shows a dialog to pick a [QualityPreference] for [title] (Wi-Fi or Mobile).
void showQualityDialog(
  BuildContext context,
  WidgetRef ref, {
  required String title,
  required QualityPreference current,
  required Future<void> Function(QualityPreference) onChanged,
}) {
  final l10n = AppLocalizations.of(context)!;
  const options = QualityPreference.values;
  showDialog<void>(
    context: context,
    builder: (ctx) => AlertDialog(
      surfaceTintColor: Colors.transparent,
      title: Text(title),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            RadioGroup<QualityPreference>(
              groupValue: current,
              onChanged: (val) {
                if (val == null) return;
                onChanged(val);
                Navigator.pop<void>(ctx);
              },
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: options.map((q) {
                  final bool isCurrent = q == current;
                  return _currentOption(
                    isCurrent: isCurrent,
                    child: ListTile(
                      autofocus: isCurrent,
                      title: Text(qualityPreferenceLabel(q, l10n)),
                      subtitle: q == QualityPreference.any
                          ? Text(l10n.keepSourcesOriginalOrder)
                          : null,
                      leading: Radio<QualityPreference>(value: q),
                      onTap: () {
                        onChanged(q);
                        Navigator.pop<void>(ctx);
                      },
                    ),
                  );
                }).toList(),
              ),
            ),
            const Divider(height: 24),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.info_outline_rounded,
                    size: 14,
                    color: Theme.of(ctx).colorScheme.onSurfaceVariant,
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      l10n.qualityNotGuaranteed,
                      style: Theme.of(ctx).textTheme.bodySmall?.copyWith(
                        color: Theme.of(ctx).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

/// Shows a dialog to pick a [QualityFilterMode].
/// Controls whether sources that don't match the quality preference are hidden.
void showQualityFilterModeDialog(
  BuildContext context,
  WidgetRef ref, {
  required QualityFilterMode current,
  required Future<void> Function(QualityFilterMode) onChanged,
}) {
  const options = [
    (
      mode: QualityFilterMode.any,
      label: 'Show all (sort only)',
      subtitle:
          'Sources are sorted by your quality preference but none are hidden.',
    ),
    (
      mode: QualityFilterMode.atOrAbove,
      label: 'Hide sources below preference',
      subtitle:
          'Only sources at or above your preferred quality are shown. '
          'Falls back to all sources if nothing qualifies.',
    ),
    (
      mode: QualityFilterMode.atOrBelow,
      label: 'Hide sources above preference',
      subtitle:
          'Only sources at or below your preferred quality are shown '
          '(data-saver mode).',
    ),
  ];

  showDialog<void>(
    context: context,
    builder: (ctx) => AlertDialog(
      surfaceTintColor: Colors.transparent,
      title: const Text('Quality Filter Mode'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            RadioGroup<QualityFilterMode>(
              groupValue: current,
              onChanged: (val) {
                if (val == null) return;
                onChanged(val);
                Navigator.pop<void>(ctx);
              },
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: options.map((opt) {
                  final bool isCurrent = opt.mode == current;
                  return _currentOption(
                    isCurrent: isCurrent,
                    child: ListTile(
                      autofocus: isCurrent,
                      title: Text(opt.label),
                      subtitle: Text(opt.subtitle),
                      leading: Radio<QualityFilterMode>(value: opt.mode),
                      onTap: () {
                        onChanged(opt.mode);
                        Navigator.pop<void>(ctx);
                      },
                    ),
                  );
                }).toList(),
              ),
            ),
            const Divider(height: 24),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.info_outline_rounded,
                    size: 14,
                    color: Theme.of(ctx).colorScheme.onSurfaceVariant,
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      'The quality preference (Wi-Fi / Mobile) controls '
                      'which tier is used as the threshold for this filter.',
                      style: Theme.of(ctx).textTheme.bodySmall?.copyWith(
                        color: Theme.of(ctx).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

/// One row of [showPlayerControlsDialog].
typedef _ControlToggle = ({
  IconData icon,
  String label,
  Future<void> Function(bool) setter,
  bool initial,
});

/// Whether the player would actually build a picture-in-picture button on a
/// device of this shape.
///
/// Deliberately the same predicate as `_pipAvailable` in
/// `vlc_player_screen.dart`: only Android gives us an OS-level PiP window, and
/// a television has nothing to shrink into. Everywhere else the screen passes
/// a null `onEnterPip` and the button is never built, so the *setting* for it
/// cannot change anything.
bool playerCanShowPip(TargetPlatform platform, PlayerFormFactor form) =>
    platform == TargetPlatform.android && form != PlayerFormFactor.tv;

/// Shows a dialog to toggle the visibility of individual player control
/// buttons. Changes apply live via the player settings notifier.
///
/// Only offers a switch for a button this device can actually draw. One row is
/// conditional on hardware: picture-in-picture exists only on an Android
/// handset or tablet. Offering the platforms that have no such window a switch
/// that moves a stored boolean and changes nothing on screen is the screen
/// lying about what it controls.
///
/// There is deliberately no rotate row. The player's manual rotate button went
/// away when orientation started following the video's own shape, so the
/// switch that hid it had nothing left to hide.
void showPlayerControlsDialog(BuildContext context, WidgetRef ref) {
  final l10n = AppLocalizations.of(context)!;
  final notifier = ref.read(playerSettingsProvider.notifier);
  final settings =
      ref.read(playerSettingsProvider).asData?.value ?? const PlayerSettings();

  final platform = Theme.of(context).platform;
  final form = playerFormFactorOf(
    ref.read(deviceProfileProvider).asData?.value,
  );

  final rows = <_ControlToggle>[
    if (playerCanShowPip(platform, form))
      (
        icon: Icons.picture_in_picture_alt_rounded,
        label: l10n.showPip,
        setter: notifier.setShowPip,
        initial: settings.showPip,
      ),
    (
      icon: Icons.aspect_ratio_rounded,
      label: l10n.showResize,
      setter: notifier.setShowResize,
      initial: settings.showResize,
    ),
    (
      icon: Icons.speed_rounded,
      label: l10n.showPlaybackSpeed,
      setter: notifier.setShowPlaybackSpeed,
      initial: settings.showPlaybackSpeed,
    ),
    (
      icon: Icons.playlist_play_rounded,
      label: l10n.showEpisodes,
      setter: notifier.setShowEpisodes,
      initial: settings.showEpisodes,
    ),
  ];
  final values = rows.map((row) => row.initial).toList();

  showDialog<void>(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (context, setState) {
        return AlertDialog(
          surfaceTintColor: Colors.transparent,
          title: Text(l10n.playerControls),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (var i = 0; i < rows.length; i++)
                  SwitchListTile(
                    secondary: Icon(rows[i].icon),
                    title: Text(rows[i].label),
                    value: values[i],
                    onChanged: (val) {
                      rows[i].setter(val);
                      setState(() => values[i] = val);
                    },
                  ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop<void>(ctx),
              child: Text(
                l10n.close,
                style: TextStyle(
                  color: Theme.of(ctx).colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          ],
        );
      },
    ),
  );
}

/// Shows a dialog to enter OpenSubtitles.com credentials.
void showOpenSubtitlesAuthDialog(
  BuildContext context,
  WidgetRef ref,
  PlayerSettings settings,
) {
  showDialog<void>(
    context: context,
    builder: (_) => _OpenSubtitlesAuthDialog(settings: settings),
  );
}

class _OpenSubtitlesAuthDialog extends ConsumerStatefulWidget {
  final PlayerSettings settings;

  const _OpenSubtitlesAuthDialog({required this.settings});

  @override
  ConsumerState<_OpenSubtitlesAuthDialog> createState() =>
      _OpenSubtitlesAuthDialogState();
}

class _OpenSubtitlesAuthDialogState
    extends ConsumerState<_OpenSubtitlesAuthDialog> {
  late final TextEditingController _userController = TextEditingController(
    text: widget.settings.osUsername,
  );
  late final TextEditingController _passController = TextEditingController(
    text: widget.settings.osPassword,
  );
  late final TextEditingController _keyController = TextEditingController(
    text: widget.settings.osApiKey,
  );
  bool _isVerifying = false;
  bool? _verifyResult;
  var _isObscure = true;

  @override
  void dispose() {
    _userController.dispose();
    _passController.dispose();
    _keyController.dispose();
    super.dispose();
  }

  Future<void> _verify() async {
    setState(() {
      _isVerifying = true;
      _verifyResult = null;
    });
    final ok = await ref
        .read(playerSettingsProvider.notifier)
        .verifyOpenSubtitles(
          _userController.text.trim(),
          _passController.text.trim(),
          _keyController.text.trim(),
        );
    if (mounted) {
      setState(() {
        _isVerifying = false;
        _verifyResult = ok;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final verifyResult = _verifyResult;

    return FocusTraversalGroup(
      policy: WidgetOrderTraversalPolicy(),
      child: AlertDialog(
        surfaceTintColor: Colors.transparent,
        title: Row(
          children: [
            const Icon(Icons.subtitles_rounded, color: Colors.blue),
            const SizedBox(width: 12),
            Text(l10n.openSubtitles),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                l10n.openSubtitlesAuthSubtitle,
                style: TextStyle(
                  fontSize: 13,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 16),
              // First, not last: without a key the provider answers every
              // search with an empty list and the credentials below are never
              // sent anywhere.
              CustomTextField(
                controller: _keyController,
                autofocus: true,
                textInputAction: TextInputAction.next,
                decoration: InputDecoration(
                  labelText: l10n.apiKey,
                  prefixIcon: const Icon(Icons.key_rounded, size: 20),
                ),
              ),
              const SizedBox(height: 12),
              CustomTextField(
                controller: _userController,
                textInputAction: TextInputAction.next,
                decoration: InputDecoration(
                  labelText: l10n.username,
                  prefixIcon: const Icon(Icons.person_outline, size: 20),
                ),
              ),
              const SizedBox(height: 12),
              CustomTextField(
                controller: _passController,
                obscureText: _isObscure,
                decoration: InputDecoration(
                  labelText: l10n.password,
                  prefixIcon: const Icon(Icons.lock_outline, size: 20),
                  suffixIcon: ExcludeFocus(
                    child: IconButton(
                      icon: Icon(
                        _isObscure ? Icons.visibility_off : Icons.visibility,
                        size: 20,
                      ),
                      onPressed: () => setState(() => _isObscure = !_isObscure),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              TextButton.icon(
                onPressed: () => launchUrl(
                  Uri.parse('https://www.opensubtitles.com/en/users/sign_up'),
                  mode: LaunchMode.externalApplication,
                ),
                icon: const Icon(Icons.open_in_new_rounded, size: 16),
                label: Text(l10n.noAccountRegister),
                style: TextButton.styleFrom(
                  visualDensity: VisualDensity.compact,
                  textStyle: const TextStyle(fontSize: 12),
                ),
              ),
              if (verifyResult != null) ...[
                const SizedBox(height: 8),
                Row(
                  children: [
                    Icon(
                      verifyResult
                          ? Icons.check_circle_outline_rounded
                          : Icons.error_outline_rounded,
                      color: verifyResult ? Colors.green : Colors.red,
                      size: 16,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      verifyResult
                          ? l10n.connectedSuccessfully
                          : l10n.connectionFailed,
                      style: TextStyle(
                        color: verifyResult ? Colors.green : Colors.red,
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ],
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: _isVerifying ? null : _verify,
                  icon: _isVerifying
                      ? const AppLoadingIndicator(
                          constraints: BoxConstraints(
                            minWidth: 16,
                            minHeight: 16,
                            maxWidth: 16,
                            maxHeight: 16,
                          ),
                        )
                      : const Icon(
                          Icons.check_circle_outline_rounded,
                          size: 18,
                        ),
                  label: Text(l10n.testConnection),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        actions: [
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton(
                onPressed: _isVerifying
                    ? null
                    : () => Navigator.pop<void>(context),
                child: Text(
                  l10n.cancel,
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              CustomButton(
                isPrimary: true,
                onPressed: _isVerifying
                    ? null
                    : () {
                        ref
                            .read(playerSettingsProvider.notifier)
                            .setOpenSubtitlesCredentials(
                              _userController.text.trim(),
                              _passController.text.trim(),
                              _keyController.text.trim(),
                            );
                        Navigator.pop<void>(context);
                      },
                child: Text(l10n.save),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Shows a dialog to enter SubDL Account credentials.
void showSubDlAuthDialog(
  BuildContext context,
  WidgetRef ref,
  PlayerSettings settings,
) {
  showDialog<void>(
    context: context,
    builder: (_) => _SubDlAuthDialog(settings: settings),
  );
}

class _SubDlAuthDialog extends ConsumerStatefulWidget {
  final PlayerSettings settings;

  const _SubDlAuthDialog({required this.settings});

  @override
  ConsumerState<_SubDlAuthDialog> createState() => _SubDlAuthDialogState();
}

class _SubDlAuthDialogState extends ConsumerState<_SubDlAuthDialog> {
  late final TextEditingController _apiKeyController = TextEditingController(
    text: widget.settings.subdlApiKey,
  );
  late final TextEditingController _emailController = TextEditingController(
    text: widget.settings.subdlEmail,
  );
  late final TextEditingController _passController = TextEditingController(
    text: widget.settings.subdlPassword,
  );
  bool _isFetching = false;
  String? _fetchError;
  bool _isObscure = true;
  bool _isVerifyingKey = false;
  bool? _verifyKeyResult;

  bool get _busy => _isFetching || _isVerifyingKey;

  @override
  void dispose() {
    _apiKeyController.dispose();
    _emailController.dispose();
    _passController.dispose();
    super.dispose();
  }

  Future<void> _fetchKey() async {
    setState(() {
      _isFetching = true;
      _fetchError = null;
      _verifyKeyResult = null;
    });
    final result = await ref
        .read(playerSettingsProvider.notifier)
        .verifySubDl(_emailController.text.trim(), _passController.text.trim());
    if (mounted) {
      setState(() {
        _isFetching = false;
        if (result.key != null) {
          _apiKeyController.text = result.key!;
        } else {
          _fetchError = result.error;
        }
      });
    }
  }

  Future<void> _verifyKey() async {
    setState(() {
      _isVerifyingKey = true;
      _verifyKeyResult = null;
      _fetchError = null;
    });
    final ok = await ref
        .read(playerSettingsProvider.notifier)
        .verifySubDlKey(_apiKeyController.text.trim());
    if (mounted) {
      setState(() {
        _isVerifyingKey = false;
        _verifyKeyResult = ok;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final fetchError = _fetchError;
    final verifyKeyResult = _verifyKeyResult;

    return FocusTraversalGroup(
      policy: WidgetOrderTraversalPolicy(),
      child: AlertDialog(
        surfaceTintColor: Colors.transparent,
        title: const Row(
          children: [
            Icon(Icons.vpn_key_rounded, color: Colors.orange),
            SizedBox(width: 12),
            Text('SubDL API Key'),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                l10n.subDlAuthSubtitle,
                style: TextStyle(
                  fontSize: 13,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 16),
              CustomTextField(
                controller: _apiKeyController,
                autofocus: true,
                textInputAction: TextInputAction.next,
                decoration: InputDecoration(
                  labelText: l10n.apiKey,
                  prefixIcon: const Icon(Icons.key_rounded, size: 20),
                ),
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  const Expanded(child: Divider()),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: Text(
                      'OR FETCH VIA ACCOUNT',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: theme.colorScheme.onSurfaceVariant.withValues(
                          alpha: 0.6,
                        ),
                      ),
                    ),
                  ),
                  const Expanded(child: Divider()),
                ],
              ),
              const SizedBox(height: 16),
              CustomTextField(
                controller: _emailController,
                textInputAction: TextInputAction.next,
                decoration: InputDecoration(
                  labelText: l10n.email,
                  prefixIcon: const Icon(Icons.email_outlined, size: 20),
                ),
              ),
              const SizedBox(height: 12),
              CustomTextField(
                controller: _passController,
                obscureText: _isObscure,
                decoration: InputDecoration(
                  labelText: l10n.password,
                  prefixIcon: const Icon(Icons.lock_outline, size: 20),
                  suffixIcon: ExcludeFocus(
                    child: IconButton(
                      icon: Icon(
                        _isObscure ? Icons.visibility_off : Icons.visibility,
                        size: 20,
                      ),
                      onPressed: () => setState(() => _isObscure = !_isObscure),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: _busy ? null : _fetchKey,
                  icon: _isFetching
                      ? const AppLoadingIndicator(
                          color: Colors.white,
                          constraints: BoxConstraints(
                            minWidth: 16,
                            minHeight: 16,
                            maxWidth: 16,
                            maxHeight: 16,
                          ),
                        )
                      : const Icon(Icons.download_rounded, size: 18),
                  label: Text(l10n.fetchMyApiKey),
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    backgroundColor: theme.colorScheme.primary.withValues(
                      alpha: 0.8,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              TextButton.icon(
                onPressed: () => launchUrl(
                  Uri.parse('https://subdl.com/panel/api'),
                  mode: LaunchMode.externalApplication,
                ),
                icon: const Icon(Icons.open_in_new_rounded, size: 16),
                label: Text(l10n.noAccountRegister),
                style: TextButton.styleFrom(
                  visualDensity: VisualDensity.compact,
                  textStyle: const TextStyle(fontSize: 12),
                ),
              ),
              if (fetchError != null || verifyKeyResult != null) ...[
                const SizedBox(height: 8),
                Row(
                  children: [
                    Icon(
                      fetchError != null || verifyKeyResult == false
                          ? Icons.error_outline_rounded
                          : Icons.check_circle_outline_rounded,
                      color: fetchError != null || verifyKeyResult == false
                          ? Colors.red
                          : Colors.green,
                      size: 16,
                    ),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        fetchError ??
                            (verifyKeyResult!
                                ? l10n.keyVerified
                                : l10n.invalidApiKey),
                        style: TextStyle(
                          color: fetchError != null || verifyKeyResult == false
                              ? Colors.red
                              : Colors.green,
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: _busy ? null : _verifyKey,
                  icon: _isVerifyingKey
                      ? const AppLoadingIndicator(
                          constraints: BoxConstraints(
                            minWidth: 16,
                            minHeight: 16,
                            maxWidth: 16,
                            maxHeight: 16,
                          ),
                        )
                      : const Icon(
                          Icons.check_circle_outline_rounded,
                          size: 18,
                        ),
                  label: Text(l10n.testConnection),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        actions: [
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton(
                onPressed: _busy ? null : () => Navigator.pop<void>(context),
                child: Text(
                  l10n.cancel,
                  style: TextStyle(color: theme.colorScheme.onSurfaceVariant),
                ),
              ),
              const SizedBox(width: 8),
              CustomButton(
                isPrimary: true,
                onPressed: _busy
                    ? null
                    : () {
                        ref
                            .read(playerSettingsProvider.notifier)
                            .setSubDlAuth(
                              apiKey: _apiKeyController.text.trim(),
                              email: _emailController.text.trim(),
                              pass: _passController.text.trim(),
                            );
                        Navigator.pop<void>(context);
                      },
                child: Text(l10n.save),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Shows a dialog to enter SubSource API Key.
void showSubSourceAuthDialog(
  BuildContext context,
  WidgetRef ref,
  PlayerSettings settings,
) {
  showDialog<void>(
    context: context,
    builder: (_) => _SubSourceAuthDialog(settings: settings),
  );
}

class _SubSourceAuthDialog extends ConsumerStatefulWidget {
  final PlayerSettings settings;

  const _SubSourceAuthDialog({required this.settings});

  @override
  ConsumerState<_SubSourceAuthDialog> createState() =>
      _SubSourceAuthDialogState();
}

class _SubSourceAuthDialogState extends ConsumerState<_SubSourceAuthDialog> {
  late final TextEditingController _keyController = TextEditingController(
    text: widget.settings.subsourceApiKey,
  );
  bool _isVerifying = false;
  bool? _verifyResult;

  @override
  void dispose() {
    _keyController.dispose();
    super.dispose();
  }

  Future<void> _verify() async {
    setState(() {
      _isVerifying = true;
      _verifyResult = null;
    });
    final ok = await ref
        .read(playerSettingsProvider.notifier)
        .verifySubSource(_keyController.text.trim());
    if (mounted) {
      setState(() {
        _isVerifying = false;
        _verifyResult = ok;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final verifyResult = _verifyResult;

    return FocusTraversalGroup(
      policy: WidgetOrderTraversalPolicy(),
      child: AlertDialog(
        surfaceTintColor: Colors.transparent,
        title: const Row(
          children: [
            Icon(Icons.vpn_key_rounded, color: Colors.blue),
            SizedBox(width: 12),
            Text('SubSource API Key'),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                l10n.subSourceAuthSubtitle,
                style: TextStyle(
                  fontSize: 13,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 16),
              CustomTextField(
                controller: _keyController,
                autofocus: true,
                decoration: InputDecoration(
                  labelText: l10n.apiKeyOptionalOverride,
                  prefixIcon: const Icon(Icons.key_rounded, size: 20),
                  hintText: l10n.enterKeyToOverrideDefault,
                ),
              ),
              const SizedBox(height: 12),
              TextButton.icon(
                onPressed: () => launchUrl(
                  Uri.parse('https://subsource.net/dashboard/profile'),
                  mode: LaunchMode.externalApplication,
                ),
                icon: const Icon(Icons.open_in_new_rounded, size: 16),
                label: Text(l10n.getApiKeyFromProfile),
                style: TextButton.styleFrom(
                  visualDensity: VisualDensity.compact,
                  textStyle: const TextStyle(fontSize: 12),
                ),
              ),
              if (verifyResult != null) ...[
                const SizedBox(height: 8),
                Row(
                  children: [
                    Icon(
                      verifyResult
                          ? Icons.check_circle_outline_rounded
                          : Icons.error_outline_rounded,
                      color: verifyResult ? Colors.green : Colors.red,
                      size: 16,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      verifyResult ? l10n.keyVerified : l10n.invalidApiKey,
                      style: TextStyle(
                        color: verifyResult ? Colors.green : Colors.red,
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ],
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: _isVerifying ? null : _verify,
                  icon: _isVerifying
                      ? const AppLoadingIndicator(
                          constraints: BoxConstraints(
                            minWidth: 16,
                            minHeight: 16,
                            maxWidth: 16,
                            maxHeight: 16,
                          ),
                        )
                      : const Icon(
                          Icons.check_circle_outline_rounded,
                          size: 18,
                        ),
                  label: Text(l10n.testConnection),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        actions: [
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton(
                onPressed: _isVerifying
                    ? null
                    : () => Navigator.pop<void>(context),
                child: Text(
                  l10n.cancel,
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              CustomButton(
                isPrimary: true,
                onPressed: _isVerifying
                    ? null
                    : () {
                        ref
                            .read(playerSettingsProvider.notifier)
                            .setSubSourceApiKey(_keyController.text.trim());
                        Navigator.pop<void>(context);
                      },
                child: Text(l10n.save),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Volume boost
// ---------------------------------------------------------------------------

void showMaxVolumeDialog(
  BuildContext context,
  WidgetRef ref,
  PlayerSettings settings,
) {
  showDialog<void>(
    context: context,
    builder: (ctx) {
      var value = settings.maxVolumePercent.toDouble().clamp(100.0, 200.0);
      return StatefulBuilder(
        builder: (ctx, setState) => AlertDialog(
          surfaceTintColor: Colors.transparent,
          title: const Text('Maximum volume'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${value.round()}%',
                style: Theme.of(ctx).textTheme.headlineSmall
                    ?.copyWith(fontWeight: FontWeight.bold),
              ),
              CustomSlider(
                value: value,
                min: 100,
                max: 200,
                divisions: 10,
                step: 10.0,
                onChanged: (v) => setState(() => value = v),
              ),
              const SizedBox(height: 4),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.info_outline_rounded,
                    size: 18,
                    color: Theme.of(ctx).colorScheme.onSurfaceVariant,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Above 100% the built-in player amplifies the audio. '
                      'Loud settings can distort quiet recordings and are not '
                      'available on the ExoPlayer/AVPlayer engine.',
                      style: Theme.of(ctx).textTheme.bodySmall,
                    ),
                  ),
                ],
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop<void>(ctx),
              child: Text(AppLocalizations.of(ctx)!.cancel),
            ),
            FilledButton(
              onPressed: () {
                ref
                    .read(playerSettingsProvider.notifier)
                    .setMaxVolumePercent(value.round());
                Navigator.pop<void>(ctx);
              },
              child: Text(AppLocalizations.of(ctx)!.save),
            ),
          ],
        ),
      );
    },
  );
}

/// Lets the user paste their own TMDB API key.
///
/// Why this exists: the key is normally baked in at build time via
/// `--dart-define=TMDB_API_KEY`, which comes from a CI secret. When that
/// secret is unset the APK ships with an empty key and every TMDB-backed
/// screen (Stream, Explore, Details) silently has nothing to show. This
/// dialog gives users a way out without rebuilding the app.
///
/// The key is validated against the live API before saving so a typo is
/// caught here rather than surfacing as an empty grid later.
void showTmdbApiKeyDialog(BuildContext context, WidgetRef ref) {
  showDialog<void>(context: context, builder: (_) => const _TmdbApiKeyDialog());
}

class _TmdbApiKeyDialog extends ConsumerStatefulWidget {
  const _TmdbApiKeyDialog();

  @override
  ConsumerState<_TmdbApiKeyDialog> createState() => _TmdbApiKeyDialogState();
}

class _TmdbApiKeyDialogState extends ConsumerState<_TmdbApiKeyDialog> {
  late final TextEditingController _controller = TextEditingController(
    text: ref.read(generalSettingsProvider).tmdbApiKey,
  );
  var _isChecking = false;
  String? _errorText;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final key = _controller.text.trim();

    // Empty is a legitimate input: it clears the override and falls
    // back to the build-time key.
    if (key.isEmpty) {
      await ref.read(generalSettingsProvider.notifier).setTmdbApiKey('');
      if (mounted) Navigator.pop<void>(context);
      return;
    }

    setState(() {
      _isChecking = true;
      _errorText = null;
    });

    var valid = false;
    try {
      final dio = ref.read(dioClientProvider);
      final res = await dio.get<Map<String, dynamic>>(
        '${TmdbConfig.baseUrl}/authentication',
        queryParameters: {'api_key': key},
        options: Options(
          validateStatus: (s) => s != null && s < 500,
          receiveTimeout: const Duration(seconds: 15),
        ),
      );
      valid = res.statusCode == 200;
    } catch (_) {
      // Network failure is not the same as a bad key; fall through to
      // the generic message so an offline user isn't told their key
      // is wrong.
      valid = false;
    }

    if (!mounted) return;

    if (!valid) {
      setState(() {
        _isChecking = false;
        _errorText =
            'Could not verify this key. Check the key and your '
            'connection, then try again.';
      });
      return;
    }

    await ref.read(generalSettingsProvider.notifier).setTmdbApiKey(key);

    if (mounted) Navigator.pop<void>(context);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return AlertDialog(
      surfaceTintColor: Colors.transparent,
      title: const Text('TMDB API key'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Stream and Explore use TMDB for posters, titles and '
              'search. Paste a free API key to enable them.',
            ),
            const SizedBox(height: 12),
            CustomTextField(
              controller: _controller,
              autofocus: true,
              decoration: InputDecoration(
                labelText: 'API key (v3 auth)',
                hintText: 'e.g. 0123456789abcdef0123456789abcdef',
                errorText: _errorText,
                prefixIcon: const Icon(Icons.vpn_key_rounded, size: 20),
              ),
              keyboardType: TextInputType.text,
            ),
            const SizedBox(height: 12),
            InkWell(
              onTap: () => launchUrl(
                Uri.parse('https://www.themoviedb.org/settings/api'),
                mode: LaunchMode.externalApplication,
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.open_in_new_rounded, size: 16),
                    const SizedBox(width: 6),
                    Flexible(
                      child: Text(
                        'Get a free key from themoviedb.org',
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.primary,
                          decoration: TextDecoration.underline,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            if (_isChecking) ...[
              const SizedBox(height: 16),
              const Row(
                children: [
                  SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                  SizedBox(width: 10),
                  Text('Verifying key...'),
                ],
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isChecking ? null : () => Navigator.pop<void>(context),
          child: Text(l10n.cancel),
        ),
        TextButton(
          onPressed: _isChecking ? null : _save,
          child: Text(l10n.save),
        ),
      ],
    );
  }
}
