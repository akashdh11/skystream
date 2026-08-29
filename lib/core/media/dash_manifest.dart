/// Redirecting a DASH manifest's segment URLs through the local proxy.
///
/// This deliberately does **not** parse the MPD. Nothing here needs to
/// understand periods, timelines or adaptation logic — VLC already owns all of
/// that and is very good at it. The only job is to substitute the URLs in two
/// attributes so segments arrive via the proxy, which is a text rewrite.
///
/// That matters practically: a live manifest is refreshed every couple of
/// seconds (`minimumUpdatePeriod="PT2S"` on the streams this was built for) and
/// can be 300 KB, so building and re-serialising a DOM on every refresh would
/// be real work to accomplish nothing.
///
/// The one subtlety is that `$Number$`, `$Time$` and `$RepresentationID$` must
/// survive **as literal text** in the rewritten URL. VLC substitutes them
/// before issuing the request, so percent-encoding the dollar signs would leave
/// it asking the proxy for a segment literally named with the token.
library;

/// Matches the two SegmentTemplate attributes that carry segment URLs.
final RegExp _segmentUrlAttribute = RegExp(
  r'(\b(?:initialization|media)\s*=\s*")([^"]+)(")',
);

/// Matches a `<BaseURL>` element, used to resolve relative templates.
final RegExp _baseUrl = RegExp(
  r'<BaseURL[^>]*>\s*([^<\s]+)\s*</BaseURL>',
  caseSensitive: false,
);

/// Placeholder standing in for a `$…$` template token while a URL is resolved.
///
/// [Uri] percent-encodes a dollar sign, which would destroy the token, so the
/// tokens are hidden across the resolve and restored afterwards.
const String _tokenSentinel = 'X0TOKEN0X';

/// Rewrites every segment URL in [manifest] to point at the proxy.
///
/// [proxyUrlFor] receives the absolute upstream URL — still containing its
/// template tokens — and returns the replacement. [isInit] distinguishes the
/// initialization segment, which needs relabelling rather than decryption.
String rewriteDashManifest({
  required String manifest,
  required Uri manifestUrl,
  required String Function(String upstreamUrl, {required bool isInit})
  proxyUrlFor,
}) {
  final declared = _baseUrl.firstMatch(manifest)?.group(1);
  final base = declared == null
      ? manifestUrl
      : _join(manifestUrl, declared.trim());

  return manifest.replaceAllMapped(_segmentUrlAttribute, (m) {
    final attribute = m.group(1)!;
    final value = m.group(2)!;
    final isInit = attribute.contains('initialization');
    final absolute = _restoreTokens(_join(base, value).toString());
    final replacement = proxyUrlFor(absolute, isInit: isInit);
    return '$attribute${_escapeXmlAttribute(replacement)}${m.group(3)}';
  });
}

/// Joins a possibly-relative segment template onto its base, preserving tokens.
Uri _join(Uri base, String reference) {
  final hidden = _hideTokens(reference);
  if (hidden.startsWith('http://') || hidden.startsWith('https://')) {
    return Uri.parse(hidden);
  }
  return base.resolve(hidden);
}

String _hideTokens(String value) => value.replaceAllMapped(
  RegExp(r'\$([^$/]*)\$'),
  (m) => '$_tokenSentinel${m.group(1)}$_tokenSentinel',
);

String _restoreTokens(String value) {
  final parts = value.split(_tokenSentinel);
  if (parts.length < 3) return value;
  final out = StringBuffer(parts.first);
  for (var i = 1; i < parts.length; i += 2) {
    out.write('\$${parts[i]}\$');
    if (i + 1 < parts.length) out.write(parts[i + 1]);
  }
  return out.toString();
}

/// Only these can break an XML attribute value we are writing.
String _escapeXmlAttribute(String value) =>
    value.replaceAll('&', '&amp;').replaceAll('<', '&lt;');
