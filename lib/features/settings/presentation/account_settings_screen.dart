import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/utils/layout_constants.dart';
import 'package:skystream/l10n/generated/app_localizations.dart';

import 'widgets/settings_widgets.dart';
import 'widgets/settings_dialogs.dart';
import 'widgets/tracking_auth_dialog.dart';
import 'widgets/webview_auth_dialog.dart';
import 'player_settings_provider.dart';

import '../../../core/config/sync_config.dart';
import '../../tracking/presentation/tracking_auth_provider.dart';
import '../../tracking/data/simkl_service.dart';
import '../../tracking/data/trakt_service.dart';
import '../../tracking/data/mal_service.dart';
import '../../tracking/data/anilist_service.dart';
import '../../../core/storage/settings_repository.dart';
import '../../../core/services/notification_service.dart';

class AccountSettingsScreen extends ConsumerStatefulWidget {
  final bool isEmbedded;

  const AccountSettingsScreen({super.key, this.isEmbedded = false});

  @override
  ConsumerState<AccountSettingsScreen> createState() =>
      _AccountSettingsScreenState();
}

class _AccountSettingsScreenState extends ConsumerState<AccountSettingsScreen> {
  final FocusNode _simklFocusNode = FocusNode();
  final FocusNode _traktFocusNode = FocusNode();
  final FocusNode _malFocusNode = FocusNode();
  final FocusNode _anilistFocusNode = FocusNode();

  @override
  void dispose() {
    _simklFocusNode.dispose();
    _traktFocusNode.dispose();
    _malFocusNode.dispose();
    _anilistFocusNode.dispose();
    super.dispose();
  }

  Future<bool> _confirmDisconnect(
    BuildContext context,
    String providerName,
  ) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Disconnect $providerName'),
        content: Text(
          'Are you sure you want to disconnect your $providerName account?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text(
              'Disconnect',
              style: TextStyle(color: Colors.red),
            ),
          ),
        ],
      ),
    );
    return result == true;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final playerSettings =
        ref.watch(playerSettingsProvider).asData?.value ??
        const PlayerSettings();
    final settingsRepo = ref.watch(settingsRepositoryProvider);

    final content = Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 800),
        child: ListView(
          padding: const EdgeInsets.only(bottom: LayoutConstants.spacingLg),
          children: [
            const SizedBox(height: LayoutConstants.spacingXs),
            SettingsGroup(
              title: l10n.accounts,
              children: [
                SettingsTile(
                  icon: Icons.subtitles_rounded,
                  title: l10n.openSubtitles,
                  subtitle: playerSettings.osUsername.isNotEmpty
                      ? l10n.loggedInAs(playerSettings.osUsername)
                      : l10n.notLoggedIn,
                  onTap: () =>
                      showOpenSubtitlesAuthDialog(context, ref, playerSettings),
                ),
                SettingsTile(
                  icon: Icons.vpn_key_rounded,
                  title: l10n.subDl,
                  subtitle: playerSettings.subdlApiKey.isNotEmpty
                      ? l10n.apiKeyConfigured
                      : l10n.keyNotSet,
                  onTap: () =>
                      showSubDlAuthDialog(context, ref, playerSettings),
                ),
                SettingsTile(
                  icon: Icons.vpn_key_rounded,
                  title: l10n.subSource,
                  subtitle: playerSettings.subsourceApiKey.isNotEmpty
                      ? l10n.apiKeyConfigured
                      : l10n.keyNotSet,
                  onTap: () =>
                      showSubSourceAuthDialog(context, ref, playerSettings),
                ),
                Consumer(
                  builder: (context, ref, _) {
                    final trackingAuthAsync = ref.watch(trackingAuthProvider);
                    return Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        SettingsTile(
                          focusNode: _simklFocusNode,
                          icon: Icons.sync_rounded,
                          title: 'Simkl',
                          subtitle: trackingAuthAsync.when(
                            data: (state) => state['simkl'] == true
                                ? 'Connected'
                                : l10n.notLoggedIn,
                            loading: () => l10n.loading,
                            error: (_, _) => l10n.unknown,
                          ),
                          onTap: () async {
                            final state = trackingAuthAsync.value ?? {};
                            if (state['simkl'] == true) {
                              final confirm = await _confirmDisconnect(
                                context,
                                'Simkl',
                              );
                              if (confirm) {
                                await ref.read(simklServiceProvider).logout();
                                ref.invalidate(trackingAuthProvider);
                                if (context.mounted) {
                                  FocusScope.of(context).requestFocus();
                                }
                              }
                            } else {
                              bool isCancelled = false;
                              bool isDialogShowing = false;
                              BuildContext? dialogContext;
                              final success = await ref
                                  .read(simklServiceProvider)
                                  .login(
                                    isCancelled: () => isCancelled,
                                    onDeviceCodeGenerated: (url, code) async {
                                      if (context.mounted) {
                                        isDialogShowing = true;
                                        unawaited(
                                          showDialog<void>(
                                            context: context,
                                            barrierDismissible: true,
                                            builder: (ctx) {
                                              dialogContext = ctx;
                                              return TrackingAuthDialog(
                                                providerName: 'Simkl',
                                                verificationUrl: url,
                                                userCode: code,
                                              );
                                            },
                                          ).then((_) {
                                            isCancelled = true;
                                            isDialogShowing = false;
                                            if (context.mounted) {
                                              FocusScope.of(
                                                context,
                                              ).requestFocus();
                                            }
                                          }),
                                        );
                                      }
                                    },
                                  );
                              if (success && context.mounted) {
                                ref
                                    .read(notificationServiceProvider)
                                    .showSuccess(
                                      'Successfully connected to Simkl!',
                                      title: 'Simkl',
                                      icon: Icons.sync_rounded,
                                    );
                              }
                              if (isDialogShowing &&
                                  dialogContext != null &&
                                  dialogContext!.mounted) {
                                Navigator.of(dialogContext!).pop();
                              }
                            }
                            ref.invalidate(trackingAuthProvider);
                          },
                        ),
                        SettingsTile(
                          focusNode: _traktFocusNode,
                          icon: Icons.sync_rounded,
                          title: 'Trakt',
                          subtitle: trackingAuthAsync.when(
                            data: (state) => state['trakt'] == true
                                ? 'Connected'
                                : l10n.notLoggedIn,
                            loading: () => l10n.loading,
                            error: (_, _) => l10n.unknown,
                          ),
                          onTap: () async {
                            final state = trackingAuthAsync.value ?? {};
                            if (state['trakt'] == true) {
                              final confirm = await _confirmDisconnect(
                                context,
                                'Trakt',
                              );
                              if (confirm) {
                                await ref.read(traktServiceProvider).logout();
                                ref.invalidate(trackingAuthProvider);
                                if (context.mounted) {
                                  _traktFocusNode.requestFocus();
                                }
                              }
                            } else {
                              bool isCancelled = false;
                              bool isDialogShowing = false;
                              BuildContext? dialogContext;
                              final success = await ref
                                  .read(traktServiceProvider)
                                  .login(
                                    isCancelled: () => isCancelled,
                                    onDeviceCodeGenerated: (url, code) async {
                                      if (context.mounted) {
                                        isDialogShowing = true;
                                        unawaited(
                                          showDialog<void>(
                                            context: context,
                                            barrierDismissible: true,
                                            builder: (ctx) {
                                              dialogContext = ctx;
                                              return TrackingAuthDialog(
                                                providerName: 'Trakt',
                                                verificationUrl: url,
                                                userCode: code,
                                              );
                                            },
                                          ).then((_) {
                                            isCancelled = true;
                                            isDialogShowing = false;
                                            if (context.mounted) {
                                              _traktFocusNode.requestFocus();
                                            }
                                          }),
                                        );
                                      }
                                    },
                                  );
                              if (success && context.mounted) {
                                ref
                                    .read(notificationServiceProvider)
                                    .showSuccess(
                                      'Successfully connected to Trakt!',
                                      title: 'Trakt',
                                      icon: Icons.sync_rounded,
                                    );
                              }
                              if (isDialogShowing &&
                                  dialogContext != null &&
                                  dialogContext!.mounted) {
                                Navigator.of(dialogContext!).pop();
                              }
                            }
                            ref.invalidate(trackingAuthProvider);
                          },
                        ),
                        SettingsTile(
                          focusNode: _malFocusNode,
                          icon: Icons.sync_rounded,
                          title: 'MyAnimeList',
                          subtitle: trackingAuthAsync.when(
                            data: (state) => state['mal'] == true
                                ? 'Connected'
                                : l10n.notLoggedIn,
                            loading: () => l10n.loading,
                            error: (_, _) => l10n.unknown,
                          ),
                          onTap: () async {
                            final state = trackingAuthAsync.value ?? {};
                            if (state['mal'] == true) {
                              final confirm = await _confirmDisconnect(
                                context,
                                'MyAnimeList',
                              );
                              if (confirm) {
                                await ref.read(malServiceProvider).logout();
                                ref.invalidate(trackingAuthProvider);
                                if (context.mounted) {
                                  _malFocusNode.requestFocus();
                                }
                              }
                            } else {
                              final malService = ref.read(malServiceProvider);
                              // Generate PKCE verifier before opening webview
                              final codeVerifier = malService
                                  .generateCodeVerifier();

                              final authUrl =
                                  'https://myanimelist.net/v1/oauth2/authorize'
                                  '?response_type=code'
                                  '&client_id=${SyncConfig.malClientId}'
                                  '&code_challenge=$codeVerifier'
                                  '&code_challenge_method=plain'
                                  '&redirect_uri=${Uri.encodeComponent('http://localhost')}';

                              if (context.mounted) {
                                final redirectUrl = await showDialog<String>(
                                  context: context,
                                  builder: (context) => WebViewAuthDialog(
                                    providerName: 'MyAnimeList',
                                    initialUrl: authUrl,
                                    redirectUrlPrefix: 'http://localhost',
                                  ),
                                );

                                if (redirectUrl != null && context.mounted) {
                                  final success = await malService
                                      .exchangeCodeForToken(
                                        redirectUrl,
                                        codeVerifier,
                                      );
                                  if (success && context.mounted) {
                                    ref
                                        .read(notificationServiceProvider)
                                        .showSuccess(
                                          'Successfully connected to MyAnimeList!',
                                          title: 'MyAnimeList',
                                          icon: Icons.sync_rounded,
                                        );
                                  } else if (context.mounted) {
                                    ref
                                        .read(notificationServiceProvider)
                                        .showError(
                                          'Failed to connect to MyAnimeList',
                                          title: 'MyAnimeList',
                                          icon: Icons.sync_problem_rounded,
                                        );
                                  }
                                }
                                if (context.mounted) {
                                  _malFocusNode.requestFocus();
                                }
                              }
                            }
                            ref.invalidate(trackingAuthProvider);
                          },
                        ),
                        SettingsTile(
                          focusNode: _anilistFocusNode,
                          icon: Icons.sync_rounded,
                          title: 'AniList',
                          subtitle: trackingAuthAsync.when(
                            data: (state) => state['anilist'] == true
                                ? 'Connected'
                                : l10n.notLoggedIn,
                            loading: () => l10n.loading,
                            error: (_, _) => l10n.unknown,
                          ),
                          isLast: true,
                          onTap: () async {
                            final state = trackingAuthAsync.value ?? {};
                            if (state['anilist'] == true) {
                              final confirm = await _confirmDisconnect(
                                context,
                                'AniList',
                              );
                              if (confirm) {
                                await ref.read(aniListServiceProvider).logout();
                                ref.invalidate(trackingAuthProvider);
                                if (context.mounted) {
                                  _anilistFocusNode.requestFocus();
                                }
                              }
                            } else {
                              final anilistService = ref.read(
                                aniListServiceProvider,
                              );

                              const authUrl =
                                  'https://anilist.co/api/v2/oauth/authorize'
                                  '?client_id=${SyncConfig.anilistClientId}'
                                  '&response_type=token';

                              if (context.mounted) {
                                final redirectUrl = await showDialog<String>(
                                  context: context,
                                  builder: (context) => const WebViewAuthDialog(
                                    providerName: 'AniList',
                                    initialUrl: authUrl,
                                    redirectUrlPrefix: 'http://localhost',
                                  ),
                                );

                                if (redirectUrl != null && context.mounted) {
                                  final success = await anilistService
                                      .saveTokenFromRedirect(redirectUrl);
                                  if (success && context.mounted) {
                                    ref
                                        .read(notificationServiceProvider)
                                        .showSuccess(
                                          'Successfully connected to AniList!',
                                          title: 'AniList',
                                          icon: Icons.sync_rounded,
                                        );
                                  } else if (context.mounted) {
                                    ref
                                        .read(notificationServiceProvider)
                                        .showError(
                                          'Failed to connect to AniList',
                                          title: 'AniList',
                                          icon: Icons.sync_problem_rounded,
                                        );
                                  }
                                }
                                if (context.mounted) {
                                  _anilistFocusNode.requestFocus();
                                }
                              }
                            }
                            ref.invalidate(trackingAuthProvider);
                          },
                        ),
                      ],
                    );
                  },
                ),
              ],
            ),
            const SizedBox(height: LayoutConstants.spacingLg),
            SettingsGroup(
              title: 'Integrations',
              children: [
                SettingsTile(
                  icon: Icons.fast_forward_rounded,
                  title: 'AnimeSkip',
                  isBeta: true,
                  subtitle:
                      'Automatically fetch skip segments for Anime (requires AniList authentication)',
                  trailing: Switch(
                    value: settingsRepo.isAnimeSkipIntegrationEnabled(),
                    onChanged: (val) {
                      settingsRepo.setAnimeSkipIntegrationEnabled(val);
                      // Trigger a rebuild
                      ref.invalidate(settingsRepositoryProvider);
                    },
                  ),
                  onTap: () {
                    final current = settingsRepo
                        .isAnimeSkipIntegrationEnabled();
                    settingsRepo.setAnimeSkipIntegrationEnabled(!current);
                    ref.invalidate(settingsRepositoryProvider);
                  },
                ),
                SettingsTile(
                  icon: Icons.fast_forward_rounded,
                  title: 'IntroDB',
                  isBeta: true,
                  subtitle: 'Automatically fetch skip segments for TV Shows',
                  isLast: true,
                  trailing: Switch(
                    value: settingsRepo.isIntroDbIntegrationEnabled(),
                    onChanged: (val) {
                      settingsRepo.setIntroDbIntegrationEnabled(val);
                      ref.invalidate(settingsRepositoryProvider);
                    },
                  ),
                  onTap: () {
                    final current = settingsRepo.isIntroDbIntegrationEnabled();
                    settingsRepo.setIntroDbIntegrationEnabled(!current);
                    ref.invalidate(settingsRepositoryProvider);
                  },
                ),
              ],
            ),
          ],
        ),
      ),
    );

    if (widget.isEmbedded) {
      return content;
    }

    return Scaffold(
      appBar: AppBar(title: Text(l10n.accounts)),
      body: content,
    );
  }
}
