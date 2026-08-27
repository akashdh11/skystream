/// Stream + subtitle objects returned by an add-on's `/stream` resource.
library;

import '../../utils/file_size_formatter.dart';

class AddonSubtitleTrack {
  final String id;
  final String url;
  final String lang;
  final String addonName;

  const AddonSubtitleTrack({
    required this.id,
    required this.url,
    required this.lang,
    this.addonName = '',
  });

  static AddonSubtitleTrack? fromJson(
    Map<String, dynamic> json, {
    required String addonName,
    required int index,
  }) {
    final url = (json['url'] as String?)?.trim() ?? '';
    if (!url.startsWith('http')) return null;
    final lang = ((json['lang'] as String?) ?? 'en').trim();
    return AddonSubtitleTrack(
      id: (json['id'] as String?) ?? '$addonName-$lang-$index',
      url: url,
      lang: lang.isEmpty ? 'en' : lang,
      addonName: addonName,
    );
  }

  String get label => prettyLanguage(lang);

  static String prettyLanguage(String code) {
    const names = <String, String>{
      'en': 'English',
      'eng': 'English',
      'es': 'Spanish',
      'spa': 'Spanish',
      'fr': 'French',
      'fre': 'French',
      'fra': 'French',
      'de': 'German',
      'ger': 'German',
      'deu': 'German',
      'it': 'Italian',
      'ita': 'Italian',
      'pt': 'Portuguese',
      'por': 'Portuguese',
      'ru': 'Russian',
      'rus': 'Russian',
      'ar': 'Arabic',
      'ara': 'Arabic',
      'hi': 'Hindi',
      'hin': 'Hindi',
      'ur': 'Urdu',
      'urd': 'Urdu',
      'bn': 'Bengali',
      'ben': 'Bengali',
      'ta': 'Tamil',
      'tam': 'Tamil',
      'te': 'Telugu',
      'tel': 'Telugu',
      'tr': 'Turkish',
      'tur': 'Turkish',
      'ja': 'Japanese',
      'jpn': 'Japanese',
      'ko': 'Korean',
      'kor': 'Korean',
      'zh': 'Chinese',
      'chi': 'Chinese',
      'zho': 'Chinese',
      'nl': 'Dutch',
      'dut': 'Dutch',
      'nld': 'Dutch',
      'pl': 'Polish',
      'pol': 'Polish',
      'sv': 'Swedish',
      'swe': 'Swedish',
      'fa': 'Persian',
      'per': 'Persian',
      'fas': 'Persian',
      'id': 'Indonesian',
      'ind': 'Indonesian',
      'vi': 'Vietnamese',
      'vie': 'Vietnamese',
      'th': 'Thai',
      'tha': 'Thai',
      'uk': 'Ukrainian',
      'ukr': 'Ukrainian',
      'el': 'Greek',
      'gre': 'Greek',
      'ell': 'Greek',
      'he': 'Hebrew',
      'heb': 'Hebrew',
      'cs': 'Czech',
      'cze': 'Czech',
      'ces': 'Czech',
      'ro': 'Romanian',
      'rum': 'Romanian',
      'ron': 'Romanian',
      'hu': 'Hungarian',
      'hun': 'Hungarian',
    };
    final key = code.trim().toLowerCase();
    final match = names[key];
    if (match != null) return match;
    if (key.isEmpty) return 'Unknown';
    return key[0].toUpperCase() + key.substring(1);
  }
}

enum AddonStreamKind { direct, torrent, youtube, external, unknown }

/// One playable result from an add-on.
class AddonStreamSource {
  final String addonId;
  final String addonName;

  final String? url;
  final String? infoHash;
  final int? fileIdx;
  final String? ytId;
  final String? externalUrl;

  final String? name;
  final String? title;
  final String? description;

  /// Torrent trackers advertised by the add-on (`tracker:udp://…`).
  final List<String> sources;

  final Map<String, String>? proxyHeaders;
  final String? bingeGroup;
  final int? videoSize;
  final String? filename;
  final List<AddonSubtitleTrack> subtitles;

  const AddonStreamSource({
    required this.addonId,
    required this.addonName,
    this.url,
    this.infoHash,
    this.fileIdx,
    this.ytId,
    this.externalUrl,
    this.name,
    this.title,
    this.description,
    this.sources = const [],
    this.proxyHeaders,
    this.bingeGroup,
    this.videoSize,
    this.filename,
    this.subtitles = const [],
  });

  factory AddonStreamSource.fromJson(
    Map<String, dynamic> json, {
    required String addonId,
    required String addonName,
  }) {
    final rawHints = json['behaviorHints'];
    final hints = rawHints is Map
        ? Map<String, dynamic>.from(rawHints)
        : <String, dynamic>{};

    Map<String, String>? headers;
    final proxy = hints['proxyHeaders'];
    if (proxy is Map) {
      final request = proxy['request'];
      if (request is Map) {
        final map = <String, String>{};
        request.forEach((key, value) {
          if (key is String && value != null) map[key] = value.toString();
        });
        if (map.isNotEmpty) headers = map;
      }
    }

    final subtitles = <AddonSubtitleTrack>[];
    final rawSubs = json['subtitles'];
    if (rawSubs is List) {
      for (var i = 0; i < rawSubs.length; i++) {
        final entry = rawSubs[i];
        if (entry is Map) {
          final sub = AddonSubtitleTrack.fromJson(
            Map<String, dynamic>.from(entry),
            addonName: addonName,
            index: i,
          );
          if (sub != null) subtitles.add(sub);
        }
      }
    }

    final sources = <String>[];
    final rawSources = json['sources'];
    if (rawSources is List) {
      for (final entry in rawSources) {
        if (entry is String && entry.isNotEmpty) sources.add(entry);
      }
    }

    return AddonStreamSource(
      addonId: addonId,
      addonName: addonName,
      // Direct links occasionally hide inside behaviorHints (see ARVIO).
      url: _firstHttpUrl([json['url'], hints['directUrl'], hints['url']]),
      infoHash: (json['infoHash'] as String?)?.toLowerCase(),
      fileIdx: (json['fileIdx'] as num?)?.toInt(),
      ytId: json['ytId'] as String?,
      externalUrl: _firstHttpUrl([json['externalUrl'], hints['externalUrl']]),
      name: json['name'] as String?,
      title: json['title'] as String?,
      description: json['description'] as String?,
      sources: sources,
      proxyHeaders: headers,
      bingeGroup: hints['bingeGroup'] as String?,
      videoSize: (hints['videoSize'] as num?)?.toInt(),
      filename: hints['filename'] as String?,
      subtitles: subtitles,
    );
  }

  static String? _firstHttpUrl(List<dynamic> candidates) {
    for (final candidate in candidates) {
      final value = candidate is String ? candidate.trim() : '';
      if (value.isEmpty) continue;
      if (value.startsWith('//')) return 'https:$value';
      if (value.startsWith('http://') || value.startsWith('https://')) {
        return value;
      }
    }
    return null;
  }

  AddonStreamKind get kind {
    if ((infoHash ?? '').isNotEmpty) return AddonStreamKind.torrent;
    if ((url ?? '').isNotEmpty) return AddonStreamKind.direct;
    if ((ytId ?? '').isNotEmpty) return AddonStreamKind.youtube;
    if ((externalUrl ?? '').isNotEmpty) return AddonStreamKind.external;
    return AddonStreamKind.unknown;
  }

  bool get isTorrent => kind == AddonStreamKind.torrent;
  bool get isDirect => kind == AddonStreamKind.direct;
  bool get isPlayable => isTorrent || isDirect;

  /// Deep links into a streaming service or YouTube (WatchHub, JustWatch-style
  /// add-ons). They can't be played in-app, but they must still *do* something
  /// when tapped — opening the service is the whole point of those add-ons.
  bool get isExternal =>
      kind == AddonStreamKind.external || kind == AddonStreamKind.youtube;

  String? get launchUrl => switch (kind) {
    AddonStreamKind.external => externalUrl,
    AddonStreamKind.youtube => 'https://www.youtube.com/watch?v=$ytId',
    _ => null,
  };

  String get _text =>
      [name ?? '', title ?? '', description ?? '', filename ?? ''].join(' ');

  static final RegExp _res = RegExp(
    r'(\d{3,4})\s*[pi]\b',
    caseSensitive: false,
  );
  static final RegExp _uhd = RegExp(
    r'\b(4k|uhd|2160p?)\b',
    caseSensitive: false,
  );
  static final RegExp _qhd = RegExp(r'\b(2k|1440p?)\b', caseSensitive: false);
  static final RegExp _hdr = RegExp(
    r'\b(hdr10\+?|hdr|dolby\s*vision|dovi|dv)\b',
    caseSensitive: false,
  );
  static final RegExp _cam = RegExp(
    r'\b(cam|camrip|hdcam|telesync|hdts|\bts\b|screener|scr)\b',
    caseSensitive: false,
  );
  static final RegExp _seeders = RegExp(r'(?:👤|seeders?[:\s]*)\s*(\d+)');
  static final RegExp _size = RegExp(
    r'(\d+(?:[.,]\d+)?)\s*(gb|mb|gib|mib)\b',
    caseSensitive: false,
  );

  int get qualityScore {
    if (_uhd.hasMatch(_text)) return 2160;
    if (_qhd.hasMatch(_text)) return 1440;
    final match = _res.firstMatch(_text);
    return match == null ? 0 : (int.tryParse(match.group(1)!) ?? 0);
  }

  String get qualityLabel {
    final score = qualityScore;
    if (score >= 2160) return '4K';
    if (score >= 1440) return '2K';
    if (score > 0) return '${score}p';
    if (isCam) return 'CAM';
    return isTorrent ? 'Torrent' : 'Auto';
  }

  bool get isHdr => _hdr.hasMatch(_text);
  bool get isCam => _cam.hasMatch(_text);
  bool get isCachedDebrid => RegExp(
    r'\[(rd|pm|ad|dl|oc|tb|ed)\+\]',
    caseSensitive: false,
  ).hasMatch(_text);

  int? get seeders {
    final match = _seeders.firstMatch(_text);
    return match == null ? null : int.tryParse(match.group(1)!);
  }

  int? get sizeBytes {
    if (videoSize != null && videoSize! > 0) return videoSize;
    final match = _size.firstMatch(_text);
    if (match == null) return null;
    final value = double.tryParse(match.group(1)!.replaceAll(',', '.'));
    if (value == null) return null;
    final unit = match.group(2)!.toLowerCase();
    final multiplier = unit.startsWith('g') ? 1024 * 1024 * 1024 : 1024 * 1024;
    return (value * multiplier).round();
  }

  String? get sizeLabel {
    final bytes = sizeBytes;
    if (bytes == null || bytes <= 0) return null;
    return formatFileSize(bytes, fractionDigits: 1);
  }

  List<String> get trackers => [
    for (final source in sources)
      if (source.startsWith('tracker:')) source.substring('tracker:'.length),
  ];

  String? get magnetUri {
    final hash = infoHash;
    if (hash == null || hash.isEmpty) return null;
    final buffer = StringBuffer('magnet:?xt=urn:btih:$hash');
    final display = filename ?? title ?? name;
    if (display != null && display.trim().isNotEmpty) {
      buffer.write('&dn=${Uri.encodeComponent(display.trim())}');
    }
    for (final tracker in trackers) {
      buffer.write('&tr=${Uri.encodeComponent(tracker)}');
    }
    return buffer.toString();
  }

  /// Headline shown in the sources list.
  String get headline {
    final label = (name ?? '').trim().replaceAll('\n', ' ');
    return label.isEmpty ? addonName : label;
  }

  /// Secondary line: whatever descriptive text the add-on provided.
  String get subtitleLine {
    final text = (title ?? description ?? '').trim();
    if (text.isNotEmpty) return text.replaceAll('\n', ' · ');
    return filename ?? addonName;
  }

  /// De-dup key, mirroring ARVIO's.
  String get dedupeKey => [
    addonId,
    url ?? '',
    infoHash ?? '',
    fileIdx?.toString() ?? '',
    name ?? '',
    description ?? title ?? '',
  ].join('|');

  /// Ranking score.
  ///
  /// Resolution leads, because SkyStream streams torrents natively through the
  /// bundled torrent server — unlike a browser client, a 4K torrent is not
  /// second-class here. Direct links still get a head start for instant
  /// playback, cached debrid links more so, and CAM rips are buried.
  int get score {
    var value = 0;
    if (isCachedDebrid) value += 70;
    if (isDirect) value += 45;

    final quality = qualityScore;
    if (quality >= 2160) {
      value += 140;
    } else if (quality >= 1440) {
      value += 110;
    } else if (quality >= 1080) {
      value += 85;
    } else if (quality >= 720) {
      value += 45;
    }

    if (isHdr) value += 12;
    if (isCam) value -= 150;

    final seeds = seeders;
    if (seeds != null) value += (seeds.clamp(0, 60) / 2).round();

    final bytes = sizeBytes;
    if (bytes != null) {
      value += (bytes / (1024 * 1024 * 1024)).clamp(0, 20).round();
    }
    return value;
  }
}
