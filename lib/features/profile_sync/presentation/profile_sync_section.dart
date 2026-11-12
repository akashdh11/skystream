import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:skystream/l10n/generated/app_localizations.dart';

import '../../../core/services/notification_service.dart';
import '../../settings/presentation/widgets/settings_widgets.dart';
import '../data/profile_sync_service.dart';

class ProfileSyncSection extends ConsumerWidget {
  const ProfileSyncSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final sync = ref.watch(profileSyncProvider);
    final host = Uri.tryParse(sync.serverUrl)?.host;
    final hostLabel = host == null || host.isEmpty ? sync.serverUrl : host;

    return SettingsGroup(
      title: l10n.profileSyncTitle,
      children: [
        SettingsTile(
          icon: Icons.cloud_sync_rounded,
          title: sync.isLoggedIn
              ? (sync.username ?? l10n.profileSyncTitle)
              : l10n.profileSyncSignIn,
          subtitle: sync.isLoggedIn
              ? l10n.profileSyncConnected(sync.username ?? '', hostLabel)
              : sync.lastError ?? l10n.profileSyncSignedOut,
          isLast: !sync.isLoggedIn,
          onTap: () => _showLogin(context, ref, sync),
        ),
        if (sync.isLoggedIn) ...[
          SettingsTile(
            icon: Icons.sync_rounded,
            title: l10n.profileSyncSyncNow,
            subtitle: sync.isSyncing
                ? l10n.profileSyncSyncing
                : sync.lastError ??
                      (sync.lastSyncedAt == null
                          ? null
                          : l10n.profileSyncLastSynced(
                              _formatSyncedAt(context, sync.lastSyncedAt!),
                            )),
            onTap: sync.isSyncing ? null : () => _syncNow(context, ref),
          ),
          SettingsTile(
            icon: Icons.autorenew_rounded,
            title: l10n.profileSyncAuto,
            subtitle: l10n.profileSyncAutoSubtitle,
            trailing: Switch(
              value: sync.autoSync,
              onChanged: (enabled) =>
                  ref.read(profileSyncProvider.notifier).setAutoSync(enabled),
            ),
            onTap: () => ref
                .read(profileSyncProvider.notifier)
                .setAutoSync(!sync.autoSync),
          ),
          SettingsTile(
            icon: Icons.link_off_rounded,
            title: l10n.profileSyncDisconnect,
            isLast: true,
            onTap: () => _disconnect(context, ref),
          ),
        ],
      ],
    );
  }

  Future<void> _syncNow(BuildContext context, WidgetRef ref) async {
    final l10n = AppLocalizations.of(context)!;
    final ok = await ref
        .read(profileSyncProvider.notifier)
        .syncNow(installMissingExtensions: true);
    if (!context.mounted) return;
    final notifications = ref.read(notificationServiceProvider);
    if (ok) {
      notifications.showSuccess(l10n.profileSyncSynced);
      return;
    }
    notifications.showError(
      ref.read(profileSyncProvider).lastError ?? l10n.profileSyncFailed,
    );
  }

  Future<void> _disconnect(BuildContext context, WidgetRef ref) async {
    final l10n = AppLocalizations.of(context)!;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.profileSyncDisconnect),
        content: Text(l10n.profileSyncDisconnectBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(l10n.cancel),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(l10n.profileSyncDisconnect),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await ref.read(profileSyncProvider.notifier).logout();
  }

  Future<void> _showLogin(
    BuildContext context,
    WidgetRef ref,
    ProfileSyncState sync,
  ) async {
    final l10n = AppLocalizations.of(context)!;
    final serverController = TextEditingController(text: sync.serverUrl);
    final usernameController = TextEditingController(text: sync.username ?? '');
    final passwordController = TextEditingController();
    final formKey = GlobalKey<FormState>();
    try {
      final submitted = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(l10n.profileSyncTitle),
          content: Form(
            key: formKey,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextFormField(
                    controller: serverController,
                    decoration: InputDecoration(
                      labelText: l10n.profileSyncServerUrl,
                    ),
                    keyboardType: TextInputType.url,
                    autofillHints: const [AutofillHints.url],
                    validator: (value) =>
                        value == null || value.trim().isEmpty ? '' : null,
                  ),
                  TextFormField(
                    controller: usernameController,
                    decoration: InputDecoration(labelText: l10n.username),
                    autofillHints: const [AutofillHints.username],
                    validator: (value) =>
                        value == null || value.trim().length < 2 ? '' : null,
                  ),
                  TextFormField(
                    controller: passwordController,
                    decoration: InputDecoration(labelText: l10n.password),
                    obscureText: true,
                    autofillHints: const [AutofillHints.password],
                    validator: (value) =>
                        value == null || value.length < 6 ? '' : null,
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text(l10n.cancel),
            ),
            TextButton(
              onPressed: () {
                if (formKey.currentState?.validate() != true) return;
                Navigator.pop(context, true);
              },
              child: Text(l10n.profileSyncSignIn),
            ),
          ],
        ),
      );
      if (submitted != true || !context.mounted) return;
      final ok = await ref
          .read(profileSyncProvider.notifier)
          .login(
            serverUrl: serverController.text,
            username: usernameController.text,
            password: passwordController.text,
          );
      if (!context.mounted) return;
      final notifications = ref.read(notificationServiceProvider);
      if (ok) {
        notifications.showSuccess(l10n.profileSyncSynced);
      } else {
        notifications.showError(
          ref.read(profileSyncProvider).lastError ?? l10n.profileSyncFailed,
        );
      }
    } finally {
      serverController.dispose();
      usernameController.dispose();
      passwordController.dispose();
    }
  }

  String _formatSyncedAt(BuildContext context, int millis) {
    final localizations = MaterialLocalizations.of(context);
    final time = DateTime.fromMillisecondsSinceEpoch(millis);
    return '${localizations.formatShortDate(time)} ${localizations.formatTimeOfDay(TimeOfDay.fromDateTime(time))}';
  }
}
