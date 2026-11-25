import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../features/profile_sync/profile_sync_hooks.dart';
import '../models/addon_manifest.dart';
import 'addon_client.dart';

part 'addon_repository.g.dart';

class AddonsState {
  final List<ManagedAddon> addons;
  final bool isLoading;

  const AddonsState({this.addons = const [], this.isLoading = true});

  List<ManagedAddon> get enabled =>
      addons.where((a) => a.isActive).toList(growable: false);

  int get catalogCount => enabled.fold(
    0,
    (sum, addon) => sum + (addon.manifest?.catalogs.length ?? 0),
  );

  AddonsState copyWith({List<ManagedAddon>? addons, bool? isLoading}) =>
      AddonsState(
        addons: addons ?? this.addons,
        isLoading: isLoading ?? this.isLoading,
      );
}

/// Owns the user's add-on list: install, enable, order, refresh, persistence.
///
/// Order is priority — the first add-on that answers a request wins, exactly
/// like Stremio and the reference clients.
@Riverpod(keepAlive: true)
class AddonRepository extends _$AddonRepository {
  static const String _prefsKey = 'stremio_addons_v2';

  /// The stored add-ons reaching [state]. [autoUpdate] waits on it, so a
  /// launch that builds this provider and updates in the same breath does not
  /// look at an empty list.
  Future<void> _loaded = Future<void>.value();

  /// See [CloudStreamRepository.load]: a second read must not replace [state]
  /// after a sync has installed add-ons.
  Future<void>? _loadInFlight;

  @override
  AddonsState build() {
    _loaded = load();
    return const AddonsState();
  }

  Future<void> load() {
    final current = _loadInFlight;
    if (current != null) return current;
    final run = _loadFromDisk();
    _loadInFlight = run;
    _loaded = run;
    return run.whenComplete(() {
      if (identical(_loadInFlight, run)) _loadInFlight = null;
    });
  }

  Future<void> _loadFromDisk() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getStringList(_prefsKey) ?? const <String>[];
      final addons = <ManagedAddon>[];
      for (final entry in raw) {
        try {
          final decoded = jsonDecode(entry);
          if (decoded is Map) {
            final addon = ManagedAddon.fromJson(
              Map<String, dynamic>.from(decoded),
            );
            if (addon != null) addons.add(addon);
          }
        } catch (error) {
          if (kDebugMode) debugPrint('[AddonRepository] bad entry: $error');
        }
      }
      if (!ref.mounted) return;
      state = AddonsState(addons: addons, isLoading: false);
      // Manifests can change (new catalogs, renamed rows), but the refresh is
      // not started from here: the launch runs [autoUpdate] once for every
      // extension system, and a second pass would fetch everything twice.
    } catch (error) {
      if (kDebugMode) debugPrint('[AddonRepository] load failed: $error');
      if (!ref.mounted) return;
      state = const AddonsState(addons: [], isLoading: false);
    }
  }

  Future<void> _persist(List<ManagedAddon> addons) async {
    if (!ref.mounted) return;
    state = state.copyWith(addons: addons, isLoading: false);
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList(
        _prefsKey,
        addons.map((a) => jsonEncode(a.toJson())).toList(),
      );
    } catch (error) {
      if (kDebugMode) debugPrint('[AddonRepository] persist failed: $error');
    }
  }

  void _notifySync() {
    if (ref.mounted) {
      ref.read(profileSyncHooksProvider).onLocalChange?.call();
    }
  }

  /// Installs from any pasted URL shape. Throws [AddonException] with a
  /// user-readable message when the manifest can't be used.
  Future<ManagedAddon> install(String rawUrl) =>
      _install(rawUrl, personWaiting: true, notifySync: true);

  /// Installs an add-on synced from another device without opening interactive
  /// checks or re-triggering sync.
  Future<ManagedAddon> installFromSync(String rawUrl) =>
      _install(rawUrl, personWaiting: false, notifySync: false);

  /// Fetches and installs multiple synced add-ons concurrently, persisting once.
  Future<void> installManyFromSync(
    Iterable<String> rawUrls, {
    void Function(String url, Object error)? onError,
  }) async {
    await _loaded;
    final candidates = <String>[];
    final seen = <String>{};
    for (final rawUrl in rawUrls) {
      final url = AddonTransport.normalizeManifestUrl(rawUrl);
      if (url.isEmpty ||
          !AddonTransport.looksValid(url) ||
          isInstalled(url) ||
          !seen.add(url)) {
        continue;
      }
      candidates.add(url);
    }
    if (candidates.isEmpty) return;

    final client = ref.read(addonClientProvider);
    Future<ManagedAddon?> fetchOne(String url) async {
      try {
        final manifest = await client.fetchManifest(
          url,
          forceRefresh: true,
          personWaiting: false,
        );
        return ManagedAddon(
          manifestUrl: url,
          manifest: manifest,
          addedAt: DateTime.now(),
        );
      } catch (error) {
        onError?.call(url, error);
        return null;
      }
    }

    final fetched = await Future.wait([for (final url in candidates) fetchOne(url)]);
    if (!ref.mounted) return;
    final next = List<ManagedAddon>.of(state.addons);
    var changed = false;
    for (final addon in fetched) {
      if (addon == null) continue;
      final existing = next.indexWhere(
        (a) =>
            a.manifestUrl == addon.manifestUrl ||
            (a.manifest?.id == addon.manifest?.id),
      );
      if (existing >= 0) {
        next[existing] = addon.copyWith(enabled: next[existing].enabled);
      } else {
        next.add(addon);
      }
      changed = true;
    }
    if (changed) await _persist(next);
  }

  Future<ManagedAddon> _install(
    String rawUrl, {
    required bool personWaiting,
    required bool notifySync,
  }) async {
    await _loaded;
    final url = AddonTransport.normalizeManifestUrl(rawUrl);
    if (!AddonTransport.looksValid(url)) {
      throw const AddonException('Enter a valid add-on URL.');
    }

    final manifest = await ref
        .read(addonClientProvider)
        .fetchManifest(url, forceRefresh: true, personWaiting: personWaiting);

    final addon = ManagedAddon(
      manifestUrl: url,
      manifest: manifest,
      addedAt: DateTime.now(),
    );

    final next = List<ManagedAddon>.of(state.addons);
    final existing = next.indexWhere(
      (a) => a.manifestUrl == url || (a.manifest?.id == manifest.id),
    );
    if (existing >= 0) {
      next[existing] = addon.copyWith(enabled: next[existing].enabled);
    } else {
      next.add(addon);
    }
    await _persist(next);
    if (notifySync) _notifySync();
    return addon;
  }

  Future<void> remove(String manifestUrl) async {
    await removeFromSync(manifestUrl);
    _notifySync();
  }

  Future<void> removeFromSync(String manifestUrl) async {
    await _loaded;
    final normalized = AddonTransport.normalizeManifestUrl(manifestUrl);
    await _persist(
      state.addons
          .where((a) => a.manifestUrl != manifestUrl && a.manifestUrl != normalized)
          .toList(),
    );
  }

  Future<void> setEnabled(String manifestUrl, bool enabled) async {
    await setEnabledFromSync(manifestUrl, enabled);
    _notifySync();
  }

  Future<void> setEnabledFromSync(String manifestUrl, bool enabled) async {
    await _loaded;
    final normalized = AddonTransport.normalizeManifestUrl(manifestUrl);
    var changed = false;
    final next = [
      for (final addon in state.addons)
        if (addon.manifestUrl == manifestUrl || addon.manifestUrl == normalized)
          (() {
            if (addon.enabled != enabled) changed = true;
            return addon.copyWith(enabled: enabled);
          })()
        else
          addon,
    ];
    if (changed) await _persist(next);
  }

  /// [newIndex] is already adjusted for the removed row.
  Future<void> reorder(int oldIndex, int newIndex) async {
    await _loaded;
    final next = List<ManagedAddon>.of(state.addons);
    if (oldIndex < 0 || oldIndex >= next.length) return;
    final addon = next.removeAt(oldIndex);
    next.insert(newIndex.clamp(0, next.length), addon);
    await _persist(next);
    _notifySync();
  }

  /// Launch-time update: every add-on's manifest fetched again, on every
  /// launch and on any connection. Returns the names of the add-ons whose
  /// version moved - see [refreshAll].
  Future<List<String>> autoUpdate() async {
    await _loaded;
    return refreshAll(silent: true);
  }

  /// Fetches every add-on's manifest again. Returns the names of the add-ons
  /// that now report a different version than the one stored; an add-on seen
  /// for the first time, or one that could not be reached, is not counted.
  Future<List<String>> refreshAll({bool silent = false}) async {
    if (state.addons.isEmpty) return const <String>[];
    if (!silent) state = state.copyWith(isLoading: true);

    final client = ref.read(addonClientProvider);
    final refreshed = <ManagedAddon>[];
    final updated = <String>[];
    for (final addon in state.addons) {
      try {
        final manifest = await client.fetchManifest(
          addon.manifestUrl,
          forceRefresh: true,
        );
        client.invalidate(addon);
        final before = addon.manifest?.version;
        if (before != null && before != manifest.version) {
          updated.add(manifest.name);
        }
        refreshed.add(addon.copyWith(manifest: manifest, clearError: true));
      } catch (error) {
        refreshed.add(addon.copyWith(errorMessage: error.toString()));
      }
    }
    await _persist(refreshed);
    return updated;
  }

  bool isInstalled(String rawUrl) {
    final url = AddonTransport.normalizeManifestUrl(rawUrl);
    return state.addons.any((a) => a.manifestUrl == url);
  }

  /// Enabled add-ons declaring [resource], in user order.
  List<ManagedAddon> providersOf(String resource) => state.enabled
      .where((a) => a.manifest?.hasResource(resource) ?? false)
      .toList(growable: false);
}
