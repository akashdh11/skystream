# Player Migration Plan

Status: **planning**. Branch: `player-vlc-migration`.

This plan does **not** start by migrating. The first phases fix app-side defects and restore
structure, because the evidence says most of the instability is ours, not the engine's. The
engine decision comes after we can measure.

---

## 1. Why

One 5,249-line Riverpod `Notifier`
([player_controller.dart](../lib/features/player/presentation/player_controller.dart)) drives two
engines:

- **media_kit** (libmpv) — default and VOD.
- **video_view** (ExoPlayer / AVPlayer), vendored at `packages/video_view` — live only.

The cost, measured:

| | |
|---|---|
| `useExoPlayer` references | **75** across 8 files (44 in the controller) |
| `_videoViewController` references | **80** (71 in the controller) |
| `setProperty` call sites | **77** |
| distinct libmpv properties | **51** — 44 literal (17 `sub-*`) + 7 HDR written via `trySet` (`:5068`) |
| Controller / screen size | **5,249 / 924 lines** |

> Counts as of `main` @ `637b7c2`. Two caveats for anyone re-deriving them:
> `player_side_panel.dart:337` embeds a literal NUL in `'${s.source}\x00${s.url}'`, so `file`
> reports that 1,937-line source as `data` and **plain `grep` silently skips it** — use `grep -a`.
> And two properties are set by multi-line calls (`:4374`, `:5021`), so a single-line grep
> undercounts.

Engine selection ([player_controller.dart:452-476](../lib/features/player/presentation/player_controller.dart#L452))
is narrower than it feels: video_view runs only when a controller exists **and** not Linux **and**
the stream is live — then falls back to media_kit for DASH on macOS/iOS/Windows, and for DRM off
Android. We carry an entire second engine for a small slice of content.

### What the branch history proves

The repo already ran this experiment. Player size across branches:

| Date | Branch | Controller | Screen | Engines | `useExoPlayer` |
|---|---|---|---|---|---|
| 2026-01-24 | `tmdb_integration` | — | 975 | media_kit | 0 |
| 2026-03-21 | `feat/download` | 1,277 | 460 | media_kit | 0 |
| 2026-04-04 | `feat/ext_subs` | 1,503 | 456 | media_kit | 0 |
| **2026-04-05** | **`video_view`** | **1,796** | 494 | **mk + vv** | **9** |
| 2026-04-19 | `code-optimization` | 3,378 | 475 | mk + vv | 35 |
| 2026-05-03 | `search_filters` | 3,629 | 493 | mk + vv | 35 |
| **2026-05-03** | **`fvp_test`** | **2,714** | **396** | **fvp only** | **0** |
| 2026-05-30 | `video_player_dpad` | 4,564 | 721 | mk + vv | 39 |
| 2026-08-22 | `main` | 5,249 | 924 | mk + vv | 44 |

Three conclusions:

1. **Extracting the controller from the screen worked.** January had no controller; 975 lines of
   logic lived in the screen. By March it was a clean 1,277 / 460 split.
2. **2026-04-05 is the inflection point.** video_view lands at 1,796 lines and 9 branches. Four
   months later: 5,249 lines and 44 branches. +192% on the controller. Nothing else in that window
   explains the growth.
3. **`fvp_test` is a control group.** Branched from `search_filters`, same day, one variable
   changed — both engines swapped for a single `fvp: ^0.36.2`. Result: **−1,923 lines deleted,
   +627 added**; controller 2,714 vs 3,629; screen 396 vs 493; **zero** engine branches.

`fvp_test` also had a **101-line `player_subtitle_manager.dart`** holding `setSubtitleDelay`,
`applySubtitleSettings`, `effectiveExternalSubtitles`, `loadExternalSubtitleFile`. **`main` does
not have that file** — the concern was reabsorbed into the monolith.

> **Caveat, and it matters:** `fvp_test` proves *single-engine collapses the complexity*. It does
> **not** prove VLC works. It ran on fvp/libmdk. Keep those claims separate.

### Which branch is the base? — settled: `main`

`fvp_test` is a test spike, not a candidate base. Every branch was measured against `main`:

| Branch | Date | Commits ahead of merge-base | Commits behind `main` | Non-player files diverged |
|---|---|---|---|---|
| `fvp_test` | 2026-05-03 | **1** | 339 | 595 |
| `media_kit_test` | 2026-05-03 | **1** | 339 | 595 |
| `search_filters` | 2026-05-03 | 0 | 337 | 593 |
| `video_player_dpad` | 2026-05-30 | 0 | 256 | 505 |
| `main-backup` | 2026-05-28 | 0 | 268 | 510 |
| `tv-dpad-navigation` | 2026-05-26 | 0 | 278 | 512 |
| `code-optimization` | 2026-04-19 | 0 | 394 | 617 |
| `video_view` | 2026-04-05 | 0 | 482 | 747 |
| `feat/ext_subs` | 2026-04-04 | 0 | 484 | 899 |

**Every branch but two is 0 commits ahead** — they are historical snapshots of `main`'s own history
and contain nothing `main` lacks. Only `fvp_test` and `media_kit_test` hold unique work, one commit
each:

- `media_kit_test` @ `98b32de` — despite the name, this is plugin-engine work (`js_engine.dart`,
  `js_engine_worker.dart`, `js_unpacker.dart`), not a player experiment. **Already on `main`**
  (`js_unpacker.dart` is present). Nothing to take.
- `fvp_test` @ `b8f41eb` — the single-engine spike, 16 files, +739 / −1,853.

**`b8f41eb` is not cherry-pickable.** Applied to `main` it conflicts in **11 of 16 files**,
including *every* player file — `player_controller.dart`, `player_screen.dart`,
`player_subtitle_manager.dart` (modify/delete), `player_control_components.dart`,
`player_osd_overlay.dart`, `player_stream_widgets.dart`, `skystream_player_controls.dart` — plus
`main.dart`, `pubspec.yaml` and both lockfiles. It deletes code that `main` has since rewritten
twice over. Resolving those conflicts is not cherry-picking; it is reimplementing by hand with the
extra risk of a stale diff pulling old code back in.

Going the other way is worse: rebasing `fvp_test` forward means carrying **339 commits and 595
non-player files** of unrelated work.

**Conclusion.** The base is `main`. There is no competing branch and no patch to cherry-pick.
`fvp_test` is a **reference implementation** — read `b8f41eb` for its *shape* (the 26-line
`selectSubtitleTrack`, the 101-line `player_subtitle_manager.dart`) and reimplement that shape on
`main`. Do not merge it.

---

## 2. Principles

These are the owner's constraints, restated as rules this plan can be checked against.

1. **No manual handling where the engine already does the job.** The engine owns track state; we
   do not mirror it in Dart.
2. **Basic first, phase by phase.** A phase that grows gets its scope cut, not its corners.
3. **Dropping features is a valid outcome.** Every phase names what it deliberately does not carry.
4. **Simple and clean over clever.** Prefer deleting a layer to adding one. No abstraction lands
   without a concrete second implementation that needs it.
5. **UI performance and TV D-pad are acceptance criteria, not follow-ups.** Every phase that
   touches the player UI states its D-pad check.

---

## 3. What we are deliberately NOT carrying over

| Feature | Where it lives now | Decision | Why |
|---|---|---|---|
| HDR mode, tone-map curve, target peak, compute peak, inverse tone mapping | `player_controller.dart` `_applyHdrProperties`; settings in `settings_screen.dart` | **Drop on migration** | These are libmpv `vo_gpu` properties. libVLC has no equivalent. Merged very recently in PR #91 — dropping them weeks after shipping is bad, so they stay while media_kit is the engine and are removed with it, not before. |
| Subtitle **rendering** | media_kit's own `SubtitleView` (`player_screen.dart:739`), configured at `:783`/`:917` | **Replaced by the engine, with loss** | Corrected — an earlier draft of this plan claimed the app renders its own subtitles. It does not. `skystream_subtitle_view.dart` (620 lines) has **zero call sites in `lib/`** and has never rendered a frame. VOD subtitles come from media_kit's `SubtitleView`, live from ExoPlayer's `SubtitlePainter`. Both die with their engines. VLC **burns subtitles into the video surface** and exposes no cue-text stream, so there is nothing to render app-side. See the note below the table. |
| Subtitle **styling** via 17 `sub-*` properties | `applySubtitleSettings`, `subtitle_appearance_dialog.dart` (1,816 lines) | **Reduced to construction-time** | `VlcPlayerCapabilities.supportsRuntimeSubtitleStyling` is `false`: VLC 3.x fixes styling when the instance is created. Styling moves to `VlcSubtitleStyle` at construction; changing it means recreating the player. Most of the appearance dialog loses its live preview. |
| Volume boost above 100% | `supportsVolumeBoost` (:276) | **Keep** | Free — `setVolume` clamps 0–200 in `vlc_player`. |
| Playback speed above 2× | `maxPlaybackSpeed` (:275) | **Keep, unify** | The 2.0 vs 3.0 split exists only because of the engine divergence. One engine, one limit. |
| Per-stream health pre-flight `HEAD`/ranged-`GET` | `_isStreamCandidateHealthy` (:2988) | **Drop** | Uses a different HTTP identity than playback, so it fails good sources. Let playback fail and use the existing failover. |
| `_isLiveStream` 15-pattern URL guesser | `player_controller.dart:4726-4770` | **Demote to a hint** | Both candidate engines report `isLive` themselves. Keep the URL check only as a pre-open guess for buffer sizing. |
| The seven capability getters | :273-280 | **Five delete, two do not** | Corrected. `supportsPlaybackSpeed => !isLive` (:274) has no `useExoPlayer` and survives unchanged. `canSeek => !useExoPlayer \|\| isSeekable` (:273) does not become a constant — it becomes the **runtime** field `isSeekable`, which on VLC flips false during open and buffering. That has a TV consequence: `_scrubFocusNode` is focusable only when `isTv && canSeek` (`player_stream_widgets.dart:242`), so the scrubber's focus node would appear and vanish mid-session, and can be destroyed while holding focus. Keep it unconditionally focusable on TV and no-op the seek instead. |
| Widevine / PlayReady | — | **Not applicable** | There is none. `_extractKeysFromLicenseUrl` (:4671-4715) parses a W3C ClearKey JWK; there is no CDM code in `lib/`. DRM is ClearKey only. |
| `pendingVideoViewSubtitleIdsBeforeReload`, `selectNewestVideoViewSubtitleAfterReload` | :425-426, :1145-1159 | **Delete** | Exists purely to survive a video_view reload. Dies with the second engine. |
| `_videoViewSupportsMergedExternalSubtitles` | :494 | **Delete** | A platform check for one engine's quirk. |

### The subtitle problem, stated plainly

This is the largest single unknown in the migration and the plan should not pretend otherwise.

Today subtitles are rendered by the **engine's** Flutter-side widget: media_kit's `SubtitleView`
receives decoded cue text from libmpv and the app styles it with 17 `sub-*` properties and a
1,816-line appearance dialog. That is why styling works today.

`vlc_player` exposes **no cue text** on any of its five backends — `VlcPlayerValue` carries
`subtitleDelay` and nothing else. VLC renders subtitles by drawing them into the video surface.
So on VLC:

* subtitle **styling** is construction-time only (`VlcSubtitleStyle` → `--freetype-*`);
* the "lift subtitles above the chrome when controls are visible" behaviour
  (`player_screen.dart:705-750`) is **not implementable**;
* most of `subtitle_appearance_dialog.dart` becomes dead or preview-less.

**DECIDED: raw engine rendering.** VLC composites subtitles into the video surface; we accept that
and do not try to reproduce today's behaviour. Rationale: the migration's whole justification is
stability, and the two alternatives — recreating the player on every style change, or adding a
cue-text stream to the fork — both add risk to the thing we are trying to de-risk.

What this costs, stated so nobody is surprised later:

* Styling is **construction-time only**, applied on next play rather than live. Settings map onto
  `VlcSubtitleStyle` → `--freetype-*`: font, size, colour, opacity, bold, outline colour/thickness,
  shadow colour/distance, background colour/opacity, `--sub-margin`. Anything outside that
  vocabulary goes.
* The **chrome lift** (`player_screen.dart:722-735`, which animates `bottomOffset` off
  `_controlsVisible`) is gone. Text baked into the frame cannot move.
* `subtitle_appearance_dialog.dart` loses its live preview and most of its options.
* `sub-delay` survives — `setSubtitleDelay` is a real runtime API on the engine.

Rejected, and why:

* **Recreate the player on style change** — keeps full styling, but every tweak is a visible reload,
  and `_platformViewKey` (`vlc_player.dart:189`) already forces a LibVLC rebuild on fit change, so
  this leans on a path that is known-janky.
* **Render app-side in Flutter** — would preserve today's behaviour exactly, and is genuinely
  feasible **for external subtitle files** (the app already parses SRT at
  `subtitle_sync_dialog.dart:30`). It is not feasible for **embedded** container tracks: libVLC 3.x
  exposes no decoded cue text to the host (UNVERIFIED but consistent with its burn-in design). A
  hybrid would give two visibly different subtitle experiences in one app. Left as a possible
  follow-up for external subs only; it blocks nothing.

`skystream_subtitle_view.dart` is **dead code**, not a head start. It is deleted in Phase 1.

---

## 4. Architecture

Target, in the fewest layers that work:

- **One engine.** No `PlaybackEngine` interface. An interface is justified only by a second
  implementation; during migration the flag selects between old and new at the *screen* level, not
  behind an abstraction that both must satisfy. When the old engine is deleted, there is nothing
  left to abstract.
- **The screen owns the engine controller.** Today `PlayerController` is `ref.keepAlive()`'d while
  `_PlayerScreenState` owns and disposes the actual `Player` — which is why instance fields survive
  across episodes and auto-select fires after teardown. The engine controller's lifetime must match
  the screen's.
- **Session state is a value, not fields.** Everything reset per `load()` lives in one object that
  is replaced wholesale, so nothing can leak between episodes by omission.
- **High-frequency state bypasses Riverpod.** `VlcPlayerValue` is already a `ValueNotifier`. Position
  and buffering drive `ValueListenableBuilder`s directly; the Riverpod state carries only what
  changes rarely (track lists, current stream, error).
- **The engine owns tracks.** One list, read from the engine. No merging of stream-provided and
  user-added lists in Dart, no `external:` id scheme if the engine can hold external subtitles as
  real tracks.
- **Subtitle concerns live in their own file** — restore `player_subtitle_manager.dart`.

---

## 5. Phases

Phases 1–3 are app-side only. **No engine change, no new dependency, shippable independently.**

### Phase 0 — Baseline

**Goal.** Be able to tell whether anything we do afterwards works. Everything below is measured
against this; without it the whole plan is opinion.

**Scope**
- Pick two reference devices and name them in this doc: the Android TV box that hangs, and the iOS
  device that overheats.
- Capture, on a fixed 10-minute VOD stream and a fixed live stream, on each device: peak and steady
  RSS, dropped-frame count, average and p99 frame build time, device temperature or thermal state,
  and time-to-first-frame.
- Record the same on macOS as the control — it does not exhibit the iOS overheating, which is itself
  a clue.
- Note the exact stream URLs and app build used, so the runs are repeatable.

**Explicitly out of scope.** No fixes. Resist fixing anything you notice here; write it down instead.

**Files.** None. Results go in `docs/player-baseline.md`.

**Done when.** A committed table of numbers that a later run can be diffed against.

**Risk.** Skipping this. Every later phase's "done when" depends on it, and re-deriving a baseline
after changes have landed is impossible.

### Phase 0b — Build viability gate

**Goal.** Prove the app can be *built* with `vlc_player` at all. Nothing downstream matters if it
cannot. **No app code changes** — this is a build spike on a throwaway branch.

**Scope**
- Add `vlc_player` as a path dependency and build for every target. It is currently **absent from
  `pubspec.yaml`**, so it has never been compiled by this app.
- Reconcile the toolchain skew: the fork's buildscript pins **AGP 9.0.1 / Kotlin 2.3.20**
  (`packages/vlc_player/android/build.gradle.kts:4-15`) against the app's **8.13.0 / 2.2.20**
  (`android/settings.gradle.kts:22-23`). `compileSdk`/`targetSdk`/JVM target are already forced onto
  subprojects by `android/build.gradle.kts:41,44,50-53`, so those are fine; the buildscript block is
  not. Deleting it is the likely fix — Flutter plugins do not need one.
- Configure ABI splits. `libvlc-all:3.7.0` is a **97 MB fat AAR** (armeabi-v7a 37, arm64-v8a 50,
  x86 46, x86_64 55). With splits an arm64 install takes ~50 MB, which is the agreed "reasonable".
- Windows: the build downloads the VLC runtime from `download.videolan.org`
  (`packages/vlc_player/windows/CMakeLists.txt:61`). Vendor it or pre-seed the cache, or offline and
  CI builds fail.
- Linux: `pkg_check_modules(LIBVLC REQUIRED)` needs system libVLC. Decide bundle-or-document.
- **Already fixed:** `minSdk` was 29 upstream, which excluded Fire OS 7 (Android 9 / API 28). Lowered
  to 24 in commit `2aff10d` — libVLC's own AAR declares 17, and the only API-24 symbol in the plugin
  is `PixelCopy` in `takeSnapshot`. Verified by reading, **not yet by a build**; this phase proves it.

**Done when.** A debug build runs on Android, Android TV, iOS, macOS, Windows and Linux with the
package linked, and the arm64 APK size delta is recorded.

**Risk / escape hatch.** If the toolchain skew or the from-source libVLC requirement makes this
uneconomic, the migration stops here and Phases 1-3 still stand on their own.

### Phase 0c — Render path

**Goal.** Decide `Texture` vs platform view on evidence, before any migration code depends on it.

Stability and performance are the stated priorities and APK size is negotiable, so this is not a
"measure and maybe" item. `vlc_player` renders through `AndroidView` / `UiKitView` / `AppKitView`
(`packages/vlc_player/lib/src/vlc_player.dart:101,117,172`) with `Texture` only on Windows and Linux.
media_kit uses a `Texture` on Android today. Adopting platform views is a step **backwards** on the
exact axis that matters most — hybrid composition with a controls overlay on top of video is its
worst case, on precisely the low-end TV hardware in question.

**Scope**
- Measure the example app against media_kit on the Phase 0 reference devices.
- If platform views cost anything measurable, build the Android texture path in the fork:
  `SurfaceTextureEntry` → `Surface` → `IVLCVout.setVideoSurface`, replacing `attachViews`
  (`VlcPlayerPlatformView.kt:493`). ~150-250 lines of Kotlin.
- Apple is harder — VLCKit exposes no clean frame callback, so it means
  `libvlc_video_set_callbacks` → `CVPixelBuffer` → `FlutterTexture`. Scope separately; do Android first.
- Note the related defect either way: `_platformViewKey` is
  `'${identityHashCode(controller)}-${fit.name}'` (`vlc_player.dart:189`), so **changing video fit
  recreates the entire LibVLC instance** — a visible stall on every resize press.

**Done when.** A recorded comparison, and a decision written into this doc.

### Phase 1 — Stop the bleeding

**Goal.** Remove the verified defects that cost memory, battery and stability today.

**Scope**
- Make the second engine conditional. [player_screen.dart:177](../lib/features/player/presentation/player_screen.dart#L177)
  builds `vv.VideoController(autoPlay: true)` unconditionally, next to the media_kit controller at
  :174. Its Kotlin constructor immediately creates an ExoPlayer, two `SurfaceProducer`s and a
  `SubtitlePainter` — for every VOD session that never uses it. Create it lazily, on first live use.
- Fix the dispose-order use-after-dispose. `_player.dispose()` at
  [:306](../lib/features/player/presentation/player_screen.dart#L306), then `setPlaybackSpeed` at
  [:322](../lib/features/player/presentation/player_screen.dart#L322) when the user exits while
  holding space-for-speed. Restore the speed before disposing, or skip it.
- Cap the render target. `media_kit_video` sizes its surface to the **source** resolution, and the
  Wi-Fi default is 4K ([player_settings_provider.dart:201](../lib/features/settings/presentation/player_settings_provider.dart#L201)),
  so a low-end box fills a 3840×2160 buffer per frame. Lower the default, and cap selectable quality
  by device class.
- Break the readahead feedback loop. [player_controller.dart:1607](../lib/features/player/presentation/player_controller.dart#L1607)
  doubles readahead to 360 s *after a stall* — on a device already failing.
- **Delete `skystream_subtitle_view.dart`** — 620 lines, zero call sites, never rendered a frame.
  Pure deletion, no user impact. It also removes 7 of the 75 `useExoPlayer` references for free.
- Give `DeviceProfile` a low-end axis. `device_info_provider.dart` has no RAM or tier signal, so
  buffer and quality decisions cannot distinguish a flagship from a 1 GB TV box.

**Explicitly out of scope.** No restructuring, no file moves, no engine work.

**Files.** `player_screen.dart`, `player_controller.dart`, `player_settings_provider.dart`,
`core/providers/device_info_provider.dart`.

**Done when**
- A VOD session allocates exactly one decoder stack (verify: no ExoPlayer in the Android profile).
- Exiting the player while holding space does not touch a disposed `Player`.
- Peak memory on the reference TV box drops measurably against the Phase 0 baseline.
- D-pad: unchanged — no UI touched.

**Risk.** Lazy video_view creation could race the first live stream. Escape hatch: keep eager
creation behind a debug flag for one release.

### Phase 2 — UI performance

**Goal.** Fix the rebuild and allocation costs that hurt most on TV and low-end, all engine-independent.

**Scope**
- **The single `RepaintBoundary`.** There is exactly one inside the chrome, at
  `skystream_player_controls.dart:1544`, and it wraps the *entire* `Column`. So one seek-bar tick
  repaints the top bar, both scrims and every icon button in one layer. Add a boundary at the
  `PlayerProgressBar` mount site (`:1568`) so the ticking widget repaints alone. **This is the item
  that moves the frame-time gate.**
- Throttle the position source feeding the nested `StreamBuilder`s in
  `player_stream_widgets.dart:296-314` — libmpv's `time-pos` is unthrottled.
- Unmount the chrome rather than fading it to `opacity: 0` — it stays fully mounted and building
  under `AnimatedOpacity` (`:1545`).
- SRT parsing compiling `RegExp`s per call — the live one is `parseSubtitle`
  (`subtitle_sync_dialog.dart:30`). Hoist the patterns to statics. Note this is reached only from a
  modal (`player_side_panel.dart:842`, `player_bottom_sheets.dart:834`), **not** the playback hot
  path, so it is a correctness/tidiness fix, not a frame-time one.
- `playerGestureHandlerProvider` is `keepAlive` and retains a disposed controls `State`.
- Bundled asset images decoded at native resolution in `subtitle_appearance_dialog.dart`.

**Explicitly out of scope.** No new state management. No widget-tree rewrites. `ValueListenableBuilder`,
selectors and `RepaintBoundary` only.

**Done when**
- Controls do not rebuild on position ticks (verify with the rebuild counter).
- No dropped frames on the reference TV box during steady-state playback.
- D-pad: focus order through the control bar and side panel is unchanged; verify on hardware.

### Phase 3 — Restore structure

**Goal.** Make the controller migratable without changing behaviour.

**Scope**
- Re-extract `player_subtitle_manager.dart`, following the `fvp_test` shape (101 lines:
  `setSubtitleDelay`, `applySubtitleSettings`, `effectiveExternalSubtitles`, `loadExternalSubtitleFile`).
- Collapse per-session instance fields into one session-state object reset on every `load()`.
- Fix ownership: the engine controller's lifetime matches the screen's.
- Delete dead capability branches that are already unreachable.

**Explicitly out of scope.** No engine change. No behaviour change — this phase should be invisible
to users.

**Done when.** Controller is materially smaller, every per-session field is reset in one place, and
playback behaviour is unchanged across VOD, live, torrent and DRM.

### Phase 4 — Decision gate

**Goal.** Decide the engine on evidence, not preference. **No code.**

**Scope**
- Measure Phase 1–3 gains against the Phase 0 baseline. If thermals and hangs are resolved, the
  migration's justification narrows to live-stream correctness alone — which is a much smaller case.
- Run the render-path experiment: `packages/vlc_player/example` with a real live stream and a
  ClearKey stream, on the TV box that hangs and the iOS device that overheats, against media_kit.
  `vlc_player` renders via `AndroidView`/`UiKitView` platform views while media_kit uses a `Texture`;
  this is the one risk that could make things *worse*.
- Settle licensing. The prebuilt binaries (`libvlc-all:3.7.0`, MobileVLCKit/TVVLCKit 3.7.3) carry
  compiled-in GPLv2+ modules despite declaring LGPL-2.1. Adopting VLC means owning a from-source
  libVLC build for Android and Apple, permanently. **Price this before writing migration code.**

**Done when.** A written go/no-go with numbers.

### Phase 5 — Single engine behind a flag, minimal

**Goal.** Play a video with basic controls on the new engine. Nothing else.

**Scope.** Open a URL with headers; play/pause/seek/stop; position and duration; **a forked minimal
controls overlay**; a debug setting selecting old or new engine at `PlayerRoute.build`
(`app_router.dart:269`). Both engines coexist; the old path is untouched.

Plus one non-obvious item: **a single position/duration source of truth**. `saveProgress()`
(`player_controller.dart:3773`) branches on `state.useExoPlayer` at `:3778`; under a screen-level
flag that stays `false`, so it reads the **idle media_kit handle** and returns 0. It has 9 call
sites and drives history rows, `scrobbleStart`, the local watched flag, `markWatched` at ≥90% and
next-episode rollover. Wrong reads push **irreversible** writes to Trakt/Simkl/MAL. Until a
validated duration source exists, **the new path is read-only against watch history and sync** —
state that explicitly, and treat the `if (dur < 30000) return;` guard at `:3807` as a required
invariant of any reimplementation.

**Explicitly out of scope.** Tracks, subtitles, live, DRM, torrent, PiP, skip, next-episode, gestures,
speed, volume boost.

**Why the controls are forked, not reused.** An earlier draft said "use the existing control bar".
That is not possible: `SkyStreamPlayerControls` takes `final Player player` — a **non-nullable
media_kit type**, `required` (`skystream_player_controls.dart:36,61`) — reads
`playerControllerProvider` **72 times**, and *unconditionally mounts* `TorrentInfoWidget` (:1168),
`ResumePromptOverlay` (:1182), `NextEpisodeOverlay` (:1200), `SkipSegmentOverlay` (:1226), three
`PlayerSidePanel`s (:1258, :1275, :1318) and `PlayerMetadataScrim` (:1297) — i.e. exactly the
features this phase excludes. The surrounding chrome is equally coupled (`player_side_panel`,
`player_stream_widgets`, `skip_segment_overlay` all import media_kit or video_view).

So Phase 5 writes a **new, small** overlay and **no file the old screen imports may be edited during
Phases 5-7**. Give it a line budget and hold to it. Include the seek bar explicitly — `PlayerProgressBar`
(`player_stream_widgets.dart:16`) is the largest chrome component and is bound to
`widget.player.stream.buffer` (:315).

**Done when.** A VOD stream plays end to end on every platform we ship, with working controls, and
D-pad reaches every control on the TV box.

### Phase 5b — Rebuild the controls' machinery, keep the design

**Goal.** The controls look right and behave wrong. Keep the visual design pixel-for-pixel; replace
the machinery underneath, which is the app's densest concentration of manual handling.

**What is actually wrong** — `skystream_player_controls.dart`, 1,659 lines:

| Symptom | Evidence |
|---|---|
| The auto-hide timer is poked by hand from **15 call sites** | `:114, :188, :247, :284, :351, :548, :580, :661, :700, :728, :749, :767, :777, :1024, :1048` (definition `:665`) |
| **6 hand-managed `FocusNode`s**, 34 references | `_playFocusNode`, `_skipFocusNode`, `_resumeFocusNode`, `_nextEpFocusNode`, `_backFocusNode`, `_scrubFocusNode` |
| **72 instance fields**, 23 `setState` calls | one State object holding the whole player's UI state |
| **72 `playerControllerProvider` reads**, only 30 with `.select(` | the rest rebuild on any state change |
| **99 `if (`, 24 `Platform.is*`** scattered through build | per-widget platform branching |
| **One `RepaintBoundary`** for the entire `Column` | `:1544` — a seek tick repaints the whole overlay |

Each of these is the same bug in a different costume: state that should be derived is instead
maintained by hand at every call site, so correctness depends on remembering to update it. Miss one
`_startHideTimer()` and the chrome vanishes mid-interaction; add one in the wrong branch and it
never hides.

**Scope**
- **One interaction sink.** A single `Listener`/`Focus` wrapper resets the hide timer on any pointer
  or key event. Delete all 15 manual calls. One place, not fifteen.
- **Delete the named focus nodes.** The screen already does the right thing — `_handleKey`
  (`player_screen.dart:347`) stays out of the way so native directional traversal runs, and
  `FocusTraversalGroup(policy: ReadingOrderTraversalPolicy())` is already in place at `:1538`.
  Ordinary focusable widgets in reading order replace the hand-placed nodes. Keep at most one, for
  the autofocus target on open.
- **High-frequency state to `ValueListenable`.** Position, buffer and visibility become listenables
  consumed by leaf `ValueListenableBuilder`s, so a tick rebuilds one widget. Riverpod keeps only what
  changes rarely.
- **Resolve platform once.** Compute a layout/capability record at build from `DeviceProfile`
  instead of 24 scattered `Platform.is*` checks.
- **Boundaries where they matter** — carried over from Phase 2.

**Explicitly out of scope.** Any visual change. No new features. No redesign. If the rebuilt overlay
does not look identical, it is wrong.

**Done when**
- Line count materially down (target: well under half of 1,659) with **no visual diff**.
- Exactly one code path restarts the hide timer.
- D-pad: the full §6 hardware checklist passes — this phase touches focus, so it is the highest-risk
  phase for TV and must be tested on real hardware before it lands.
- Controls do not rebuild on position ticks.

**Risk / escape hatch.** This is a rewrite of the most-touched UI in the app. It lands on the new
engine's overlay first (Phase 5), where it is behind the flag and cannot regress the shipping path.
Only after it is proven there does the old overlay get retired with its engine in Phase 8.

### Phase 6 — Tracks and subtitles, engine-owned

**Goal.** Deliver constraint 3 — no hand-driven track state.

**Scope.** `getAudioTracks`/`setAudioTrack`, `getSubtitleTracks`/`setSubtitleTrack`/`disableSubtitle`,
`addSubtitle(Uri)` for external files, `setSubtitleDelay`. One track list owned by the engine.

**Explicitly out of scope.** The `external:` id scheme, the two-list merge, the 800 ms/2000 ms
auto-select races, `pendingVideoViewSubtitleIdsBeforeReload` — all deleted, not ported.
`fvp_test`'s `selectSubtitleTrack` was **26 lines**; treat that as the budget.

**Done when.** Embedded and external audio/subtitle tracks are selectable, delay works, and no Dart
code mirrors engine track state.

### Phase 7 — Live, then the long tail

**Goal.** Move live onto the new engine and retire video_view.

Live is the strongest technical case for VLC: FFmpeg's `hls.c` has no `EXT-X-DISCONTINUITY`
handling, `dashdec.c` handles only one period, and HLS variant bitrate is metadata that is never
switched — which is why we pin `hls-bitrate=max`. These are FFmpeg capability gaps that no mpv
property fixes. Then ClearKey, torrent, PiP, skip segments, next-episode.

### Phase 8 — Delete the old engine

Remove media_kit, `packages/video_view`, the **75** `useExoPlayer` references across 8 files, and the
**51** libmpv properties (the 7 HDR ones are among them — they are not a separate item).

**Gated on, not vibes:** the subtitle option from §3 is chosen and implemented; the §6 hardware
checklist passes on Android TV; a full Phase 0 baseline re-run is no worse than the original on every
metric; and the new path has been the default (Phase 7) through at least one full release cycle with
no player-related regression reports. If any of those is unmet, this phase does not start — both
engines keep coexisting, which is annoying but safe.

---

## 6. TV / D-pad

**The current design is correct and must be preserved.** `_handleKey`
([player_screen.dart:347](../lib/features/player/presentation/player_screen.dart#L347)) is
deliberately minimal: it uses `FocusManager.instance.primaryFocus == node` to detect "no control is
focused" and otherwise stays out of the way so **native directional traversal** and the focused
control's own activation run. No manual focus bookkeeping. Keep this.

### The real risk is focus theft, not key interception

An earlier draft of this plan got this wrong. It said the platform view might *swallow key events*,
and prescribed "three lines in our fork" on the Android side. That fix cannot work, because the node
is not created by the native view — **Flutter creates it**:

* `flutter/lib/src/widgets/platform_view.dart:716` declares `FocusNode? _focusNode;`
* `:722-733` returns `Focus(focusNode: _focusNode, onFocusChange: …, child: _AndroidPlatformView(…))`
* `:799-801` installs `onFocus: () { _focusNode!.requestFocus(); }`

`Focus` defaults to `canRequestFocus: true`, `skipTraversal: false`. The Darwin path is identical.
`VlcPlayer` uses `AndroidView` (`vlc_player.dart:101`), `UiKitView` (:117) **and** `AppKitView`
(:172) — three platforms, so a Kotlin-only fix would miss two of them.

**The concrete failure.** With the chrome hidden, `skystream_player_controls.dart:1540` is
`ExcludeFocus(excluding: !chromeVisible)`, which removes *every* chrome node from the tree. The
full-screen platform-view node is then the only focusable candidate. It takes `primaryFocus`, so
`player_screen.dart:348`'s `rootHasFocus` evaluates **false**, `_handleKey` correctly stands aside —
and nothing is left to handle the key. Remote Play/Pause stops working and focus is invisible.

This works today only because **both current engines render to a `Texture`, which contributes no
focus nodes at all.** It is a regression introduced by the render path, not a pre-existing risk.

### The fix — two parts, a Phase 5 prerequisite (not "if it bites")

1. **Dart, in the fork.** Wrap all three platform-view branches in
   `packages/vlc_player/lib/src/vlc_player.dart:96-181` in `ExcludeFocus`. This sets
   `descendantsAreFocusable: false`, drops the node from `traversalDescendants`, *and* neutralises
   the engine's `requestFocus` callback. This is the part that actually works.
2. **Kotlin, also in the fork.** `isFocusable = false` and
   `descendantFocusability = FOCUS_BLOCK_DESCENDANTS` on the `VLCVideoLayout`, for Android's own
   native focus search.

If Phase 0c moves rendering to a `Texture`, this problem disappears entirely — another reason that
phase comes first.

### A second TV hazard: `canSeek` becomes a flapping runtime value

`canSeek => !useExoPlayer || isSeekable` (:273) is a constant today on the media_kit path. On VLC it
becomes the live `isSeekable` field, which flips false during open and buffering. `_scrubFocusNode`
is focusable only when `isTv && canSeek` (`player_stream_widgets.dart:242`), so the scrubber's focus
node would appear and vanish mid-session — and can be destroyed **while holding focus**, dumping the
user into the same invisible-focus state. Keep it unconditionally focusable on TV and no-op the seek
when the engine reports not-seekable.

### Acceptance checklist — must pass on real Android TV / Fire TV hardware

- `debugDumpFocusTree()` on the new route shows **no** `AndroidView`/`UiKitView`/`AppKitView` node in
  `traversalDescendants`. (Mechanical, and the one check that catches the regression above.)
- Every control in the bottom bar is reachable by D-pad, in visual order.
- With chrome **hidden**, remote Play/Pause still works.
- The side panel is enterable and exitable without a focus trap.
- Back/Escape dismisses one layer at a time and never skips straight out of the player.
- Focus is visible at all times — no invisible focus, including during buffering.
- Seeking with the scrubber works, and the scrubber never disappears while focused.

## 6b. Testing and CI — currently absent

The repo has **3 app test files** and `.github/workflows` runs **no** analyze, test or build job.
Nine phases of "done when" gates therefore rest entirely on one person checking by hand on hardware.
That is the most likely way this migration silently regresses something.

Minimum, and it belongs in **Phase 1** so everything after it is protected:

- A CI job on push/PR running `flutter analyze` (currently clean, 2 pre-existing warnings) and
  `flutter test`, made required on `main`.
- A build job per platform, so the Phase 0b toolchain work cannot rot.
- Unit tests for the pure logic the migration will touch: `stream_quality_sorter`,
  `torrent_file_parser`, episode filtering, and — most importantly — the resume/progress arithmetic
  in `saveProgress`, since that is where the irreversible third-party writes originate.

Golden-frame or integration tests for the player itself are **not** proposed; they are expensive and
brittle. The hardware checklist in §6 stays manual, but it should be a written checklist that is
actually run, not an assumption.

## 7. Open questions

| Question | Experiment |
|---|---|
| Do Phases 1–3 alone fix the thermals and hangs? | Phase 0 baseline vs post-Phase-3 on the reference TV box and iOS device. |
| Does `AndroidView` regress TV performance or D-pad vs media_kit's `Texture`? | Phase 4 render-path experiment. Decisive. |
| Is a from-source libVLC build acceptable, forever? | Licensing review before Phase 5. |
| Does the iOS `-Dvideotoolbox-gl=disabled` build explain the overheating? | Compare iOS against macOS (which ships it enabled) on the same stream. If yes, a rebuilt libmpv may beat migrating. |
| Can VLC play our ClearKey content? | Test a real ClearKey stream in Phase 4. |
| Is `fvp` a better target than VLC? | `fvp_test` already worked here. Re-run it against current `main` before committing to VLC. |

---

## 8. Not doing

- **A `PlaybackEngine` interface.** Two implementations exist only during migration, and the flag
  can select at the screen level. Adding an interface both engines must satisfy is the exact
  over-engineering constraint 1 rules out.
- **Migrating the HDR settings.** No libVLC equivalent. They go when media_kit goes.
- **Assuming app-side subtitle rendering exists.** It does not — `skystream_subtitle_view.dart` is
  dead code with zero call sites. See §3; this is a real open decision, not a solved one.
- **A big-bang cutover.** Both engines coexist behind a flag until Phase 8.
- **Adopting engine-native controls, or redesigning the look.** The controls stay Flutter and keep
  their current visual design. `player_screen.dart:698` passes
  `controls: (state) => const SizedBox.shrink()`, so media_kit's built-ins are already off;
  `vlc_player` ships none at all (`VlcPlayer` takes only `controller`, `backgroundColor`, `fit`).
  No engine offers D-pad traversal, Skip Intro, next-episode, the sources panel or our theming, and
  native controls would sit *inside* the platform view — on the far side of the focus boundary §6 is
  about. What **is** being rewritten is the controls' internal machinery: see Phase 5b.
  Corollary for Phase 0c: a full-screen Flutter overlay composited over a **platform view** every
  frame is hybrid composition's worst case; over a **`Texture`** it is an ordinary widget. The
  controls architecture is itself an argument for the texture path.
