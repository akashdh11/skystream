/// Shared HTTP defaults for the app's network + playback layers.
///
/// The single most important value here is [kDefaultBrowserUserAgent]. When a
/// plugin resolves a stream it usually sends a real browser User-Agent, and
/// many CDNs / origin servers tie the signed playback URL to that UA (or
/// simply 403 any non-browser UA). If the *player* then fetches the stream
/// with the engine's built-in UA — or the resolver fetches with Dio's
/// default `Dio/xx` — the origin sees a different, non-browser identity and
/// rejects playback even though resolution succeeded.
///
/// Worse, an engine's default UA differs per platform build, so the same
/// stream can play on one desktop OS and 403 on another. Forcing one
/// consistent, real
/// browser UA across resolve + playback removes that entire class of
/// cross-platform divergence.
library;

/// Current-ish desktop Chrome UA. Picked because it's the least likely to be
/// filtered by CDNs and matches what most scraping plugins already send.
const String kDefaultBrowserUserAgent =
    'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 '
    '(KHTML, like Gecko) Chrome/124.0.0.0 Safari/537.36';
