import 'dart:io';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:flutter_displaymode/flutter_displaymode.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../config/tmdb_config.dart';
import '../storage/storage_service.dart';
import '../network/doh_service.dart';
import '../logger/app_logger.dart';

part 'bootstrap_provider.g.dart';

@Riverpod(keepAlive: true)
class Bootstrap extends _$Bootstrap {
  @override
  Future<void> build() async {
    talker.info('Bootstrap: Starting initialization...');

    final storageService = ref.read(storageServiceProvider);

    try {
      await Future.wait([
        storageService.init().then(
          (_) => talker.info('Bootstrap: Storage initialized'),
        ),
        DohService.instance.init().then(
          (_) => talker.info('Bootstrap: DoH initialized'),
        ),
        if (Platform.isAndroid)
          FlutterDisplayMode.setHighRefreshRate().catchError((Object e) {
            talker.error('Bootstrap: Error setting high refresh rate', e);
          }),
      ]);

      // Storage is open now, so TMDB keys the user saved in Settings or
      // Nuvio plugins screen can be mirrored into TmdbConfig's static cache.
      // This must happen before the first TMDB request (Stream/Explore fire on
      // their first build), which is why it lives here.
      final savedTmdbKey = storageService.getString('tmdb_api_key');
      if (savedTmdbKey != null && savedTmdbKey.trim().isNotEmpty) {
        TmdbConfig.setUserApiKey(savedTmdbKey);
        talker.info('Bootstrap: Loaded user TMDB API key from Settings');
      }

      try {
        final prefs = await SharedPreferences.getInstance();
        final savedNuvioKey = prefs.getString('nuvio_tmdb_api_key');
        if (savedNuvioKey != null && savedNuvioKey.trim().isNotEmpty) {
          TmdbConfig.setNuvioApiKey(savedNuvioKey);
          talker.info('Bootstrap: Loaded user TMDB API key from Nuvio');
        }
      } catch (_) {}

      talker.info('Bootstrap: Initialization complete');
    } catch (e, st) {
      talker.handle(e, st, 'Bootstrap: Critical initialization error');
      rethrow;
    }
  }
}
