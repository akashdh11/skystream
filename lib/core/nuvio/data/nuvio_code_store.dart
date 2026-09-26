import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// On-disk cache for Nuvio scraper code.
///
/// The All-in-One repository alone is 3.3 MB of JavaScript across 61 files,
/// with one 1 MB bundle. SharedPreferences keeps everything in a single XML
/// document that is parsed into memory at startup and rewritten on every
/// change, so caching plugin code there makes launch slower the more plugins
/// the user installs. Nuvio keeps the code in files (`PluginScraperCodeFileStore`)
/// and so do we — one file per scraper *version*, which also means a stale
/// version can never be executed after an update.
class NuvioCodeStore {
  NuvioCodeStore({Directory? root}) : _root = root;

  Directory? _root;
  Future<Directory>? _pending;

  /// Small in-memory cache so a playback session doesn't re-read from disk.
  /// Bounded, because these strings are large.
  static const int _maxMemoryEntries = 8;
  final Map<String, String> _memory = <String, String>{};

  Future<Directory> _directory() async {
    final existing = _root;
    if (existing != null) return existing;
    return _pending ??= () async {
      final base = await getApplicationSupportDirectory();
      final dir = Directory(p.join(base.path, 'nuvio_plugins'));
      if (!await dir.exists()) await dir.create(recursive: true);
      _root = dir;
      return dir;
    }();
  }

  /// One file per repository + scraper + version.
  static String fileNameFor({
    required String manifestUrl,
    required String scraperId,
    required String version,
  }) {
    final repo = sha1
        .convert(utf8.encode(manifestUrl))
        .toString()
        .substring(0, 12);
    final safeId = _safeName(scraperId);
    final safeVersion = _safeName(version);
    return '$repo.$safeId@$safeVersion.js';
  }

  /// Uri.encodeComponent-style naming for a file-name piece: everything
  /// outside the unreserved set becomes %XX, so no path separator, query
  /// character, `@` or `..` pair can survive into a file name.
  /// encodeComponent keeps dots on its own, and a leading dot would hide
  /// the file while `..` would read as traversal — dots are encoded too.
  static String _safeName(String value) =>
      Uri.encodeComponent(value).replaceAll('.', '%2E');

  /// The inverse of [_safeName]; a name written by an older build (plain
  /// sanitising) decodes to itself, which is close enough for the sweep.
  static String _decodedName(String piece) {
    try {
      return Uri.decodeComponent(piece);
    } catch (_) {
      return piece;
    }
  }

  /// The in-memory key encodes id and version the same way, so an id that
  /// contains `#` or `@` cannot be mistaken for the key's own separators.
  String _memoryKey(String manifestUrl, String scraperId, String version) =>
      '$manifestUrl#${Uri.encodeComponent(scraperId)}@${Uri.encodeComponent(version)}';

  void _remember(String key, String code) {
    _memory[key] = code;
    while (_memory.length > _maxMemoryEntries) {
      _memory.remove(_memory.keys.first);
    }
  }

  Future<String?> read({
    required String manifestUrl,
    required String scraperId,
    required String version,
  }) async {
    final key = _memoryKey(manifestUrl, scraperId, version);
    final cached = _memory[key];
    if (cached != null) return cached;
    try {
      final dir = await _directory();
      final file = File(
        p.join(
          dir.path,
          fileNameFor(
            manifestUrl: manifestUrl,
            scraperId: scraperId,
            version: version,
          ),
        ),
      );
      if (!await file.exists()) return null;
      final code = await file.readAsString();
      if (code.trim().isEmpty) return null;
      _remember(key, code);
      return code;
    } catch (error) {
      if (kDebugMode) debugPrint('[Nuvio] code read failed: $error');
      return null;
    }
  }

  Future<void> write({
    required String manifestUrl,
    required String scraperId,
    required String version,
    required String code,
  }) async {
    _remember(_memoryKey(manifestUrl, scraperId, version), code);
    try {
      final dir = await _directory();
      final file = File(
        p.join(
          dir.path,
          fileNameFor(
            manifestUrl: manifestUrl,
            scraperId: scraperId,
            version: version,
          ),
        ),
      );
      await file.writeAsString(code, flush: false);
    } catch (error) {
      if (kDebugMode) debugPrint('[Nuvio] code write failed: $error');
    }
  }

  /// Forget every cached version of the given scrapers (used when the
  /// developer publishes a new version).
  Future<void> deleteScrapers({
    required String manifestUrl,
    required Set<String> scraperIds,
  }) async {
    if (scraperIds.isEmpty) return;
    final wanted = {for (final id in scraperIds) Uri.encodeComponent(id)};
    _memory.removeWhere((key, _) {
      if (!key.startsWith('$manifestUrl#')) return false;
      final id = key.split('#').last.split('@').first;
      return wanted.contains(id);
    });
    // [_sweep] hands back decoded ids, so the raw set matches there.
    await _sweep(manifestUrl, (id, _) => scraperIds.contains(id));
  }

  /// Drop files for scrapers/versions the manifest no longer lists.
  Future<void> prune({
    required String manifestUrl,
    required Set<String> keepIdVersions,
  }) async {
    _memory.removeWhere((key, _) {
      if (!key.startsWith('$manifestUrl#')) return false;
      final rest = key.split('#').last;
      final at = rest.lastIndexOf('@');
      if (at < 0) return false;
      final id = _decodedName(rest.substring(0, at));
      final version = _decodedName(rest.substring(at + 1));
      return !keepIdVersions.contains('$id@$version');
    });
    await _sweep(
      manifestUrl,
      (id, version) => !keepIdVersions.contains('$id@$version'),
    );
  }

  Future<void> deleteRepository(String manifestUrl) async {
    _memory.removeWhere((key, _) => key.startsWith('$manifestUrl#'));
    await _sweep(manifestUrl, (_, _) => true);
  }

  Future<void> _sweep(
    String manifestUrl,
    bool Function(String scraperId, String version) shouldDelete,
  ) async {
    try {
      final dir = await _directory();
      if (!await dir.exists()) return;
      final prefix =
          '${sha1.convert(utf8.encode(manifestUrl)).toString().substring(0, 12)}.';
      await for (final entity in dir.list()) {
        if (entity is! File) continue;
        final name = p.basename(entity.path);
        if (!name.startsWith(prefix) || !name.endsWith('.js')) continue;
        final body = name.substring(prefix.length, name.length - 3);
        final at = body.lastIndexOf('@');
        if (at < 0) continue;
        // File names carry encodeComponent pieces; decode them back so the
        // caller can compare against the ids the manifest actually uses.
        if (shouldDelete(
          _decodedName(body.substring(0, at)),
          _decodedName(body.substring(at + 1)),
        )) {
          await entity.delete();
        }
      }
    } catch (error) {
      if (kDebugMode) debugPrint('[Nuvio] code sweep failed: $error');
    }
  }

  /// Total bytes on disk, for the "storage used" line in the plugins screen.
  Future<int> usedBytes() async {
    try {
      final dir = await _directory();
      if (!await dir.exists()) return 0;
      var total = 0;
      await for (final entity in dir.list()) {
        if (entity is File) total += await entity.length();
      }
      return total;
    } catch (_) {
      return 0;
    }
  }
}
