import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:open_file/open_file.dart';
import 'package:path_provider/path_provider.dart';

import '../../../core/cloudstream/cloudstream_models.dart';
import '../../../core/cloudstream/cloudstream_repository.dart';
import '../../../core/extensions/models/extension_plugin.dart';
import '../../../core/logger/app_logger.dart';
import '../../../core/storage/library_repository.dart';
import '../../../core/storage/storage_service.dart';
import '../../extensions/providers/extensions_controller.dart';
import '../../library/presentation/history_provider.dart';
import '../../library/presentation/library_provider.dart';
import 'app_backup.dart';

/// A backup failure, in the user's words — a file that is not a backup, or
/// a picker that was already open.
class BackupException implements Exception {
  const BackupException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// The state of the backup feature. The backup itself lives in the history
/// box, the library box and the two plugin systems' own stores; this
/// feature only reads them and restores into them through their public APIs.
/// There is nothing to display while idle, so the state is empty — the work
/// is the notifier's methods, and the progress is the UI's own dialog.
class BackupState {
  const BackupState();
}

final backupProvider = NotifierProvider<BackupNotifier, BackupState>(
  BackupNotifier.new,
);

/// Export/Import backup: everything the app knows — watch history, library
/// bookmarks, SkyStream and CloudStream repositories and plugins — to a
/// JSON file the user can keep, and back from it.
///
/// Plain Riverpod ([NotifierProvider]) — no codegen, so no `build_runner`.
class BackupNotifier extends Notifier<BackupState> {
  /// Re-entrancy guards for the file pickers. A double-tap on Import (or
  /// Export) fired `pickFile` twice, and file_picker throws
  /// `PlatformException(multiple_request)` for a second pick while one is
  /// already open — the import then died before the backup was even read.
  /// While one is in progress, further taps are ignored (they return null,
  /// which the UI already treats as "user cancelled").
  bool _importInProgress = false;
  bool _exportInProgress = false;

  @override
  BackupState build() => const BackupState();

  // --- backup: collect ---------------------------------------------------------

  /// Reads everything the backup covers. Plugin collection never fails the
  /// backup: a repository that will not load is skipped and the rest still
  /// goes in (the restore step reports what is missing).
  Future<AppBackup> collectBackup() async {
    final storage = ref.read(storageServiceProvider);
    final history = storage.getAllHistoryEntries();
    final library = ref
        .read(libraryRepositoryProvider)
        .getLibraryItems()
        .map((item) => item.toJson())
        .toList();

    var skystreamRepos = <String>[];
    var skystreamPlugins = <Map<String, String>>[];
    try {
      final extensions = ref.read(extensionsControllerProvider.notifier);
      await extensions.ensureInitialized();
      final extensionsState = ref.read(extensionsControllerProvider);
      skystreamRepos = [
        for (final repo in extensionsState.repositories) repo.url,
      ];
      skystreamPlugins = [
        for (final plugin in extensionsState.installedPlugins)
          {
            'packageName': plugin.packageName,
            'repositoryUrl': plugin.repositoryUrl ?? '',
          },
      ];
    } catch (e) {
      talker.warning('[Backup] SkyStream plugins not backed up: $e');
    }

    var cloudstreamRepos = <String>[];
    var cloudstreamPlugins = <Map<String, String>>[];
    try {
      final cloudstream = ref.read(cloudStreamRepositoryProvider.notifier);
      await cloudstream.load();
      final cloudstreamState = ref.read(cloudStreamRepositoryProvider);
      cloudstreamRepos = [
        for (final repo in cloudstreamState.repositories) repo.url,
      ];
      cloudstreamPlugins = [
        for (final plugin in cloudstreamState.installed)
          {
            'internalName': plugin.info.internalName,
            'name': plugin.info.name,
            'url': plugin.info.url,
            'repositoryUrl': plugin.info.repositoryUrl,
          },
      ];
    } catch (e) {
      talker.warning('[Backup] CloudStream plugins not backed up: $e');
    }

    return AppBackup(
      exportedAt: DateTime.now().millisecondsSinceEpoch,
      history: history,
      library: library,
      skystreamRepos: skystreamRepos,
      skystreamPlugins: skystreamPlugins,
      cloudstreamRepos: cloudstreamRepos,
      cloudstreamPlugins: cloudstreamPlugins,
    );
  }

  // --- backup: restore ---------------------------------------------------------

  /// Merges [backup] into this device: newest timestamp wins per history
  /// entry, bookmarks are added when missing, repositories are re-added and
  /// their missing plugins re-installed. Never throws for one bad entry;
  /// failures are collected in the report.
  Future<AppRestoreReport> restoreBackup(AppBackup backup) async {
    final errors = <String>[];
    var historyRestored = 0;
    var historySkipped = 0;
    var libraryRestored = 0;
    var skystreamReposRestored = 0;
    var skystreamPluginsRestored = 0;
    var cloudstreamReposRestored = 0;
    var cloudstreamPluginsRestored = 0;

    // History: newest timestamp wins, per box key.
    final storage = ref.read(storageServiceProvider);
    final local = <String, int>{
      for (final raw in storage.getAllHistoryEntries())
        if (raw['key'] is String)
          raw['key'] as String:
              ((raw['entry'] as Map?)?['timestamp'] as int?) ?? 0,
    };
    final toPut = <Map<String, dynamic>>[];
    for (final raw in backup.history) {
      final key = raw['key'];
      final entry = raw['entry'];
      if (key is! String || entry is! Map) continue;
      final timestamp = (entry['timestamp'] as int?) ?? 0;
      if (!local.containsKey(key) || timestamp > (local[key] ?? 0)) {
        toPut.add(raw);
        historyRestored++;
      } else {
        historySkipped++;
      }
    }
    if (toPut.isNotEmpty) {
      await storage.restoreHistoryEntries(toPut);
    }

    // Library: add what is missing.
    final library = ref.read(libraryRepositoryProvider);
    for (final raw in backup.library) {
      final item = libraryItemFromBackup(raw);
      if (item == null) continue;
      try {
        final wasThere = library.isInLibrary(item.url);
        await library.addToLibrary(item);
        if (!wasThere) libraryRestored++;
      } catch (e) {
        errors.add('Could not restore bookmark "${item.title}": $e');
      }
    }

    // SkyStream repositories, then their plugins.
    try {
      final extensions = ref.read(extensionsControllerProvider.notifier);
      await extensions.ensureInitialized();
      var extensionsState = ref.read(extensionsControllerProvider);
      for (final url in backup.skystreamRepos) {
        if (extensionsState.repositories.any((repo) => repo.url == url)) {
          continue;
        }
        try {
          await extensions.addRepository(url);
          skystreamReposRestored++;
        } catch (e) {
          errors.add('Could not add repository $url: $e');
        }
        extensionsState = ref.read(extensionsControllerProvider);
      }
      for (final saved in backup.skystreamPlugins) {
        final packageName = saved['packageName'];
        if (packageName == null || packageName.isEmpty) continue;
        if (extensionsState.installedPlugins.any(
          (plugin) => plugin.packageName == packageName,
        )) {
          continue;
        }
        final found = _findSkyStreamPlugin(extensionsState, packageName);
        if (found == null) {
          errors.add(
            'Plugin $packageName is no longer listed by its repository, so it was not restored.',
          );
          continue;
        }
        try {
          await extensions.installPlugin(found);
          skystreamPluginsRestored++;
        } catch (e) {
          errors.add('Could not install ${found.name}: $e');
        }
        extensionsState = ref.read(extensionsControllerProvider);
      }
    } catch (e) {
      errors.add('SkyStream plugins were not restored: $e');
    }

    // CloudStream repositories, then their plugins.
    try {
      final cloudstream = ref.read(cloudStreamRepositoryProvider.notifier);
      await cloudstream.load();
      var cloudstreamState = ref.read(cloudStreamRepositoryProvider);
      for (final url in backup.cloudstreamRepos) {
        if (cloudstreamState.repositories.any((repo) => repo.url == url)) {
          continue;
        }
        try {
          await cloudstream.addRepository(url);
          cloudstreamReposRestored++;
        } catch (e) {
          errors.add('Could not add repository $url: $e');
        }
        cloudstreamState = ref.read(cloudStreamRepositoryProvider);
      }
      if (!cloudstreamState.enabled) {
        if (backup.cloudstreamPlugins.isNotEmpty) {
          errors.add(
            'CloudStream is switched off, so its ${backup.cloudstreamPlugins.length} plugin(s) were not restored. Switch it on in Settings and import again.',
          );
        }
      } else {
        for (final saved in backup.cloudstreamPlugins) {
          final internalName = saved['internalName'];
          final repositoryUrl = saved['repositoryUrl'];
          if (internalName == null || repositoryUrl == null) continue;
          if (cloudstreamState.installed.any(
            (plugin) =>
                plugin.info.internalName == internalName &&
                plugin.info.repositoryUrl == repositoryUrl,
          )) {
            continue;
          }
          final found = _findCloudStreamPlugin(
            cloudstreamState,
            internalName,
            repositoryUrl,
          );
          if (found == null) {
            errors.add(
              'Plugin ${saved['name'] ?? internalName} is no longer listed by its repository, so it was not restored.',
            );
            continue;
          }
          try {
            await cloudstream.install(found);
            cloudstreamPluginsRestored++;
          } catch (e) {
            errors.add('Could not install ${found.name}: $e');
          }
          cloudstreamState = ref.read(cloudStreamRepositoryProvider);
        }
      }
    } catch (e) {
      errors.add('CloudStream plugins were not restored: $e');
    }

    // Push the restored items into the Home / Library UI. Both providers
    // are keep-alive and cache their lists, and this restore writes straight
    // to the boxes/repository — without a refresh, Continue Watching and the
    // Library keep showing the pre-import (empty) list until the app
    // restarts.
    if (historyRestored > 0) {
      ref.read(watchHistoryProvider.notifier).refresh();
    }
    if (libraryRestored > 0) {
      ref.read(libraryProvider.notifier).refresh();
    }

    return AppRestoreReport(
      historyRestored: historyRestored,
      historySkipped: historySkipped,
      historyInBackup: backup.history.length,
      libraryRestored: libraryRestored,
      skystreamReposRestored: skystreamReposRestored,
      skystreamPluginsRestored: skystreamPluginsRestored,
      cloudstreamReposRestored: cloudstreamReposRestored,
      cloudstreamPluginsRestored: cloudstreamPluginsRestored,
      errors: errors,
    );
  }

  static ExtensionPlugin? _findSkyStreamPlugin(
    ExtensionsState extensionsState,
    String packageName,
  ) {
    for (final plugins in extensionsState.availablePlugins.values) {
      for (final plugin in plugins) {
        if (plugin.packageName == packageName) return plugin;
      }
    }
    return null;
  }

  static CsPluginInfo? _findCloudStreamPlugin(
    CloudStreamState cloudstreamState,
    String internalName,
    String repositoryUrl,
  ) {
    // The repository it came from first; any repository listing it second
    // (a repository can move, and the plugin is the same file).
    for (final repo in cloudstreamState.repositories) {
      if (repo.url != repositoryUrl) continue;
      for (final plugin in repo.plugins) {
        if (plugin.internalName == internalName) return plugin;
      }
    }
    for (final repo in cloudstreamState.repositories) {
      for (final plugin in repo.plugins) {
        if (plugin.internalName == internalName) return plugin;
      }
    }
    return null;
  }

  // --- export / import (no backend) --------------------------------------------

  /// Writes the backup to a file the user can keep. Returns the path and
  /// whether the share sheet was opened, or null when the user cancels. On
  /// iOS there is no save dialog, so the file goes to a temp file and the
  /// share sheet opens for "Save to Files".
  Future<({String path, bool openedShareSheet})?> exportBackupFile() async {
    if (_exportInProgress) return null;
    _exportInProgress = true;
    try {
      return await _exportBackupFile();
    } finally {
      _exportInProgress = false;
    }
  }

  Future<({String path, bool openedShareSheet})?> _exportBackupFile() async {
    final backup = await collectBackup();
    final bytes = utf8.encode(
      const JsonEncoder.withIndent('  ').convert(backup.toJson()),
    );
    final stamp = DateTime.now().toIso8601String().replaceAll(':', '-');
    final fileName = 'skystream-backup-$stamp.json';
    try {
      final uri = await FilePicker.saveFile(
        dialogTitle: 'Save SkyStream backup',
        fileName: fileName,
        type: FileType.custom,
        allowedExtensions: ['json'],
        bytes: bytes,
      );
      if (uri != null) {
        return (path: uri.toFilePath(), openedShareSheet: false);
      }
    } catch (e) {
      talker.warning('[Backup] save dialog failed: $e');
    }
    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/$fileName');
    await file.writeAsBytes(bytes, flush: true);
    await OpenFile.open(file.path);
    return (path: file.path, openedShareSheet: true);
  }

  /// True while a backup import is running. The UI answers a second tap
  /// with "already running" instead of silence: the old `importBackupFile()`
  /// returned null for a tap that landed mid-import, which the UI read as
  /// "user cancelled". (The guard covers the pick; the UI's progress dialog
  /// covers the restore that follows it.)
  bool get importInProgress => _importInProgress;

  /// Picks a backup file and restores it. Returns the restore report, or
  /// null when the user cancels the picker. Throws [BackupException]
  /// when the file is not a SkyStream backup.
  Future<AppRestoreReport?> importBackupFile() async {
    final backup = await pickBackupFile();
    if (backup == null) return null;
    return await restoreBackup(backup);
  }

  /// Picks a backup file and parses it, without restoring it — so the UI can
  /// show progress while the (slow, network) restore runs. Returns null when
  /// the user cancels the picker. Throws [BackupException] when the file
  /// is not a SkyStream backup, [PlatformException] when the picker itself fails.
  Future<AppBackup?> pickBackupFile() async {
    if (_importInProgress) return null;
    _importInProgress = true;
    try {
      return await _pickBackupFile();
    } finally {
      _importInProgress = false;
    }
  }

  Future<AppBackup?> _pickBackupFile() async {
    try {
      // file_picker throws PlatformException(multiple_request) when a pick
      // is started while another pick is still open (a stale pending
      // picker). The raw exception reads like a crash; tell the user to
      // tap Import again instead — the guard above is reset in `finally`,
      // so the next tap works. (Only the picker in this block can throw a
      // PlatformException, so the catch below is effectively pick-only.)
      final picked = await FilePicker.pickFile(
        dialogTitle: 'Import SkyStream backup',
        type: FileType.custom,
        allowedExtensions: ['json'],
      );
      if (picked == null) return null;
      // On iOS the picked file is a security-scoped URL, not a plain path:
      // XFile reads it either way.
      final bytes = picked.path != null
          ? await File(picked.path!).readAsBytes()
          : await picked.xFile.readAsBytes();
      final decoded = jsonDecode(utf8.decode(bytes));
      if (decoded is! Map) {
        throw const BackupException('That file is not a SkyStream backup.');
      }
      return AppBackup.fromJson(Map<String, dynamic>.from(decoded));
    } on PlatformException catch (e) {
      if (e.code == 'multiple_request') {
        throw const BackupException(
          'The file picker was already open — please tap Import again.',
        );
      }
      rethrow;
    }
  }
}
