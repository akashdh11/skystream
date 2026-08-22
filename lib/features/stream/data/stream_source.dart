import 'package:skystream/core/domain/entity/multimedia_item.dart';

/// A stream link resolved from one installed plugin.
class AggregatedStream {
  final String providerId;
  final String providerName;
  final String itemUrl;
  final String episodeUrl;
  final StreamResult stream;
  final MultimediaItem detailedItem;
  final Episode? episode;

  const AggregatedStream({
    required this.providerId,
    required this.providerName,
    required this.itemUrl,
    required this.episodeUrl,
    required this.stream,
    required this.detailedItem,
    this.episode,
  });

  String get sourceLabel => stream.displaySource;

  /// Vertical resolution parsed out of the source label (e.g. "1080p WEB-DL"
  /// -> 1080). Plugins don't expose structured quality, so the label is the
  /// only signal available for sorting best-first.
  static final _resRegex = RegExp(r'(\d{3,4})\s*[pi]\b', caseSensitive: false);
  static final _kRegex = RegExp(r'\b(4k|uhd|2160)\b', caseSensitive: false);
  static final _twoKRegex = RegExp(r'\b(2k|1440)\b', caseSensitive: false);

  int get qualityScore {
    final label = '${stream.source} ${stream.url}';
    if (_kRegex.hasMatch(label)) return 2160;
    if (_twoKRegex.hasMatch(label)) return 1440;
    final match = _resRegex.firstMatch(label);
    if (match != null) return int.tryParse(match.group(1)!) ?? 0;
    return 0;
  }

  /// Short badge shown as the row's headline, e.g. "1080p" or "4K".
  String get qualityLabel {
    final score = qualityScore;
    if (score >= 2160) return '4K';
    if (score >= 1440) return '2K';
    if (score > 0) return '${score}p';
    return stream.source.isEmpty ? 'Source' : stream.source;
  }

  bool get isHdr =>
      RegExp(
        r'\b(hdr10\+?|hdr|dolby\s*vision|dovi|dv)\b',
        caseSensitive: false,
      ).hasMatch('${stream.source} ${stream.url}');

  /// True when the link is an adaptive manifest — these usually carry multiple
  /// renditions, so they're worth surfacing even without a quality tag.
  bool get isAdaptive {
    final u = stream.url.toLowerCase();
    return u.contains('.m3u8') || u.contains('.mpd');
  }

  bool get hasSubtitles => (stream.subtitles?.isNotEmpty ?? false);
}
