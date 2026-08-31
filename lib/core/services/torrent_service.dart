import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_torrent_server/flutter_torrent_server.dart';
import '../utils/torrent_file_parser.dart';
import '../utils/app_utils.dart';
import '../models/torrent_status.dart';

class TorrentService {
  static final TorrentService _instance = TorrentService._internal();
  factory TorrentService() => _instance;
  TorrentService._internal();

  final _server = FlutterTorrentServer();
  String? _serverUrl;
  bool _isStarted = false;
  String? _activeTorrentHash;

  Future<TorrentStatus?> getCurrentStatus() async {
    if (_activeTorrentHash == null || !_isStarted) {
      return null;
    }
    try {
      final statusMap = await _server.getTorrentStatus(_activeTorrentHash!);
      if (statusMap != null) {
        return TorrentStatus.fromMap(statusMap);
      }
    } catch (e) {
      if (kDebugMode) debugPrint("Error fetching status: $e");
    }
    return null;
  }

  Future<void> start() async {
    if (_isStarted) {
      return;
    }
    try {
      final port = await _server.start();
      if (port > 0) {
        _serverUrl = "http://127.0.0.1:$port";
        _isStarted = true;
        if (kDebugMode) debugPrint("Torrent Server started at $_serverUrl");
        await _configureSettings();
      }
    } catch (e) {
      if (kDebugMode) debugPrint("Failed to start torrent server: $e");
    }
  }

  Future<void> _configureSettings() async {
    try {
      // Optimize for streaming (4K/High Bitrate)
      // cacheSize: 64MB (67108864 bytes)
      // readerReadAHead: 95%
      final settings = {
        "cacheSize": 67108864,
        "readerReadAHead": 95,
        "preload": true,
      };

      final response = await http.post(
        Uri.parse("$_serverUrl/settings"),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(settings),
      );

      if (response.statusCode == 200) {
        if (kDebugMode) {
          debugPrint("TorrServer settings configured for streaming.");
        }
      }
    } catch (e) {
      if (kDebugMode) debugPrint("Failed to configure TorrServer settings: $e");
    }
  }

  Future<void> stop() async {
    try {
      await _server.stop();
    } catch (e) {
      if (kDebugMode) debugPrint("Error stopping torrent server: $e");
    } finally {
      _isStarted = false;
      _serverUrl = null;
      _activeTorrentHash = null;
    }
  }

  Future<String?> getStreamUrl(String magnetLink) async {
    if (!_isStarted) {
      await start();
    }
    if (_serverUrl == null) {
      return null;
    }

    try {
      final String linkToAdd = await _prepareMagnetLink(magnetLink);

      // Add Torrent
      final hash = await _server.addTorrent(linkToAdd);
      if (hash == null) {
        throw Exception("Failed to add torrent");
      }
      _activeTorrentHash = hash;

      // Poll for Status to get Filename and File Index
      final fileInfo = await _pollForMetadata(hash);
      if (fileInfo == null) {
        throw Exception("Timed out waiting for torrent metadata");
      }

      final int fileIndex = fileInfo['index'] as int;

      // Construct URL
      // Try to fetch from playlist first
      final playlistStreamUrl = await _fetchPlaylistUrl(hash, fileIndex);
      if (playlistStreamUrl != null) {
        return playlistStreamUrl;
      }

      // Fallback: Use "Simplified" format
      return "$_serverUrl/stream?link=$hash&index=$fileIndex&play";
    } catch (e) {
      if (kDebugMode) debugPrint("Error generating stream URL: $e");
      return null;
    }
  }

  Future<String> _prepareMagnetLink(String link) async {
    if (!link.startsWith("magnet:") &&
        !link.startsWith("http") &&
        (AppUtils.isLocalFile(link) || link.contains(RegExp(r'\.torrent$')))) {
      try {
        return await TorrentFileParser.getMagnetLink(link);
      } catch (e) {
        throw Exception("Failed to parse torrent file: $e");
      }
    }
    return link;
  }

  Future<Map<String, dynamic>?> _pollForMetadata(String hash) async {
    int attempts = 0;
    while (attempts < 120) {
      await Future<void>.delayed(const Duration(seconds: 1));
      final status = await _server.getTorrentStatus(hash);

      if (status != null && status['file_stats'] is List) {
        final fileStats = status['file_stats'] as List;
        if (fileStats.isNotEmpty) {
          return _findSequentialVideoFile(fileStats);
        }
      }
      attempts++;
    }
    return null;
  }

  Map<String, dynamic> _findSequentialVideoFile(List<dynamic> fileStats) {
    final videoExtensions = ['.mp4', '.mkv', '.avi', '.mov', '.webm'];
    final videoFiles = <Map<dynamic, dynamic>>[];

    for (final f in fileStats) {
      if (f is Map) {
        final path = f['path']?.toString() ?? "";
        if (path.isNotEmpty) {
          final lowerPath = path.toLowerCase();
          if (videoExtensions.any((ext) => lowerPath.endsWith(ext))) {
            videoFiles.add(f);
          }
        }
      }
    }

    if (videoFiles.isNotEmpty) {
      // Sort alphabetically to find the "first" file in sequence (e.g. S01E01)
      videoFiles.sort(
        (a, b) => (a['path'] as String).compareTo(b['path'] as String),
      );

      final selectedFile = videoFiles.first;
      int fileIndex = 0;
      if (selectedFile['id'] != null) {
        fileIndex = (selectedFile['id'] as num).toInt();
      }
      if (kDebugMode) {
        debugPrint(
          "Auto-selected first video file: ${selectedFile['path']} (Index: $fileIndex)",
        );
      }
      return {'index': fileIndex, 'path': selectedFile['path']};
    }

    // Fallback to largest file if no video extension matches (e.g. strict naming)
    return _findLargestFile(fileStats);
  }

  Map<String, dynamic> _findLargestFile(List<dynamic> fileStats) {
    Map<dynamic, dynamic>? largestFile;
    int maxLen = -1;
    int largestIndex = 0;

    for (int i = 0; i < fileStats.length; i++) {
      final f = fileStats[i];
      if (f is Map) {
        final path = f['path']?.toString() ?? "";
        if (path.isNotEmpty) {
          final len = (f['length'] as num?)?.toInt() ?? 0;
          if (len > maxLen) {
            maxLen = len;
            largestFile = f;
            largestIndex = i;
          }
        }
      }
    }

    if (largestFile != null) {
      int fileIndex = largestIndex;
      if (largestFile['id'] != null) {
        fileIndex = (largestFile['id'] as num).toInt();
      }
      if (kDebugMode) {
        debugPrint(
          "Fallback to largest file: ${largestFile['path']} (Index: $fileIndex)",
        );
      }
      return {'index': fileIndex, 'path': largestFile['path']};
    }

    return {'index': 0, 'path': 'Unknown'};
  }

  Future<String?> _fetchPlaylistUrl(String hash, int index) async {
    try {
      final playlistUrl = "$_serverUrl/playlist?link=$hash";
      final plResponse = await http.get(Uri.parse(playlistUrl));

      if (plResponse.statusCode == 200) {
        final lines = plResponse.body.split('\n');
        int currentIndex = 0;
        for (var line in lines) {
          line = line.trim();
          if (line.isNotEmpty && !line.startsWith('#')) {
            if (currentIndex == index) {
              String targetUrl = line;
              if (!targetUrl.startsWith('http')) {
                targetUrl = targetUrl.startsWith('/')
                    ? "$_serverUrl$targetUrl"
                    : "$_serverUrl/$targetUrl";
              }
              return targetUrl;
            }
            currentIndex++;
          }
        }
      }
    } catch (e) {
      if (kDebugMode) debugPrint("Failed to fetch playlist: $e");
    }
    return null;
  }

  Future<String?> getStreamUrlForFileIndex(int index) async {
    if (_serverUrl == null || _activeTorrentHash == null) {
      return null;
    }

    // Use "Simplified" format for maximum compatibility
    final streamUrl =
        "$_serverUrl/stream?link=$_activeTorrentHash&index=$index&play";
    if (kDebugMode) {
      debugPrint("Generated Stream URL for Index $index: $streamUrl");
    }
    return streamUrl;
  }
}
