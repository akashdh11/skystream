import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:skystream/l10n/generated/app_localizations.dart';

import '../../../core/services/notification_service.dart';
import '../../../shared/widgets/custom_widgets.dart';
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
    final submitted = await showDialog<_ProfileSyncLogin>(
      context: context,
      builder: (context) => _ProfileSyncLoginDialog(
        serverUrl: sync.serverUrl,
        username: sync.username ?? '',
      ),
    );
    if (submitted == null || !context.mounted) return;
    final ok = await ref
        .read(profileSyncProvider.notifier)
        .login(
          serverUrl: submitted.serverUrl,
          username: submitted.username,
          password: submitted.password,
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
  }

  String _formatSyncedAt(BuildContext context, int millis) {
    final localizations = MaterialLocalizations.of(context);
    final time = DateTime.fromMillisecondsSinceEpoch(millis);
    return '${localizations.formatShortDate(time)} ${localizations.formatTimeOfDay(TimeOfDay.fromDateTime(time))}';
  }
}

class _ProfileSyncLogin {
  const _ProfileSyncLogin({
    required this.serverUrl,
    required this.username,
    required this.password,
  });

  final String serverUrl;
  final String username;
  final String password;
}

/// Owns the field controllers for the whole route, including the exit
/// animation. Disposing them when [showDialog] returns uses them after dispose,
/// because the route is still on screen while it closes.
class _ProfileSyncLoginDialog extends StatefulWidget {
  const _ProfileSyncLoginDialog({
    required this.serverUrl,
    required this.username,
  });

  final String serverUrl;
  final String username;

  @override
  State<_ProfileSyncLoginDialog> createState() =>
      _ProfileSyncLoginDialogState();
}

class _ProfileSyncLoginDialogState extends State<_ProfileSyncLoginDialog> {
  late final TextEditingController _server = TextEditingController(
    text: widget.serverUrl,
  );
  late final TextEditingController _username = TextEditingController(
    text: widget.username,
  );
  final TextEditingController _password = TextEditingController();

  @override
  void dispose() {
    _server.dispose();
    _username.dispose();
    _password.dispose();
    super.dispose();
  }

  void _submit() {
    if (_server.text.trim().isEmpty) return;
    if (_username.text.trim().length < 2) return;
    if (_password.text.length < 6) return;
    Navigator.pop(
      context,
      _ProfileSyncLogin(
        serverUrl: _server.text,
        username: _username.text,
        password: _password.text,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return FocusTraversalGroup(
      policy: WidgetOrderTraversalPolicy(),
      child: AlertDialog(
        title: Text(l10n.profileSyncTitle),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CustomTextField(
                controller: _server,
                autofocus: true,
                textInputAction: TextInputAction.next,
                keyboardType: TextInputType.url,
                decoration: InputDecoration(
                  labelText: l10n.profileSyncServerUrl,
                ),
              ),
              const SizedBox(height: 12),
              CustomTextField(
                controller: _username,
                textInputAction: TextInputAction.next,
                decoration: InputDecoration(labelText: l10n.username),
              ),
              const SizedBox(height: 12),
              CustomTextField(
                controller: _password,
                obscureText: true,
                textInputAction: TextInputAction.done,
                onSubmitted: (_) => _submit(),
                decoration: InputDecoration(labelText: l10n.password),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(l10n.cancel),
          ),
          CustomButton(
            isPrimary: true,
            onPressed: _submit,
            child: Text(l10n.profileSyncSignIn),
          ),
        ],
      ),
    );
  }
}
