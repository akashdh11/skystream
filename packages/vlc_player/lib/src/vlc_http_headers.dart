/// Translating HTTP request headers into what libVLC can actually transmit.
///
/// libVLC 3.x has **no general mechanism for per-request HTTP headers**. Its
/// HTTP access module exposes exactly two as options — `http-user-agent` and
/// `http-referrer` — and nothing else. There is no `http-header` option; the
/// name appears in no VLC 3.x build. Passing one produces a libvlccore warning
/// ("unknown option") that `--quiet` suppresses, and the header is dropped.
///
/// This matters because it is silent. A caller can hand over a complete and
/// correct header map, see no error, and watch the server answer 403 because
/// the request went out bare. Everything here exists to make that failure
/// visible and to deliver the two headers that can be delivered.
///
/// For `Cookie`, `Authorization`, `Origin` and everything else, there is no
/// option to translate to. The host application has to solve it above this
/// package — usually by proxying the media through a local server that injects
/// the headers itself. [unsupportedVlcHeaders] tells it when that is needed.
library;

/// Request headers libVLC 3.x can set per media, lower-cased.
///
/// `referrer` is accepted alongside the (misspelled, but canonical) HTTP
/// `Referer` because callers write both and VLC's own option uses the
/// two-r spelling.
const Set<String> kVlcTransmittableHeaders = <String>{
  'user-agent',
  'referer',
  'referrer',
};

/// Converts [headers] into libVLC media options.
///
/// Only the headers in [kVlcTransmittableHeaders] produce output; the rest have
/// no libVLC representation and are reported by [unsupportedVlcHeaders]
/// instead. Blank names and values are skipped, as are values containing CR or
/// LF — an option string is parsed positionally, so an embedded newline would
/// corrupt the ones after it.
///
/// A per-media option overrides the instance-level `--http-user-agent` through
/// VLC's variable inheritance, so a source that carries its own User-Agent wins
/// over the player-wide default while sources that carry none still get it.
List<String> vlcHeaderOptions(Map<String, String> headers) {
  final options = <String>[];
  String? userAgent;
  String? referer;

  for (final entry in headers.entries) {
    final name = entry.key.trim().toLowerCase();
    final value = entry.value;
    if (name.isEmpty || value.isEmpty) continue;
    if (value.contains('\r') || value.contains('\n')) continue;

    switch (name) {
      case 'user-agent':
        userAgent ??= value;
      case 'referer':
      case 'referrer':
        referer ??= value;
    }
  }

  if (userAgent != null) options.add(':http-user-agent=$userAgent');
  if (referer != null) options.add(':http-referrer=$referer');
  return options;
}

/// The names in [headers] that libVLC cannot transmit, in their original case.
///
/// A non-empty result means this media cannot be opened with the identity the
/// caller asked for. Callers that must honour those headers should not hand the
/// URL to VLC directly — proxy it and inject them upstream.
List<String> unsupportedVlcHeaders(Map<String, String> headers) {
  final dropped = <String>[];
  for (final entry in headers.entries) {
    final name = entry.key.trim();
    if (name.isEmpty || entry.value.isEmpty) continue;
    if (!kVlcTransmittableHeaders.contains(name.toLowerCase())) {
      dropped.add(entry.key);
    }
  }
  return dropped;
}
