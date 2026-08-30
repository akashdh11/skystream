# Fork notes

Vendored fork of [`lingjhf/vlc_player`](https://github.com/lingjhf/vlc_player).

**Upstream base:** `82b155f` — "fix(pub): expand package description" (2026-06-02, pub `2.1.2`).

Upstream is a single-maintainer project that has been quiet since June 2026, with
open bug reports and an unmerged community fix. We treat this tree as ours: land
changes here, keep this file current, and upstream anything generally useful.

Everything below is additive or a bug fix. No upstream API was removed, so the
package stays usable by any Flutter app, not just this one.

---

## Changes against upstream

### 1. Windows create/dispose UI stalls — upstream PR #5

Cherry-picked [PR #5](https://github.com/lingjhf/vlc_player/pull/5) by
`DaPotatoMan`, which upstream has not merged. Moves heavy Windows VLC
initialisation off the platform-handler path, makes disposal tear VLC down
asynchronously, and guards player lifetime across overlapping create/dispose.

Fixes upstream issue #2 (UI thread stuck on the first player creation).
Touches `windows/vlc_player_plugin.cpp` and `.h` only.

### 2. Apple: unmodelled player states no longer report "not ready"

*Fixes upstream issue #6 — "player events such as playing/buffering/ready not
fired properly" on iOS.*

`stateName` switched on `VLCMediaPlayerState` and mapped everything it did not
recognise to `"idle"`, and `isReadyState("idle")` is `false`. VLCKit 3.x emits
`.esAdded` during normal start-up and whenever an elementary stream appears — a
track switch or an adaptive rendition change — so a *playing* player would
report `isReady == false` in the middle of playback. Any host driving its UI
off `isReady` sees the player drop out and come back.

`stateName` now takes the player rather than the bare state, and for an
unmodelled case derives from the transport: `"idle"` only when no media is
loaded, otherwise `playing`/`opening` from `player.isPlaying`.

Applied identically to `ios/` and `macos/`.

### 3. `isLive` no longer flaps true at the start of every VOD

`isLive` is derived as `isLiveState(state) && duration == 0 && !isSeekable`.
Both of those are trivially true while VLC is still opening a stream, and
`isLiveState` counted `buffering` — so *every* VOD reported `isLive` for its
first frames. Long enough for a host to hide its seek bar and speed control and
then have to put them back.

`buffering` is no longer a live state; `playing` and `paused` remain. By the
time either is reached VLC generally knows the duration.

Applied to `android/`, `ios/` and `macos/`.

### 4. New: typed configuration — `lib/src/vlc_player_config.dart`

Upstream configures libVLC through an untyped `List<String> options`. That is
flexible but pushes every caller into hand-writing VLC flags and re-deriving the
same defaults, and it is where host apps accumulate a pile of magic strings.

Adds `VlcPlayerConfig` with `VlcNetworkConfig`, `VlcDecodingConfig` and
`VlcSubtitleStyle`, each of which compiles to the correct `--…` options:

| Concern | Typed as | Emits |
|---|---|---|
| Buffering | `networkCaching` / `liveCaching` / `fileCaching` | `--network-caching` etc. |
| HTTP identity | `userAgent`, `referer` | `--http-user-agent`, `--http-referrer` |
| Adaptive streams | `adaptiveLogic`, `adaptiveMaxHeight` | `--adaptive-logic`, `--adaptive-maxheight` |
| Hardware decode | `VlcHardwareAcceleration` | `--avcodec-hw=any\|none` |
| Weak-CPU fallback | `VlcDecodeThrift` | `--avcodec-skiploopfilter`, `--avcodec-skip-frame` |
| Subtitle look | `VlcSubtitleStyle` | `--freetype-*`, `--sub-margin` |

`VlcPlayerController` gains an optional `config:`. It is expanded *before* any
raw `options`, so a raw option still wins — the escape hatch is intact and the
existing `options`-only path is unchanged.

Also adds `VlcPlayerCapabilities`, which states the limits a host would
otherwise hard-code at its call sites — notably `maxVolumePercent = 200`
(libVLC amplifies past 100%), and the two honest negatives:
`supportsRuntimeSubtitleStyling = false` (VLC 3.x fixes styling at instance
creation) and `supportsToneMapping = false` (no mpv-`vo_gpu` equivalent).

Covered by `test/vlc_player_config_test.dart`.

### 5. Android `minSdk` lowered 29 → 24

Upstream set `minSdk = 29` in `android/build.gradle.kts` as a bare line in
`defaultConfig` with no comment and nothing requiring it.

It is not a real constraint:

* **libVLC declares `minSdkVersion="17"`** — read from the `libvlc-all:3.7.0`
  AAR manifest, not inferred.
* The plugin's Kotlin contains **no `@RequiresApi`, no `Build.VERSION` check and
  no `SDK_INT` guard anywhere**, and every Android import is API-17-era except
  one: `android.view.PixelCopy` (API 24), used only by `takeSnapshot`.

So the floor the code actually needs is 24 — which is exactly Flutter's default
`minSdkVersion`, so hosts inherit it for free.

This matters beyond tidiness. A host app's effective `minSdk` is the highest
across itself and all its plugins (it is not forced by the app the way
`compileSdk` and `targetSdk` typically are), so 29 silently raised any host to
29 — excluding Android 7, 8 and 9. **Fire OS 7 is Android 9 / API 28**, so
upstream's default quietly dropped a large share of Fire TV devices.

Going below 24 is possible and cheap — guard the single `PixelCopy` call in
`VlcPlayerPlatformView` behind `SDK_INT >= 24` and degrade snapshots — but is
deliberately **not** done here; 24 is Flutter's own floor and going lower means
fighting the toolchain for devices that cannot decode modern codecs anyway.

Verified by reading the AAR manifest and the plugin source. **Not yet verified by
an Android build** at the time of writing. The package is now the host's
only playback engine.

### 6. Dropped upstream repo scaffolding

Removed `.github/` and `.vscode/`, matching how `flutter_js_ng`
and `flutter_torrent_server` are vendored here — the host repo owns CI.

`test/release_metadata_test.dart` went with them. It asserted on upstream's
pub.dev release process — that the version string matches across README,
CHANGELOG, podspecs and `example/pubspec.lock`, that the podspec author is
`lingjhf`, that the description fits pub.dev's length guidance. None of that
describes package behaviour, and none of it is true or wanted for a vendored
fork that will never be published to pub.dev.

### 7. `addSubtitle` before attachment queues instead of throwing

Upstream, `setMedia` may be called before a `VlcPlayer` is mounted — it stores
the source and applies it when the view is attached. `addSubtitle` did not: it
went straight to `_attachedArguments`, which throws

    StateError: The controller is not attached to a VlcPlayer.

That asymmetry is a trap. The natural way to start playback is to set the media
and its side-car subtitles together, before building the widget that shows it,
and only the first of those two calls worked. Every caller would otherwise
reimplement the same "wait until attached" dance.

`addSubtitle` now queues when there is no view and flushes, in order, from both
attach paths (`attach` and `attachTexturePlayer`), right after the pending media
is applied. Setting new media discards subtitles queued for the previous media.
A queued subtitle that fails to load is dropped rather than thrown: the video is
still playable without it, and attachment must not fail because a side-car URI
was bad.

Covered by `subtitles added before attachment are applied in order` and
`new media drops subtitles queued for the old media`.

### 8. HTTP headers now use options libVLC actually has

Upstream converted every entry of a source's header map into a media option:

    media.addOption(":http-header=$name: $value")

**`http-header` is not a libVLC option.** It exists in no VLC 3.x build. I dumped the option-name
string tables of every binary this app ships — `libvlc-all:3.7.0` (the pinned Android AAR),
`MobileVLCKit 3.7.3`, `VLCKit 3.7.3`, and the VLC 3.0.23 desktop core. All four contain
`http-user-agent`, `http-referrer` and `http-forward-cookies`. None contains `http-header`.
libvlccore parses the unknown option, logs `unknown option %s`, and drops it — and the log is
suppressed by the default `--quiet`.

The effect was total and silent: **no per-source HTTP header reached the network on any of the five
platforms.** No Referer, no Cookie, no Authorization, no Origin, and not even a source's own
User-Agent. A caller could pass a complete, correct header map, see no error, and watch the server
answer 403. Nothing in the package or its tests could catch it, because every layer agreed the
header had been handed on.

The translation now happens once, in Dart, in `_sourceArguments()` — the single builder every
`setSource` payload goes through, so all five backends inherit one policy instead of five copies of
it. `lib/src/vlc_http_headers.dart` maps `User-Agent` → `:http-user-agent=` and `Referer`/`Referrer`
→ `:http-referrer=`, skipping blank values and any value containing CR or LF, which would otherwise
corrupt the options after it in the list. Per-media options override the instance-level
`--http-user-agent` through VLC's variable inheritance, so a source carrying its own User-Agent now
wins while sources carrying none still get the configured default. The `:http-header=` emission is
deleted from all five native backends; the raw map is still delivered in the payload for genuinely
platform-specific mechanisms (iOS's `storeCookie:forHost:path:`, for instance) but produces no
options.

`Cookie`, `Authorization`, `Origin` and custom headers have **no libVLC representation at all**.
Pretending otherwise is what caused this, so the package no longer does: `unsupportedVlcHeaders()`
names exactly which headers will not be sent, and a debug build prints them per source. A host app
that must honour them has to proxy the media and inject them upstream — which is what SkyStream now
does through `LocalProxyService`.

Covered by `test/vlc_http_headers_test.dart` and two channel-boundary tests in
`vlc_player_controller_test.dart` that assert the emitted option strings and that nothing containing
`http-header` is ever produced.

---

## Known gaps, not yet addressed

- **Rendering path.** Android/iOS/macOS use `AndroidView`/`UiKitView`/
  `AppKitView` platform views; only Windows and Linux use a Flutter `Texture`.
  Platform views cost more on low-end Android TV hardware. Closing this means
  feeding a Flutter `SurfaceTextureEntry` to `IVLCVout.setVideoSurface` on
  Android; Apple needs `libvlc_video_set_callbacks` into a `CVPixelBuffer`.
  **Measure before building** — this is only worth it if it shows up.
- **No tvOS.** `ios/vlc_player.podspec` is `:ios, '13.0'` against `MobileVLCKit`.
  tvOS needs a separate target against `TVVLCKit`.
- **No DRM.** No ClearKey or Widevine surface. Content behind a licence server
  needs a different engine.
- **Windows fetches the VLC runtime at build time** from `download.videolan.org`
  (`windows/CMakeLists.txt`), so offline and sandboxed CI builds fail.
- **Linux requires system libVLC** (`pkg_check_modules(LIBVLC REQUIRED)`).
- **Android pulls `libvlc-all`** — every ABI, no splits. Filter in the host app.
- Upstream issue #1 (first frame jumps) and #7 (Swift Package Manager) are open
  and unaddressed here.
