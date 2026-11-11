import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/services/notification_service.dart';
import '../../settings/presentation/widgets/settings_widgets.dart';
import '../data/app_backup.dart';
import '../data/backup_notifier.dart';

/// The "Backup" group on the Accounts settings screen: export the app's
/// watch history, library and plugins to a file, and import one back.
///
/// No account and no server: the file is the backup, and moving it between
/// devices is moving the backup.
class BackupSection extends ConsumerWidget {
  const BackupSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return SettingsGroup(
      title: 'Backup',
      children: [
        SettingsTile(
          icon: Icons.file_download_rounded,
          title: 'Export backup',
          subtitle: 'Save watch history, plugins & library to a file',
          onTap: () => _exportBackup(context, ref),
        ),
        SettingsTile(
          icon: Icons.file_upload_rounded,
          title: 'Import backup',
          subtitle: 'Restore from a backup file',
          isLast: true,
          onTap: () => _importBackup(context, ref),
        ),
      ],
    );
  }

  Future<void> _exportBackup(BuildContext context, WidgetRef ref) async {
    try {
      final result = await ref
          .read(backupProvider.notifier)
          .exportBackupFile();
      if (!context.mounted) return;
      if (result == null) return; // User cancelled the save dialog.
      ref
          .read(notificationServiceProvider)
          .showSuccess(
            result.openedShareSheet
                ? 'Backup ready — save it from the share sheet to keep it.'
                : 'Backup exported.',
            title: 'Backup',
            icon: Icons.file_download_rounded,
          );
    } catch (e) {
      if (!context.mounted) return;
      ref
          .read(notificationServiceProvider)
          .showError(
            'Could not export the backup: $e',
            title: 'Backup',
            icon: Icons.error_outline_rounded,
          );
    }
  }

  Future<void> _importBackup(BuildContext context, WidgetRef ref) async {
    final notifier = ref.read(backupProvider.notifier);
    // The toasts ride the global overlay and need no BuildContext, so they
    // are shown even when this screen is gone by the time the import
    // finishes. The old code returned early on `!context.mounted` after the
    // restore, so a user who left Settings during the (slow, network)
    // restore never saw the confirmation at all — even though the import
    // itself had worked.
    final notifications = ref.read(notificationServiceProvider);
    if (notifier.importInProgress) {
      notifications.showInfo(
        'A backup import is already running — please wait.',
        title: 'Backup',
        icon: Icons.hourglass_top_rounded,
      );
      return;
    }

    // 1) Pick the file. Null is the user cancelling the picker.
    AppBackup? backup;
    try {
      backup = await notifier.pickBackupFile();
    } on BackupException catch (e) {
      notifications.showError(
        e.message,
        title: 'Backup',
        icon: Icons.error_outline_rounded,
      );
      return;
    } on PlatformException catch (e) {
      // file_picker's `multiple_request`: a pick was started while another
      // pick was still open. Never show the raw exception — the user just
      // needs to tap Import again (the guard is already reset by then).
      notifications.showError(
        e.code == 'multiple_request'
            ? 'The file picker was already open — please tap Import again.'
            : 'Could not import the backup: ${e.message ?? e.code}',
        title: 'Backup',
        icon: Icons.error_outline_rounded,
      );
      return;
    } catch (e) {
      notifications.showError(
        'Could not import the backup: $e',
        title: 'Backup',
        icon: Icons.error_outline_rounded,
      );
      return;
    }
    if (backup == null) return;

    // 2) Restore it. Re-adding repositories and re-installing plugins is
    // network work and takes a while on mobile data, so while it runs the
    // screen shows a progress dialog — the old code showed nothing at all
    // for the whole restore, which is why users tapped Import again or left
    // the screen and then saw no confirmation.
    if (!context.mounted) {
      // Left Settings while the picker was open: restore anyway, and
      // confirm through the global toast (it needs no context).
      await _restoreAndConfirm(notifier, notifications, backup);
      return;
    }

    var dialogShowing = false;
    BuildContext? dialogContext;
    unawaited(
      showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (ctx) {
          dialogContext = ctx;
          dialogShowing = true;
          return const _ImportingBackupDialog();
        },
      ).then((_) => dialogShowing = false),
    );
    AppRestoreReport? report;
    Object? failure;
    try {
      report = await notifier.restoreBackup(backup);
    } catch (e) {
      failure = e;
    } finally {
      if (dialogShowing &&
          dialogContext != null &&
          dialogContext!.mounted) {
        Navigator.of(dialogContext!).pop();
      }
    }
    if (failure != null) {
      notifications.showError(
        'Could not import the backup: $failure',
        title: 'Backup',
        icon: Icons.error_outline_rounded,
      );
      return;
    }
    _confirmRestore(notifications, report!);
  }
}

/// Restores [backup] and confirms the result through the global toasts,
/// which need no BuildContext — for an import whose screen is already gone.
Future<void> _restoreAndConfirm(
  BackupNotifier notifier,
  NotificationService notifications,
  AppBackup backup,
) async {
  try {
    final report = await notifier.restoreBackup(backup);
    _confirmRestore(notifications, report);
  } catch (e) {
    notifications.showError(
      'Could not import the backup: $e',
      title: 'Backup',
      icon: Icons.error_outline_rounded,
    );
  }
}

/// The confirmation for a finished restore: the success toast, plus the
/// first thing that could not be restored, when there is one. The success
/// toast lasts five seconds, so it can actually be read.
void _confirmRestore(
  NotificationService notifications,
  AppRestoreReport report,
) {
  notifications.showSuccess(
    report.summary,
    title: 'Backup',
    icon: Icons.restore_rounded,
    duration: const Duration(seconds: 5),
  );
  if (report.errors.isNotEmpty) {
    notifications.showError(
      report.errors.first,
      title: 'Some items were not restored',
      icon: Icons.warning_amber_rounded,
    );
  }
}

/// Shown while a backup restore runs: re-adding repositories and
/// re-installing plugins is network work and takes a while, and the old code
/// showed nothing at all for the whole restore.
class _ImportingBackupDialog extends StatelessWidget {
  const _ImportingBackupDialog();

  @override
  Widget build(BuildContext context) {
    return const AlertDialog(
      title: Text('Importing backup…'),
      content: Row(
        children: [
          CircularProgressIndicator(),
          SizedBox(width: 16),
          Expanded(
            child: Text(
              'Restoring your watch history, library and plugins. '
              'This can take a moment.',
            ),
          ),
        ],
      ),
    );
  }
}
