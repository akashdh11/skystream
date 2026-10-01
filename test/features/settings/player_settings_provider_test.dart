import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:skystream/core/storage/secure_token_storage.dart';
import 'package:skystream/core/storage/storage_service.dart';
import 'package:skystream/features/settings/presentation/player_settings_provider.dart';

/// Source of [PlayerSettings], read as text.
///
/// The guard below is about a parameter that *exists in the signature*, which
/// no amount of calling the API can observe: a `copyWith` argument with no
/// backing field compiles, runs, and silently does nothing. Only the source
/// text can tell us it is there.
const String _source =
    'lib/features/settings/presentation/player_settings_provider.dart';

/// `copyWith` parameters that intentionally have no field of the same name.
///
/// A nullable field cannot be *cleared* through `T? x` — passing null is
/// indistinguishable from passing nothing — so [PlayerSettings.preferredPlayer]
/// takes a companion flag instead. That is a deliberate pattern, not debris.
const Set<String> _fieldlessByDesign = <String>{'clearPreferredPlayer'};

/// Every read refuses, the way a Linux box with no libsecret does.
class _BrokenCredentials extends SecureTokenStorage {
  _BrokenCredentials() : super(StorageService());

  @override
  Future<String?> read(String key) async =>
      throw StateError('credential store unavailable');
}

/// A real box behind a first read that fails.
///
/// The one way `build` can leave the provider in [AsyncError], which it then
/// stays in for the rest of the session — every later setter has to cope.
class _FailsFirstRead extends StorageService {
  bool _failed = false;

  @override
  T? getPlayerSetting<T>(String key, {T? defaultValue}) {
    if (!_failed) {
      _failed = true;
      throw StateError('settings box unavailable');
    }
    return super.getPlayerSetting<T>(key, defaultValue: defaultValue);
  }
}

String _classBody(String src) {
  final int start = src.indexOf('class PlayerSettings {');
  final int end = src.indexOf('  const PlayerSettings({', start);
  expect(start, isNonNegative, reason: 'class PlayerSettings not found');
  expect(end, greaterThan(start), reason: 'PlayerSettings constructor moved');
  return src.substring(start, end);
}

String _copyWithParams(String src) {
  final int start = src.indexOf('PlayerSettings copyWith({');
  expect(start, isNonNegative, reason: 'PlayerSettings.copyWith not found');
  final int end = src.indexOf('\n  }) {', start);
  expect(end, greaterThan(start), reason: 'copyWith signature not closed');
  return src.substring(start, end);
}

void main() {
  final binding = TestWidgetsFlutterBinding.ensureInitialized();

  test('every copyWith parameter is backed by a field', () {
    final String src = File(_source).readAsStringSync();

    final Set<String> fields = RegExp(
      r'\bfinal\s+[^;]*?(\w+)\s*;',
    ).allMatches(_classBody(src)).map((RegExpMatch m) => m.group(1)!).toSet();
    expect(
      fields,
      contains('subtitleSize'),
      reason: 'field scrape is broken, not the class',
    );

    final List<String> params = <String>[];
    for (final String line in _copyWithParams(src).split('\n').skip(1)) {
      final RegExpMatch? m = RegExp(
        r'(\w+)\s*(?:=\s*[^,]+)?,\s*$',
      ).firstMatch(line);
      if (m != null) params.add(m.group(1)!);
    }
    expect(
      params.length,
      greaterThan(20),
      reason: 'parameter scrape is broken, not the signature',
    );

    final List<String> dead = params
        .where((String p) => !fields.contains(p))
        .where((String p) => !_fieldlessByDesign.contains(p))
        .toList();

    expect(
      dead,
      isEmpty,
      reason:
          'copyWith takes ${dead.join(', ')} but PlayerSettings has no such '
          'field, so passing one is silently ignored. Six of these were left '
          'behind when the media_kit subtitle model was deleted.',
    );
  });

  test('the Wi-Fi quality ceiling defaults to 1080p, not 4K', () {
    // Deliberate: a 3840x2160 render target is ~33 MB per frame and there is
    // no in-app escape once a 4K stream is picked. Reverting this to q4k was
    // proposed and rejected; the constant and both of its use sites stay.
    expect(kDefaultWifiQuality, QualityPreference.q1080);
    expect(const PlayerSettings().wifiQuality, kDefaultWifiQuality);
    expect(const PlayerSettings().mobileQuality, QualityPreference.q1080);

    final String src = File(_source).readAsStringSync();
    expect(
      RegExp(r'\bkDefaultWifiQuality\b').allMatches(src).length,
      greaterThanOrEqualTo(3),
      reason: 'the constant, the field default and the storage fallback',
    );
    expect(
      src.contains('QualityPreference.q4k,\n'),
      isFalse,
      reason: 'no default may be hardcoded to 4K',
    );
  });

  test('the live subtitle appearance fields survive copyWith', () {
    const PlayerSettings defaults = PlayerSettings();
    expect(defaults.subtitleSize, 22.0);
    expect(defaults.subtitleColor, 0xFFFFFFFF);
    expect(defaults.subtitleBackgroundColor, 0x00000000);
    expect(defaults.subtitleBackgroundOpacity, 0.5);

    final PlayerSettings styled = defaults.copyWith(
      subtitleSize: 30.0,
      subtitleColor: 0xFFFFEB3B,
      subtitleBackgroundColor: 0xFF303030,
      subtitleBackgroundOpacity: 0.0,
    );
    expect(styled.subtitleSize, 30.0);
    expect(styled.subtitleColor, 0xFFFFEB3B);
    expect(styled.subtitleBackgroundColor, 0xFF303030);
    expect(styled.subtitleBackgroundOpacity, 0.0);
    expect(styled.wifiQuality, kDefaultWifiQuality);
  });

  /// The OpenSubtitles and SubDL passwords are *account* passwords the user
  /// reuses elsewhere, not revocable API tokens. Held in the Hive settings box
  /// they were copied verbatim into Android's cloud backup and into iOS
  /// device-to-device transfer and unencrypted Finder backups.
  ///
  /// Driven against a real [StorageService] on a real Hive box in a temp
  /// directory and the real notifier, so "the box no longer holds it" is the
  /// genuine on-disk state and not a fake's opinion. The secure backend is the
  /// package's own in-memory test platform, whose map is the same instance
  /// handed to [FlutterSecureStorage.setMockInitialValues] — so the assertions
  /// below read what the Keychain/Keystore would have been given.
  group('subtitle account passwords live in the platform secure store', () {
    late Directory dir;
    late StorageService storage;
    late Map<String, String> keychain;

    setUp(() async {
      dir = Directory.systemTemp.createTempSync('player_settings_creds');
      binding.defaultBinaryMessenger.setMockMethodCallHandler(
        const MethodChannel('plugins.flutter.io/path_provider'),
        (MethodCall call) async => dir.path,
      );
      storage = StorageService();
      await storage.init();
      keychain = <String, String>{};
      FlutterSecureStorage.setMockInitialValues(keychain);
    });

    tearDown(() async {
      await Hive.close();
      binding.defaultBinaryMessenger.setMockMethodCallHandler(
        const MethodChannel('plugins.flutter.io/path_provider'),
        null,
      );
      if (dir.existsSync()) dir.deleteSync(recursive: true);
    });

    ProviderContainer boot() {
      final ProviderContainer container = ProviderContainer(
        overrides: [storageServiceProvider.overrideWithValue(storage)],
      );
      addTearDown(container.dispose);
      return container;
    }

    test(
      'a password left behind by an older build migrates out of Hive',
      () async {
        // Exactly what an upgrading user has on disk: the plaintext keys the
        // previous build wrote, in the box that gets backed up.
        await storage.setPlayerSetting('player_os_user', 'ada');
        await storage.setPlayerSetting('player_os_pass', 'hunter2');
        await storage.setPlayerSetting(
          'player_subdl_email',
          'ada@example.test',
        );
        await storage.setPlayerSetting('player_subdl_pass', 'correct-horse');

        final ProviderContainer container = boot();
        await container.read(playerSettingsProvider.future);
        // `build` no longer waits on the secure store, so the two passwords
        // arrive one channel round-trip after the rest of the settings.
        await pumpEventQueue();
        final PlayerSettings settings = container
            .read(playerSettingsProvider)
            .requireValue;

        expect(
          settings.osPassword,
          'hunter2',
          reason: 'the upgrade must not sign the user out',
        );
        expect(settings.subdlPassword, 'correct-horse');

        expect(keychain[kOsPasswordKey], 'hunter2');
        expect(keychain[kSubDlPasswordKey], 'correct-horse');

        expect(
          storage.getPlayerSetting<String>('player_os_pass'),
          isNull,
          reason: 'the plaintext copy in the backed-up box must be gone',
        );
        expect(storage.getPlayerSetting<String>('player_subdl_pass'), isNull);

        // The non-secret half of the same account is untouched: this moved the
        // passwords, it did not empty the settings box.
        expect(storage.getPlayerSetting<String>('player_os_user'), 'ada');
        expect(
          storage.getPlayerSetting<String>('player_subdl_email'),
          'ada@example.test',
        );
      },
    );

    test(
      'signing in writes the password to the secure store, not to Hive',
      () async {
        final ProviderContainer container = boot();
        await container.read(playerSettingsProvider.future);

        await container
            .read(playerSettingsProvider.notifier)
            .setOpenSubtitlesCredentials('ada', 'hunter2', 'os-api-key');
        await container
            .read(playerSettingsProvider.notifier)
            .setSubDlAuth(
              apiKey: 'subdl-api-key',
              email: 'ada@example.test',
              pass: 'correct-horse',
            );

        expect(keychain[kOsPasswordKey], 'hunter2');
        expect(keychain[kSubDlPasswordKey], 'correct-horse');
        expect(
          storage.getPlayerSetting<String>('player_os_pass'),
          isNull,
          reason: 'a fresh sign-in must never put the password in the box',
        );
        expect(storage.getPlayerSetting<String>('player_subdl_pass'), isNull);

        // Re-reading the settings still produces the password the user typed.
        final PlayerSettings settings = container
            .read(playerSettingsProvider)
            .requireValue;
        expect(settings.osPassword, 'hunter2');
        expect(settings.subdlPassword, 'correct-horse');
      },
    );

    test('the two account passwords are the only secure keys a reset '
        'removes', () async {
      // A tracking session and a subtitle account share the store; only the
      // second pair belongs to "Reset Data (Keep Extensions)".
      keychain['trakt_access_token'] = 'oauth-token';
      final ProviderContainer container = boot();
      await container
          .read(playerSettingsProvider.notifier)
          .setOpenSubtitlesCredentials('ada', 'hunter2', 'os-api-key');
      await container.read(playerSettingsProvider.notifier).setSubDlAuth(
        apiKey: 'subdl-api-key',
        pass: 'correct-horse',
      );

      await container.read(playerSettingsProvider.notifier).clearCredentials();

      expect(keychain[kOsPasswordKey], isNull);
      expect(keychain[kSubDlPasswordKey], isNull);
      expect(
        keychain['trakt_access_token'],
        'oauth-token',
        reason: 'the reset that keeps extensions keeps OAuth sessions too',
      );

      final PlayerSettings settings = container
          .read(playerSettingsProvider)
          .requireValue;
      expect(settings.osPassword, '');
      expect(settings.subdlPassword, '');
    });
  });

  /// Three routes push the player without awaiting this provider, and the
  /// settings screens render a row per frame from whatever it holds. While
  /// `build` was async for two secure-store reads, all of them saw
  /// `const PlayerSettings()` — the viewer's subtitle size, resize mode and
  /// decode preference were the factory defaults for the whole session.
  group('the settings resolve on the first read', () {
    late Directory dir;
    late StorageService storage;

    setUp(() async {
      dir = Directory.systemTemp.createTempSync('player_settings_sync');
      binding.defaultBinaryMessenger.setMockMethodCallHandler(
        const MethodChannel('plugins.flutter.io/path_provider'),
        (MethodCall call) async => dir.path,
      );
      storage = StorageService();
      await storage.init();
      FlutterSecureStorage.setMockInitialValues(<String, String>{});
    });

    tearDown(() async {
      await Hive.close();
      binding.defaultBinaryMessenger.setMockMethodCallHandler(
        const MethodChannel('plugins.flutter.io/path_provider'),
        null,
      );
      if (dir.existsSync()) dir.deleteSync(recursive: true);
    });

    ProviderContainer boot(StorageService service) {
      final ProviderContainer container = ProviderContainer(
        overrides: [storageServiceProvider.overrideWithValue(service)],
      );
      addTearDown(container.dispose);
      return container;
    }

    test('a consumer that never awaits gets the stored values', () async {
      await storage.setPlayerSetting('player_sub_size', 40.0);
      await storage.setPlayerSetting('player_hw_dec', false);
      await storage.setPlayerSetting('player_default_resize', 'Cover');

      // No await anywhere: exactly what `initState` does on the frame the
      // player is pushed.
      final AsyncValue<PlayerSettings> first = boot(
        storage,
      ).read(playerSettingsProvider);

      expect(
        first.hasValue,
        isTrue,
        reason: 'the first read must not be a loading state',
      );
      expect(first.requireValue.subtitleSize, 40.0);
      expect(first.requireValue.hardwareDecoding, isFalse);
      expect(first.requireValue.defaultResizeMode, 'Cover');
    });

    test('volume visibility defaults on and survives a new provider', () async {
      final container = boot(storage);
      expect(
        container.read(playerSettingsProvider).requireValue.showVolume,
        isTrue,
      );
      await container
          .read(playerSettingsProvider.notifier)
          .setShowVolume(false);
      expect(
        container.read(playerSettingsProvider).requireValue.showVolume,
        isFalse,
      );
      expect(storage.getPlayerSetting<bool>('player_show_volume'), isFalse);
      final restored = boot(storage).read(playerSettingsProvider).requireValue;
      expect(restored.showVolume, isFalse);
      expect(restored.copyWith(showResize: false).showVolume, isFalse);
      await container.read(playerSettingsProvider.notifier).setShowVolume(true);
      expect(
        boot(storage).read(playerSettingsProvider).requireValue.showVolume,
        isTrue,
      );
    });

    test('a setter after a failed load writes and does not throw', () async {
      final _FailsFirstRead broken = _FailsFirstRead();
      await broken.init();
      final ProviderContainer container = boot(broken);

      expect(
        container.read(playerSettingsProvider).hasError,
        isTrue,
        reason: 'the failed read has to reach the state, or this proves '
            'nothing',
      );

      // Fire-and-forget at every call site, so a throw here escapes as an
      // unhandled async error and the Hive write is already done.
      await expectLater(
        container
            .read(playerSettingsProvider.notifier)
            .setShowRemainingTime(true),
        completes,
      );
      expect(broken.getPlayerSetting<bool>('player_show_remaining'), isTrue);
    });

    // The secure-store read is the one thing `build` no longer waits for, so
    // it runs on its own after the settings have already been handed out.
    // Nothing awaits it: a throw there is an unhandled async error, and the
    // settings it cannot add to are already in the viewer's hands.
    test('an unreadable credential store does not escape as an error',
        () async {
      final ProviderContainer container = ProviderContainer(
        overrides: [
          storageServiceProvider.overrideWithValue(storage),
          secureTokenStorageProvider.overrideWithValue(_BrokenCredentials()),
        ],
      );
      addTearDown(container.dispose);

      final PlayerSettings settings = container
          .read(playerSettingsProvider)
          .requireValue;
      expect(settings.osPassword, '');
      await pumpEventQueue();

      expect(
        container.read(playerSettingsProvider).hasValue,
        isTrue,
        reason: 'the rest of the settings were readable and were returned',
      );
    });
  });

  /// The one player setting that changes what happens before the viewer has
  /// touched anything, so its default and its parsing are the whole contract:
  /// an install that has never opened the row has to behave exactly as it did
  /// before the row existed.
  ///
  /// Driven against a real [StorageService] on a real Hive box, like the
  /// credentials group above, because "it reads back" is a claim about the box
  /// and not about a fake's opinion.
  group('the subtitle default', () {
    late Directory dir;
    late StorageService storage;

    setUp(() async {
      dir = Directory.systemTemp.createTempSync('player_settings_subtitles');
      binding.defaultBinaryMessenger.setMockMethodCallHandler(
        const MethodChannel('plugins.flutter.io/path_provider'),
        (MethodCall call) async => dir.path,
      );
      storage = StorageService();
      await storage.init();
      FlutterSecureStorage.setMockInitialValues(<String, String>{});
    });

    tearDown(() async {
      await Hive.close();
      binding.defaultBinaryMessenger.setMockMethodCallHandler(
        const MethodChannel('plugins.flutter.io/path_provider'),
        null,
      );
      if (dir.existsSync()) dir.deleteSync(recursive: true);
    });

    ProviderContainer boot() {
      final ProviderContainer container = ProviderContainer(
        overrides: [storageServiceProvider.overrideWithValue(storage)],
      );
      addTearDown(container.dispose);
      return container;
    }

    test('is Auto out of the box', () {
      expect(const PlayerSettings().subtitleDefault, SubtitleDefault.auto);
    });

    test('an empty box reads back as Auto, not as null or Off', () async {
      final PlayerSettings settings = await boot().read(
        playerSettingsProvider.future,
      );
      expect(settings.subtitleDefault, SubtitleDefault.auto);
    });

    test('a choice survives the next launch', () async {
      final ProviderContainer first = boot();
      await first.read(playerSettingsProvider.future);
      await first
          .read(playerSettingsProvider.notifier)
          .setSubtitleDefault(SubtitleDefault.off);

      expect(
        first.read(playerSettingsProvider).requireValue.subtitleDefault,
        SubtitleDefault.off,
        reason: 'the setter has to move the state, not only the box',
      );
      expect(
        storage.getPlayerSetting<String>('player_subtitle_default'),
        'off',
        reason:
            'the stored form is the enum name, which is what the read side '
            'matches on',
      );

      // A second container is the next launch: nothing carries over but the
      // box.
      final PlayerSettings reread = await boot().read(
        playerSettingsProvider.future,
      );
      expect(reread.subtitleDefault, SubtitleDefault.off);
    });

    test('a value the enum does not know falls back to Auto', () async {
      // A build that offered a third choice, or a box that got scribbled on.
      // Either way the wrong answer here is a player that starts with no
      // subtitles for somebody who never asked for that.
      await storage.setPlayerSetting('player_subtitle_default', 'forced');

      final PlayerSettings settings = await boot().read(
        playerSettingsProvider.future,
      );
      expect(settings.subtitleDefault, SubtitleDefault.auto);
    });

    test('copyWith carries it', () {
      const PlayerSettings defaults = PlayerSettings();
      expect(
        defaults.copyWith(subtitleDefault: SubtitleDefault.off).subtitleDefault,
        SubtitleDefault.off,
      );
      expect(
        defaults.copyWith(subtitleSize: 30.0).subtitleDefault,
        SubtitleDefault.auto,
        reason: 'an unrelated copyWith must not reset it',
      );
    });
  });
}
