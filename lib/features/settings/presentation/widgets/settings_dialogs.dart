import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../../../../shared/widgets/custom_widgets.dart';
import '../../../../core/services/external_player_service.dart';
import '../../../../core/network/doh_service.dart';
import '../../../../core/storage/settings_repository.dart';
import '../../../../core/theme/theme_provider.dart';
import '../../../../core/utils/app_utils.dart';
import '../../../../shared/widgets/loading_indicator.dart';
import '../player_settings_provider.dart';
import '../../../../core/utils/stream_quality_sorter.dart';
import '../general_settings_provider.dart';
import '../../../../core/providers/locale_provider.dart';
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
              return ListTile(
                title: Text(opt['label']!),
                leading: Radio<String>(value: opt['route']!),
                onTap: () {
                  ref
                      .read(generalSettingsProvider.notifier)
                      .setDefaultHomeScreen(opt['route']!);
                  Navigator.pop<void>(context);
                },
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
              return ListTile(
                title: Text(opt['label']!),
                leading: Radio<String>(value: opt['value']!),
                onTap: () {
                  ref
                      .read(generalSettingsProvider.notifier)
                      .setTitlePosition(opt['value']!);
                  Navigator.pop<void>(context);
                },
              );
            }).toList(),
          ),
        ),
      ),
    ),
  );
}

// Must be used inside a RadioGroup<ThemeMode> ancestor.
Widget _buildThemeOption(String title, ThemeMode value, VoidCallback onSelect) {
  return ListTile(
    title: Text(title),
    leading: Radio<ThemeMode>(value: value),
    onTap: onSelect,
  );
}

/// Formats seek duration for display (e.g. "10 sec", "2 min").
String formatSeekDuration(int seconds, AppLocalizations l10n) {
  if (seconds >= 60) {
    return '${seconds ~/ 60} ${l10n.min}';
  }
  return '$seconds ${l10n.sec}';
}

/// Formats readahead seconds for display (e.g. "5 min", "10 min").
String formatReadahead(int seconds, AppLocalizations l10n) {
  return '${seconds ~/ 60} ${l10n.min}';
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
              return ListTile(
                title: Text(label),
                leading: Radio<PlayerGesture>(value: g),
                onTap: () {
                  if (isLeft) {
                    ref.read(playerSettingsProvider.notifier).setLeftGesture(g);
                  } else {
                    ref
                        .read(playerSettingsProvider.notifier)
                        .setRightGesture(g);
                  }
                  Navigator.pop<void>(context);
                },
              );
            }).toList(),
          ),
        ),
      ),
    ),
  );
}

/// Shows a dialog to pick the seek duration.
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
              return ListTile(
                title: Text(formatSeekDuration(sec, l10n)),
                leading: Radio<int>(value: sec),
                onTap: () {
                  ref
                      .read(playerSettingsProvider.notifier)
                      .setSeekDuration(sec);
                  Navigator.pop<void>(context);
                },
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
              return ListTile(
                title: Text(e['label']!),
                leading: Radio<String>(value: e['value']!),
                onTap: () {
                  ref
                      .read(playerSettingsProvider.notifier)
                      .setDefaultResizeMode(e['value']!);
                  Navigator.pop<void>(ctx);
                },
              );
            }).toList(),
          ),
        ),
      ),
    ),
  );
}

/// Shows a dialog to pick the readahead duration (5-10 min).
void showReadaheadDialog(BuildContext context, WidgetRef ref, int current) {
  final l10n = AppLocalizations.of(context)!;
  // 1 to 20 minutes in 1-minute steps
  final options = List.generate(20, (i) => (1 + i) * 60);

  showDialog<void>(
    context: context,
    builder: (context) => AlertDialog(
      surfaceTintColor: Colors.transparent,
      title: Text(l10n.selectBufferDepth),
      content: RadioGroup<int>(
        groupValue: current,
        onChanged: (val) {
          if (val == null) return;
          ref.read(playerSettingsProvider.notifier).setReadaheadSeconds(val);
          Navigator.pop<void>(context);
        },
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: options.map((sec) {
              return ListTile(
                title: Text(formatReadahead(sec, l10n)),
                leading: Radio<int>(value: sec),
                onTap: () {
                  ref
                      .read(playerSettingsProvider.notifier)
                      .setReadaheadSeconds(sec);
                  Navigator.pop<void>(context);
                },
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
  final platformPlayers = ExternalPlayerService.instance
      .getPlayersForPlatform();

  showDialog<void>(
    context: context,
    builder: (context) => AlertDialog(
      surfaceTintColor: Colors.transparent,
      title: Text(l10n.defaultPlayer),
      content: SingleChildScrollView(
        child: RadioGroup<String?>(
          groupValue: currentPlayerId,
          onChanged: (val) {
            ref.read(playerSettingsProvider.notifier).setPreferredPlayer(val);
            Navigator.pop<void>(context);
          },
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                title: Text(l10n.internalPlayer),
                subtitle: Text(l10n.builtInPlayer),
                leading: const Radio<String?>(value: null),
                trailing: const Icon(Icons.play_circle_filled_rounded),
                onTap: () {
                  ref
                      .read(playerSettingsProvider.notifier)
                      .setPreferredPlayer(null);
                  Navigator.pop<void>(context);
                },
              ),
              const Divider(),
              ...platformPlayers.map((player) {
                return ListTile(
                  title: Text(player.displayName),
                  leading: Radio<String?>(value: player.id),
                  trailing: Icon(player.icon),
                  onTap: () {
                    ref
                        .read(playerSettingsProvider.notifier)
                        .setPreferredPlayer(player.id);
                    Navigator.pop<void>(context);
                  },
                );
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

/// Shows a dialog to pick the DNS-over-HTTPS provider.
void showDohProviderDialog(BuildContext context, WidgetRef ref) {
  final l10n = AppLocalizations.of(context)!;
  final initialSettings = ref.read(dohSettingsProvider).asData?.value;
  var currentProvider = initialSettings?.provider ?? DohProvider.cloudflare;
  final controller = TextEditingController(
    text: initialSettings?.customUrl ?? '',
  );

  showDialog<void>(
    context: context,
    builder: (ctx) {
      void saveAndClose(DohProvider p, [String? customUrl]) {
        ref.read(dohSettingsProvider.notifier).setProvider(p);
        if (p == DohProvider.custom && customUrl != null) {
          ref.read(dohSettingsProvider.notifier).setCustomUrl(customUrl);
        }
        ref.read(dohSettingsProvider.notifier).clearCache();
        Navigator.pop<void>(ctx);
      }

      return StatefulBuilder(
        builder: (context, setState) {
          return AlertDialog(
            surfaceTintColor: Colors.transparent,
            title: Text(l10n.dohProvider),
            content: SingleChildScrollView(
              child: RadioGroup<DohProvider>(
                groupValue: currentProvider,
                onChanged: (val) {
                  if (val == null) return;
                  if (val == DohProvider.custom) {
                    setState(() => currentProvider = val);
                  } else {
                    saveAndClose(val);
                  }
                },
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    ListTile(
                      title: Text(l10n.cloudflare),
                      subtitle: const Text('1.1.1.1'),
                      leading: const Radio<DohProvider>(
                        value: DohProvider.cloudflare,
                      ),
                      onTap: () => saveAndClose(DohProvider.cloudflare),
                    ),
                    ListTile(
                      title: Text(l10n.google),
                      subtitle: const Text('8.8.8.8'),
                      leading: const Radio<DohProvider>(
                        value: DohProvider.google,
                      ),
                      onTap: () => saveAndClose(DohProvider.google),
                    ),
                    ListTile(
                      title: Text(l10n.adguard),
                      subtitle: const Text('dns.adguard.com'),
                      leading: const Radio<DohProvider>(
                        value: DohProvider.adguard,
                      ),
                      onTap: () => saveAndClose(DohProvider.adguard),
                    ),
                    ListTile(
                      title: Text(l10n.dnsWatch),
                      subtitle: const Text('resolver2.dns.watch'),
                      leading: const Radio<DohProvider>(
                        value: DohProvider.dnsWatch,
                      ),
                      onTap: () => saveAndClose(DohProvider.dnsWatch),
                    ),
                    ListTile(
                      title: Text(l10n.quad9),
                      subtitle: const Text('9.9.9.9'),
                      leading: const Radio<DohProvider>(
                        value: DohProvider.quad9,
                      ),
                      onTap: () => saveAndClose(DohProvider.quad9),
                    ),
                    ListTile(
                      title: Text(l10n.dnsSb),
                      subtitle: const Text('doh.dns.sb'),
                      leading: const Radio<DohProvider>(
                        value: DohProvider.dnsSb,
                      ),
                      onTap: () => saveAndClose(DohProvider.dnsSb),
                    ),
                    ListTile(
                      title: Text(l10n.canadianShield),
                      subtitle: const Text('private.canadianshield.cira.ca'),
                      leading: const Radio<DohProvider>(
                        value: DohProvider.canadianShield,
                      ),
                      onTap: () => saveAndClose(DohProvider.canadianShield),
                    ),
                    ListTile(
                      title: Text(l10n.custom),
                      subtitle: Text(l10n.enterCustomDohUrl),
                      leading: const Radio<DohProvider>(
                        value: DohProvider.custom,
                      ),
                      onTap: () =>
                          setState(() => currentProvider = DohProvider.custom),
                    ),
                    if (currentProvider == DohProvider.custom)
                      Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16.0,
                          vertical: 8.0,
                        ),
                        child: CustomTextField(
                          controller: controller,
                          autofocus: true,
                          decoration: InputDecoration(
                            labelText: l10n.customDohUrlLabel,
                            hintText: 'https://...',
                            prefixIcon: const Icon(
                              Icons.link_rounded,
                              size: 20,
                            ),
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
                onPressed: () => Navigator.pop<void>(ctx),
                child: Text(
                  l10n.cancel,
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
              if (currentProvider == DohProvider.custom)
                CustomButton(
                  isPrimary: true,
                  onPressed: () {
                    final url = controller.text.trim();
                    if (url.isNotEmpty) {
                      saveAndClose(DohProvider.custom, url);
                    }
                  },
                  child: Text(l10n.save),
                ),
            ],
          );
        },
      );
    },
  );
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
              _buildThemeOption(l10n.system, ThemeMode.system, () {
                ref
                    .read(appThemeModeProvider.notifier)
                    .setThemeMode(ThemeMode.system);
                Navigator.pop<void>(context);
              }),
              _buildThemeOption(l10n.dark, ThemeMode.dark, () {
                ref
                    .read(appThemeModeProvider.notifier)
                    .setThemeMode(ThemeMode.dark);
                Navigator.pop<void>(context);
              }),
              _buildThemeOption(l10n.light, ThemeMode.light, () {
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

            // Clear Preferences ONLY
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
                  return ListTile(
                    title: Text(opt['label'] as String),
                    leading: Radio<Locale>(value: locale),
                    onTap: () {
                      ref.read(localeProvider.notifier).setLocale(locale);
                      Navigator.pop<void>(context);
                    },
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
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
                letterSpacing: 0.5,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Fullstack & Flutter Developer',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: colorScheme.onSurfaceVariant,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 24),
            // Social Links
            Wrap(
              alignment: WrapAlignment.center,
              spacing: 12,
              runSpacing: 12,
              children: [
                _SocialButton(
                  svgUrl:
                      'https://raw.githubusercontent.com/simple-icons/simple-icons/11.10.0/icons/github.svg',
                  color: const Color(
                    0xFF909692,
                  ), // GitHub Official Black/Dark Grey
                  onTap: () => launchUrl(
                    Uri.parse('https://github.com/akashdh11'),
                    mode: LaunchMode.externalApplication,
                  ),
                ),
                _SocialButton(
                  svgUrl:
                      'https://raw.githubusercontent.com/simple-icons/simple-icons/11.10.0/icons/linkedin.svg',
                  color: const Color(0xFF2d65bc), // LinkedIn Official Blue
                  onTap: () => launchUrl(
                    Uri.parse('https://www.linkedin.com/in/akashdh11'),
                    mode: LaunchMode.externalApplication,
                  ),
                ),
                _SocialButton(
                  svgUrl:
                      'https://raw.githubusercontent.com/simple-icons/simple-icons/11.10.0/icons/discord.svg',
                  color: const Color(0xFF5865F2), // Discord Blurple
                  onTap: () => launchUrl(
                    Uri.parse('https://discord.gg/73XGA8Mxn9'),
                    mode: LaunchMode.externalApplication,
                  ),
                ),
                _SocialButton(
                  svgUrl:
                      'https://raw.githubusercontent.com/simple-icons/simple-icons/11.10.0/icons/telegram.svg',
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
                  return ListTile(
                    title: Text(qualityPreferenceLabel(q, l10n)),
                    subtitle: q == QualityPreference.any
                        ? Text(l10n.keepSourcesOriginalOrder)
                        : null,
                    leading: Radio<QualityPreference>(value: q),
                    onTap: () {
                      onChanged(q);
                      Navigator.pop<void>(ctx);
                    },
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
                  return ListTile(
                    title: Text(opt.label),
                    subtitle: Text(opt.subtitle),
                    leading: Radio<QualityFilterMode>(value: opt.mode),
                    onTap: () {
                      onChanged(opt.mode);
                      Navigator.pop<void>(ctx);
                    },
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

/// Shows a dialog to toggle the visibility of individual player control
/// buttons. Changes apply live via the player settings notifier.
void showPlayerControlsDialog(BuildContext context, WidgetRef ref) {
  final l10n = AppLocalizations.of(context)!;
  final notifier = ref.read(playerSettingsProvider.notifier);
  final settings =
      ref.read(playerSettingsProvider).asData?.value ?? const PlayerSettings();

  final metadata = [
    (icon: Icons.picture_in_picture_alt_rounded, label: l10n.showPip),
    (icon: Icons.aspect_ratio_rounded, label: l10n.showResize),
    (icon: Icons.screen_rotation_rounded, label: l10n.showRotate),
    (icon: Icons.speed_rounded, label: l10n.showPlaybackSpeed),
    (icon: Icons.playlist_play_rounded, label: l10n.showEpisodes),
  ];
  final setters = [
    notifier.setShowPip,
    notifier.setShowResize,
    notifier.setShowRotate,
    notifier.setShowPlaybackSpeed,
    notifier.setShowEpisodes,
  ];
  final values = [
    settings.showPip,
    settings.showResize,
    settings.showRotate,
    settings.showPlaybackSpeed,
    settings.showEpisodes,
  ];

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
                for (var i = 0; i < metadata.length; i++)
                  SwitchListTile(
                    secondary: Icon(metadata[i].icon),
                    title: Text(metadata[i].label),
                    value: values[i],
                    onChanged: (val) {
                      setters[i](val);
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
/// Shows a dialog to enter OpenSubtitles.com credentials.
void showOpenSubtitlesAuthDialog(
  BuildContext context,
  WidgetRef ref,
  PlayerSettings settings,
) {
  final l10n = AppLocalizations.of(context)!;
  final userController = TextEditingController(text: settings.osUsername);
  final passController = TextEditingController(text: settings.osPassword);

  showDialog<void>(
    context: context,
    builder: (ctx) {
      bool isVerifying = false;
      bool? verifyResult;
      var isObscure = true;

      return StatefulBuilder(
        builder: (context, setState) => FocusTraversalGroup(
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
                  CustomTextField(
                    controller: userController,
                    autofocus: true,
                    textInputAction: TextInputAction.next,
                    decoration: InputDecoration(
                      labelText: l10n.username,
                      prefixIcon: const Icon(Icons.person_outline, size: 20),
                    ),
                  ),
                  const SizedBox(height: 12),
                  CustomTextField(
                    controller: passController,
                    obscureText: isObscure,
                    decoration: InputDecoration(
                      labelText: l10n.password,
                      prefixIcon: const Icon(Icons.lock_outline, size: 20),
                      suffixIcon: ExcludeFocus(
                        child: IconButton(
                          icon: Icon(
                            isObscure ? Icons.visibility_off : Icons.visibility,
                            size: 20,
                          ),
                          onPressed: () =>
                              setState(() => isObscure = !isObscure),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextButton.icon(
                    onPressed: () => launchUrl(
                      Uri.parse(
                        'https://www.opensubtitles.com/en/users/sign_up',
                      ),
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
                          verifyResult!
                              ? Icons.check_circle_outline_rounded
                              : Icons.error_outline_rounded,
                          color: verifyResult! ? Colors.green : Colors.red,
                          size: 16,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          verifyResult!
                              ? l10n.connectedSuccessfully
                              : l10n.connectionFailed,
                          style: TextStyle(
                            color: verifyResult! ? Colors.green : Colors.red,
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
                      onPressed: isVerifying
                          ? null
                          : () async {
                              setState(() {
                                isVerifying = true;
                                verifyResult = null;
                              });
                              final ok = await ref
                                  .read(playerSettingsProvider.notifier)
                                  .verifyOpenSubtitles(
                                    userController.text.trim(),
                                    passController.text.trim(),
                                  );
                              if (ctx.mounted) {
                                setState(() {
                                  isVerifying = false;
                                  verifyResult = ok;
                                });
                              }
                            },
                      icon: isVerifying
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
                    onPressed: isVerifying
                        ? null
                        : () => Navigator.pop<void>(ctx),
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
                    onPressed: isVerifying
                        ? null
                        : () {
                            ref
                                .read(playerSettingsProvider.notifier)
                                .setOpenSubtitlesCredentials(
                                  userController.text.trim(),
                                  passController.text.trim(),
                                );
                            Navigator.pop<void>(ctx);
                          },
                    child: Text(l10n.save),
                  ),
                ],
              ),
            ],
          ),
        ),
      );
    },
  );
}

/// Shows a dialog to enter SubDL Account credentials.
void showSubDlAuthDialog(
  BuildContext context,
  WidgetRef ref,
  PlayerSettings settings,
) {
  final l10n = AppLocalizations.of(context)!;
  final theme = Theme.of(context);
  final apiKeyController = TextEditingController(text: settings.subdlApiKey);
  final emailController = TextEditingController(text: settings.subdlEmail);
  final passController = TextEditingController(text: settings.subdlPassword);

  showDialog<void>(
    context: context,
    builder: (ctx) {
      bool isFetching = false;
      String? fetchError;
      bool isObscure = true;
      bool isVerifyingKey = false;
      bool? verifyKeyResult;

      return StatefulBuilder(
        builder: (context, setState) => FocusTraversalGroup(
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
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 16),
                  CustomTextField(
                    controller: apiKeyController,
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
                            color: Theme.of(context)
                                .colorScheme
                                .onSurfaceVariant
                                .withValues(alpha: 0.6),
                          ),
                        ),
                      ),
                      const Expanded(child: Divider()),
                    ],
                  ),
                  const SizedBox(height: 16),
                  CustomTextField(
                    controller: emailController,
                    textInputAction: TextInputAction.next,
                    decoration: InputDecoration(
                      labelText: l10n.email,
                      prefixIcon: const Icon(Icons.email_outlined, size: 20),
                    ),
                  ),
                  const SizedBox(height: 12),
                  CustomTextField(
                    controller: passController,
                    obscureText: isObscure,
                    decoration: InputDecoration(
                      labelText: l10n.password,
                      prefixIcon: const Icon(Icons.lock_outline, size: 20),
                      suffixIcon: ExcludeFocus(
                        child: IconButton(
                          icon: Icon(
                            isObscure ? Icons.visibility_off : Icons.visibility,
                            size: 20,
                          ),
                          onPressed: () =>
                              setState(() => isObscure = !isObscure),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: (isFetching || isVerifyingKey)
                          ? null
                          : () async {
                              setState(() {
                                isFetching = true;
                                fetchError = null;
                                verifyKeyResult = null;
                              });
                              final result = await ref
                                  .read(playerSettingsProvider.notifier)
                                  .verifySubDl(
                                    emailController.text.trim(),
                                    passController.text.trim(),
                                  );
                              if (ctx.mounted) {
                                setState(() {
                                  isFetching = false;
                                  if (result.key != null) {
                                    apiKeyController.text = result.key!;
                                  } else {
                                    fetchError = result.error;
                                  }
                                });
                              }
                            },
                      icon: isFetching
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
                              color:
                                  fetchError != null || verifyKeyResult == false
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
                      onPressed: (isFetching || isVerifyingKey)
                          ? null
                          : () async {
                              setState(() {
                                isVerifyingKey = true;
                                verifyKeyResult = null;
                                fetchError = null;
                              });
                              final ok = await ref
                                  .read(playerSettingsProvider.notifier)
                                  .verifySubDlKey(apiKeyController.text.trim());
                              if (ctx.mounted) {
                                setState(() {
                                  isVerifyingKey = false;
                                  verifyKeyResult = ok;
                                });
                              }
                            },
                      icon: isVerifyingKey
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
                    onPressed: (isFetching || isVerifyingKey)
                        ? null
                        : () => Navigator.pop<void>(ctx),
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
                    onPressed: (isFetching || isVerifyingKey)
                        ? null
                        : () {
                            ref
                                .read(playerSettingsProvider.notifier)
                                .setSubDlAuth(
                                  apiKey: apiKeyController.text.trim(),
                                  email: emailController.text.trim(),
                                  pass: passController.text.trim(),
                                );
                            Navigator.pop<void>(ctx);
                          },
                    child: Text(l10n.save),
                  ),
                ],
              ),
            ],
          ),
        ),
      );
    },
  );
}

/// Shows a dialog to enter SubSource API Key.
void showSubSourceAuthDialog(
  BuildContext context,
  WidgetRef ref,
  PlayerSettings settings,
) {
  final l10n = AppLocalizations.of(context)!;
  final keyController = TextEditingController(text: settings.subsourceApiKey);

  showDialog<void>(
    context: context,
    builder: (ctx) {
      bool isVerifying = false;
      bool? verifyResult;

      return StatefulBuilder(
        builder: (context, setState) => FocusTraversalGroup(
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
                    controller: keyController,
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
                          verifyResult!
                              ? Icons.check_circle_outline_rounded
                              : Icons.error_outline_rounded,
                          color: verifyResult! ? Colors.green : Colors.red,
                          size: 16,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          verifyResult! ? l10n.keyVerified : l10n.invalidApiKey,
                          style: TextStyle(
                            color: verifyResult! ? Colors.green : Colors.red,
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
                      onPressed: isVerifying
                          ? null
                          : () async {
                              setState(() {
                                isVerifying = true;
                                verifyResult = null;
                              });
                              final ok = await ref
                                  .read(playerSettingsProvider.notifier)
                                  .verifySubSource(keyController.text.trim());
                              if (ctx.mounted) {
                                setState(() {
                                  isVerifying = false;
                                  verifyResult = ok;
                                });
                              }
                            },
                      icon: isVerifying
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
                    onPressed: isVerifying
                        ? null
                        : () => Navigator.pop<void>(ctx),
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
                    onPressed: isVerifying
                        ? null
                        : () {
                            ref
                                .read(playerSettingsProvider.notifier)
                                .setSubSourceApiKey(keyController.text.trim());
                            Navigator.pop<void>(ctx);
                          },
                    child: Text(l10n.save),
                  ),
                ],
              ),
            ],
          ),
        ),
      );
    },
  );
}
