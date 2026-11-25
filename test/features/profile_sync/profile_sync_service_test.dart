import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:skystream/core/network/dio_client_provider.dart';
import 'package:skystream/core/storage/secure_token_storage.dart';
import 'package:skystream/core/storage/storage_service.dart';
import 'package:skystream/features/profile_sync/data/profile_sync_service.dart';
import 'package:skystream/features/profile_sync/domain/profile_sync_payload.dart';
import 'package:skystream/features/profile_sync/profile_sync_hooks.dart';

const _pendingKey = 'profile_sync_pending_v1';
const _revisionKey = 'profile_sync_remote_revision_v1';

class _Storage extends StorageService {
  _Storage([Map<String, String>? saved]) {
    strings.addAll(saved ?? const {});
  }

  final strings = <String, String>{
    'profile_sync_server_url': 'https://sync.example.test',
  };
  final settings = <String, dynamic>{};
  int pendingWrites = 0;

  @override
  String? getString(String key) => strings[key];

  @override
  Future<void> setString(String key, String? value) async {
    if (key == _pendingKey) pendingWrites++;
    if (value == null) {
      strings.remove(key);
    } else {
      strings[key] = value;
    }
  }

  @override
  Future<void> remove(String key) async => strings.remove(key);

  @override
  T? getPlayerSetting<T>(String key, {T? defaultValue}) =>
      settings[key] as T? ?? defaultValue;

  @override
  Future<void> setPlayerSetting(String key, dynamic value) async {
    settings[key] = value;
  }
}

class _Tokens extends SecureTokenStorage {
  _Tokens(super.storage);

  @override
  Future<String?> read(String key) async => 'test-token';
}

class _ProfileAdapter implements HttpClientAdapter {
  final requests = <RequestOptions>[];
  int status = 304;
  int revision = 8;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(options);
    return ResponseBody.fromString(
      status == 304 ? '' : jsonEncode({'updatedAt': revision}),
      status,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
        'etag': ['"rev-$revision"'],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

class _Sync extends ProfileSyncNotifier {
  int collects = 0;
  Completer<ProfileSyncPayload>? nextSnapshot;
  Completer<void>? snapshotStarted;

  @override
  Future<ProfileSyncPayload> collectLocalProfile() async {
    collects++;
    final snapshot = nextSnapshot;
    nextSnapshot = null;
    snapshotStarted?.complete();
    snapshotStarted = null;
    return snapshot != null
        ? await snapshot.future
        : const ProfileSyncPayload(updatedAt: 0);
  }
}

Future<(ProviderContainer, _Sync)> _start(
  _Storage storage,
  _ProfileAdapter adapter,
) async {
  final dio = Dio()..httpClientAdapter = adapter;
  final container = ProviderContainer.test(
    overrides: [
      storageServiceProvider.overrideWithValue(storage),
      secureTokenStorageProvider.overrideWithValue(_Tokens(storage)),
      dioClientProvider.overrideWithValue(dio),
      profileSyncProvider.overrideWith(_Sync.new),
    ],
  );
  addTearDown(() => dio.close(force: true));
  final notifier = container.read(profileSyncProvider.notifier) as _Sync;
  await Future<void>.delayed(Duration.zero);
  expect(container.read(profileSyncProvider).isLoggedIn, isTrue);
  return (container, notifier);
}

void main() {
  test('startup and local writes make no network requests', () async {
    final storage = _Storage();
    final adapter = _ProfileAdapter();
    final (container, _) = await _start(storage, adapter);
    final hooks = container.read(profileSyncHooksProvider);
    for (var i = 0; i < 10; i++) {
      hooks.onLocalChange!();
    }

    expect(adapter.requests, isEmpty);
    expect(storage.pendingWrites, 1);
    expect(storage.strings[_pendingKey], '1');
  });

  test('a clean resume checks only the saved remote validator', () async {
    final storage = _Storage({
      _revisionKey: jsonEncode([8, '"rev-8"']),
    });
    final adapter = _ProfileAdapter();
    final (_, sync) = await _start(storage, adapter);
    await sync.syncAtBoundary(checkRemote: false);
    expect(adapter.requests, isEmpty);

    await sync.syncAtBoundary(checkRemote: true);
    expect(adapter.requests.single.headers['If-None-Match'], '"rev-8"');
    expect(sync.collects, 0);
  });

  test(
    'a failed boundary leaves pending changes for the next app session',
    () async {
      final storage = _Storage();
      final adapter = _ProfileAdapter()..status = 503;
      final (_, sync) = await _start(storage, adapter);
      sync.recordLocalChange();
      await sync.syncAtBoundary(checkRemote: false);
      expect(adapter.requests, hasLength(1));
      expect(storage.strings[_pendingKey], '1');

      final (_, restarted) = await _start(_Storage(storage.strings), adapter);
      expect(adapter.requests, hasLength(1));
      await restarted.syncAtBoundary(checkRemote: false);
      expect(adapter.requests, hasLength(2));
    },
  );

  test(
    'one full sync runs at a time and newer local work remains pending',
    () async {
      final storage = _Storage();
      final adapter = _ProfileAdapter()..status = 200;
      final (_, sync) = await _start(storage, adapter);
      sync.recordLocalChange();
      final snapshot = Completer<ProfileSyncPayload>();
      final started = Completer<void>();
      sync.nextSnapshot = snapshot;
      sync.snapshotStarted = started;
      final first = sync.syncNow(installMissingExtensions: false);

      expect(await sync.syncNow(installMissingExtensions: false), isFalse);
      await started.future;
      expect(adapter.requests, hasLength(1));
      sync.recordLocalChange();
      snapshot.complete(const ProfileSyncPayload(updatedAt: 0));
      expect(await first, isTrue);
      expect(storage.strings[_pendingKey], '1');

      expect(await sync.syncNow(installMissingExtensions: false), isTrue);
      expect(adapter.requests, hasLength(2));
      expect(storage.strings[_pendingKey], isNull);
    },
  );
}
