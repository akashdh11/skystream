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

### 5. Dropped upstream repo scaffolding

Removed `.github/` and `.vscode/`, matching how `video_view`, `flutter_js_ng`
and `flutter_torrent_server` are vendored here — the host repo owns CI.

`test/release_metadata_test.dart` went with them. It asserted on upstream's
pub.dev release process — that the version string matches across README,
CHANGELOG, podspecs and `example/pubspec.lock`, that the podspec author is
`lingjhf`, that the description fits pub.dev's length guidance. None of that
describes package behaviour, and none of it is true or wanted for a vendored
fork that will never be published to pub.dev.

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
