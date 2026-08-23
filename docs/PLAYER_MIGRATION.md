# Player Migration Plan

Status: **planning**. Branch: `player-vlc-migration`.

This plan does **not** start by migrating. The first phases fix app-side defects and restore
structure, because the evidence says most of the instability is ours, not the engine's. The
engine decision comes after we can measure.

---

## 1. Why

One 5,052-line Riverpod `Notifier`
([player_controller.dart](../lib/features/player/presentation/player_controller.dart)) drives two
engines:

- **media_kit** (libmpv) — default and VOD.
- **video_view** (ExoPlayer / AVPlayer), vendored at `packages/video_view` — live only.

The cost, measured:

| | |
|---|---|
| `useExoPlayer` branches in the controller | **44** |
| `_videoViewController` references | **71** |
| `setProperty` calls / distinct libmpv properties | **77 / 43** (18 of them `sub-*`) |
| Controller / screen size | **5,052 / 924 lines** |

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
| Subtitle styling via 18 `sub-*` properties | `player_controller.dart` `applySubtitleSettings`, `subtitle_appearance_dialog.dart` (1,816 lines) | **Delegate to app-side rendering** | VLC 3.x fixes subtitle styling at instance creation and cannot restyle live. The app already renders its own subtitles in `skystream_subtitle_view.dart`. Keep app-side rendering, disable the engine renderer, delete the property plumbing. |
| Volume boost above 100% | `supportsVolumeBoost` (:276) | **Keep** | Free — `setVolume` clamps 0–200 in `vlc_player`. |
| Playback speed above 2× | `maxPlaybackSpeed` (:275) | **Keep, unify** | The 2.0 vs 3.0 split exists only because of the engine divergence. One engine, one limit. |
| Per-stream health pre-flight `HEAD`/ranged-`GET` | `_isStreamCandidateHealthy` (:2988) | **Drop** | Uses a different HTTP identity than playback, so it fails good sources. Let playback fail and use the existing failover. |
| `_isLiveStream` 15-pattern URL guesser | `player_controller.dart:4726-4770` | **Demote to a hint** | Both candidate engines report `isLive` themselves. Keep the URL check only as a pre-open guess for buffer sizing. |
| The seven capability getters | :273-280 | **Delete** | All are `!useExoPlayer`-shaped. One engine makes them constants. |
| Widevine / PlayReady | — | **Not applicable** | There is none. `_extractKeysFromLicenseUrl` (:4671-4715) parses a W3C ClearKey JWK; there is no CDM code in `lib/`. DRM is ClearKey only. |
| `pendingVideoViewSubtitleIdsBeforeReload`, `selectNewestVideoViewSubtitleAfterReload` | :425-426, :1145-1159 | **Delete** | Exists purely to survive a video_view reload. Dies with the second engine. |
| `_videoViewSupportsMergedExternalSubtitles` | :494 | **Delete** | A platform check for one engine's quirk. |

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
- Subtitle overlay `setState` at 10 Hz with an O(cues) scan and URL re-resolution per tick
  (`skystream_subtitle_view.dart`) → `ValueListenableBuilder` on position, pre-indexed cues.
- SRT parsing compiling thousands of `RegExp`s synchronously on the UI isolate → hoist the patterns
  to statics; move parsing off the UI isolate if it is still visible.
- Controls rebuilding on every position tick — the whole control `Column` stays mounted under
  `AnimatedOpacity(opacity: 0)` with nested `StreamBuilder`s on position/duration/buffer
  (`skystream_player_controls.dart`, `player_stream_widgets.dart`) → selectors + `RepaintBoundary`,
  and unmount rather than fade to zero.
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

**Scope.** Open a URL with headers; play/pause/seek/stop; position and duration; the existing control
bar; a debug setting selecting old or new engine. Both engines coexist; the old path is untouched.

**Explicitly out of scope.** Tracks, subtitles, live, DRM, torrent, PiP, skip, next-episode, gestures,
speed, volume boost.

**Done when.** A VOD stream plays end to end on every platform we ship, with working controls, and
D-pad reaches every control on the TV box.

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

Remove media_kit, `packages/video_view`, all 44 `useExoPlayer` branches, the 43 libmpv properties,
and the HDR settings. **Only after the new path has shipped and held.**

---

## 6. TV / D-pad

**The current design is correct and must be preserved.** `_handleKey`
([player_screen.dart:347](../lib/features/player/presentation/player_screen.dart#L347)) is
deliberately minimal: it uses `FocusManager.instance.primaryFocus == node` to detect "no control is
focused" and otherwise stays out of the way so **native directional traversal** and the focused
control's own activation run. No manual focus bookkeeping. Keep this.

**The risk.** `vlc_player` renders via `AndroidView` on Android. Platform views participate in
Android's focus system and can swallow key events. The package's `VlcPlayerPlatformView.kt` does
**no** focus or key handling — `getView()` returns a bare `VLCVideoLayout` — so it is not actively
stealing input, but it inherits Android defaults and this must be tested on hardware.

**Fix if it bites** (three lines in our fork): `isFocusable = false` and
`descendantFocusability = FOCUS_BLOCK_DESCENDANTS` on the layout.

**Acceptance checklist, every UI-touching phase**
- Every control in the bottom bar is reachable by D-pad, in visual order.
- The side panel is enterable and exitable without a focus trap.
- Back/Escape dismisses one layer at a time and never skips straight out of the player.
- Play/Pause on the remote works when no control is focused.
- Focus is visible at all times — no invisible focus.

---

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
- **Porting the subtitle-styling property plumbing.** App-side rendering already exists.
- **A big-bang cutover.** Both engines coexist behind a flag until Phase 8.
- **Rewriting the control UI.** It works and its D-pad model is sound. Optimize it; do not replace it.
