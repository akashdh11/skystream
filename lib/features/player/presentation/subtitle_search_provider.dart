import 'dart:io';
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:archive/archive.dart';
import 'package:dio/dio.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;

import '../../../core/network/dio_client_provider.dart';
import '../data/subtitle_providers.dart';
import '../domain/entity/subtitle_model.dart';
import '../../settings/presentation/player_settings_provider.dart';

part 'subtitle_search_provider.g.dart';

// Args + worker for the ZIP-extraction `compute()` call below. Kept at file
// scope because compute() requires a top-level / static target.
class _SubtitleZipArgs {
  final Uint8List bytes;
  final String tempDirPath;
  _SubtitleZipArgs(this.bytes, this.tempDirPath);
}

Future<String?> _extractSubtitleFromZip(_SubtitleZipArgs args) async {
  final archive = ZipDecoder().decodeBytes(args.bytes);
  for (final file in archive) {
    if (file.isFile &&
        (file.name.endsWith('.srt') ||
            file.name.endsWith('.vtt') ||
            file.name.endsWith('.ass'))) {
      final subFile = File(
        p.join(
          args.tempDirPath,
          "sub_${DateTime.now().millisecondsSinceEpoch}_${file.name}",
        ),
      );
      await subFile.writeAsBytes(file.content as List<int>);
      return subFile.path;
    }
  }
  return null;
}

List<int> _decompressGzip(Uint8List bytes) {
  return const GZipDecoder().decodeBytes(bytes);
}

const Map<String, String> subtitleLanguages = {
  'English': 'en',
  'Hindi': 'hi',
  'Bengali': 'bn',
  'Telugu': 'te',
  'Marathi': 'mr',
  'Tamil': 'ta',
  'Gujarati': 'gu',
  'Kannada': 'kn',
  'Malayalam': 'ml',
  'Punjabi': 'pa',
  'Arabic': 'ar',
  'Assamese': 'as',
  'Belarusian': 'be',
  'Bulgarian': 'bg',
  'Czech': 'cs',
  'German': 'de',
  'Greek': 'el',
  'Spanish': 'es',
  'Finnish': 'fi',
  'French': 'fr',
  'Hebrew': 'he',
  'Croatian': 'hr',
  'Hungarian': 'hu',
  'Indonesian': 'id',
  'Italian': 'it',
  'Japanese': 'ja',
  'Korean': 'ko',
  'Latvian': 'lv',
  'Macedonian': 'mk',
  'Dutch': 'nl',
  'Polish': 'pl',
  'Portuguese': 'pt',
  'Romanian': 'ro',
  'Russian': 'ru',
  'Swedish': 'sv',
  'Turkish': 'tr',
  'Ukrainian': 'uk',
  'Urdu': 'ur',
  'Vietnamese': 'vi',
  'Chinese': 'zh',
};

@riverpod
class SubtitleSearch extends _$SubtitleSearch {
  late List<SubtitleProvider> _providers;
  CancelToken? _cancelToken;
  int _activeSearchId = 0;

  @override
  FutureOr<List<OnlineSubtitle>?> build() {
    ref.onDispose(() {
      _cancelToken?.cancel();
    });

    // Watch settings to update providers if they change
    ref.listen(playerSettingsProvider, (previous, next) {
      if (next.hasValue) {
        _initializeProviders();
      }
    });

    _initializeProviders();
    return null;
  }

  void _initializeProviders() {
    final dio = ref.read(dioClientProvider);
    final settings =
        ref.read(playerSettingsProvider).asData?.value ??
        const PlayerSettings();

    _providers = [
      OpenSubtitlesProvider(
        dio,
        username: settings.osUsername,
        password: settings.osPassword,
        apiKey: settings.osApiKey,
      ),
      SubDLProvider(dio, apiKey: settings.subdlApiKey),
      SubSourceProvider(dio, apiKey: settings.subsourceApiKey),
    ];
  }

  Future<void> search({
    required String query,
    String? imdbId,
    int? tmdbId,
    int? season,
    int? episode,
    String? language,
  }) async {
    // 1. Cancel previous search
    _cancelToken?.cancel();
    _cancelToken = CancelToken();

    // 2. Increment search ID to ignore late results from previous calls
    final searchId = ++_activeSearchId;

    if (kDebugMode) {
      print(
        "🔍 [SubtitleSearch] Starting search #$searchId for: $query (IMDB: $imdbId)",
      );
    }
    state = const AsyncLoading();

    final List<OnlineSubtitle> allResults = [];
    final lang = language ?? ref.read(subtitleLanguageProvider);
    int completedProviders = 0;

    for (final provider in _providers) {
      unawaited(
        provider
            .search(
              query: query,
              imdbId: imdbId,
              tmdbId: tmdbId,
              season: season,
              episode: episode,
              language: lang,
              cancelToken: _cancelToken,
            )
            .then((results) {
              if (!ref.mounted || searchId != _activeSearchId) return;

              if (results.isNotEmpty) {
                allResults.addAll(results);
                state = AsyncData(List.from(allResults));
              }
            })
            .catchError((Object e) {
              if (e is DioException && e.type == DioExceptionType.cancel) {
                return;
              }
              if (kDebugMode) debugPrint("${provider.name} search failed: $e");
            })
            .whenComplete(() {
              if (!ref.mounted || searchId != _activeSearchId) return;

              completedProviders++;
              // If all finished and no results found, ensure we transition from loading to empty data
              if (completedProviders == _providers.length &&
                  allResults.isEmpty) {
                state = const AsyncData([]);
              }
            }),
      );
    }
  }

  Future<String?> downloadAndPrepare(OnlineSubtitle subtitle) async {
    _initializeProviders();
    final dio = ref.read(dioClientProvider);
    final provider = _providers.firstWhere((p) => p.name == subtitle.source);

    String? url = subtitle.downloadUrl;
    if (url.isEmpty) {
      if (kDebugMode) {
        print(
          "[SubtitleDownload] No direct URL for '${subtitle.name}' from ${subtitle.source}. Fetching download URL...",
        );
      }
      url = await provider.getDownloadUrl(subtitle) ?? "";
    }

    if (url.isEmpty) {
      if (kDebugMode) {
        print(
          "[SubtitleDownload] ❌ Failed: No download URL could be resolved for '${subtitle.name}' from ${subtitle.source}",
        );
      }
      return null;
    }

    if (kDebugMode) {
      print("[SubtitleDownload] Downloading from ${subtitle.source}: $url");
    }

    try {
      final tempDir = await getTemporaryDirectory();
      final savePath = p.join(
        tempDir.path,
        "temp_sub_${DateTime.now().millisecondsSinceEpoch}",
      );

      // Use provider-specific headers for the download request
      final downloadHeaders = provider.getDownloadHeaders(subtitle);

      final response = await dio.get<List<int>>(
        url,
        options: Options(
          responseType: ResponseType.bytes,
          headers: downloadHeaders,
          receiveTimeout: const Duration(seconds: 30),
        ),
      );

      if (response.data == null || response.data!.isEmpty) {
        if (kDebugMode) {
          print(
            "[SubtitleDownload] ❌ Failed: Empty response body from ${subtitle.source} (HTTP ${response.statusCode})",
          );
        }
        return null;
      }

      final List<int> bytes = response.data!;

      if (kDebugMode) {
        print(
          "[SubtitleDownload] Received ${bytes.length} bytes from ${subtitle.source}",
        );
      }

      // Detect archive format by magic bytes
      if (bytes.length > 4 && bytes[0] == 0x50 && bytes[1] == 0x4B) {
        // ZIP archive (most common for SubDL and SubSource).
        // Decode + extract on a worker isolate so the player UI doesn't
        // freeze while the user is actively watching (audit B12).
        if (kDebugMode) {
          debugPrint("[SubtitleDownload] Detected ZIP archive, extracting...");
        }
        final extractedPath = await compute(
          _extractSubtitleFromZip,
          _SubtitleZipArgs(Uint8List.fromList(bytes), tempDir.path),
        );
        if (extractedPath != null) {
          if (kDebugMode) {
            debugPrint("[SubtitleDownload] ✅ Extracted: $extractedPath");
          }
          return extractedPath;
        }
        if (kDebugMode) {
          debugPrint(
            "[SubtitleDownload] ❌ ZIP contained no .srt/.vtt/.ass files.",
          );
        }
      } else if (bytes.length > 2 && bytes[0] == 0x1F && bytes[1] == 0x8B) {
        // GZIP compressed file — also offloaded to worker isolate.
        if (kDebugMode) {
          debugPrint("[SubtitleDownload] Detected GZIP, decompressing...");
        }
        final decompressed = await compute(
          _decompressGzip,
          Uint8List.fromList(bytes),
        );
        final subFile = File("$savePath.srt");
        await subFile.writeAsBytes(decompressed);
        return subFile.path;
      } else if (bytes.length > 4 &&
          bytes[0] == 0x52 &&
          bytes[1] == 0x61 &&
          bytes[2] == 0x72 &&
          bytes[3] == 0x21) {
        // RAR archive - not supported
        if (kDebugMode) {
          print(
            "[SubtitleDownload] ❌ RAR archive detected but not supported. Source: ${subtitle.source}",
          );
        }
        return null;
      } else {
        // Raw subtitle file (typical for OpenSubtitles CDN links)
        final subFile = File("$savePath.srt");
        await subFile.writeAsBytes(bytes);
        if (kDebugMode) print("[SubtitleDownload] ✅ Saved raw subtitle file");
        return subFile.path;
      }
    } on DioException catch (e) {
      if (kDebugMode) {
        print(
          "[SubtitleDownload] ❌ HTTP Error from ${subtitle.source}: "
          "Status=${e.response?.statusCode}, "
          "Message=${e.message}, "
          "URL=$url",
        );
        if (e.response?.data != null) {
          // Try to read error body if it's text
          try {
            final body = e.response?.data is List<int>
                ? String.fromCharCodes(e.response!.data as List<int>)
                : e.response?.data.toString();
            print(
              "[SubtitleDownload] Response body: ${body?.substring(0, (body.length > 200 ? 200 : body.length))}",
            );
          } catch (_) {}
        }
      }
      return null;
    } catch (e, stack) {
      if (kDebugMode) {
        print(
          "[SubtitleDownload] ❌ Unexpected error from ${subtitle.source}: $e",
        );
        print("[SubtitleDownload] Stack: $stack");
      }
      return null;
    }
    return null;
  }
}

@riverpod
class SubtitleLanguage extends _$SubtitleLanguage {
  @override
  String build() => 'en';

  void set(String lang) => state = lang;
}
