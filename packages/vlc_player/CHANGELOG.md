# Changelog

## 2.1.3 - 2026-06-02

### Changed

- Expanded the package description in `pubspec.yaml` to satisfy pub.dev
  metadata scoring requirements.

## 2.1.2 - 2026-05-28

### Fixed

- Restored Android video output after the app moves to the background and is
  brought back to the foreground.

### Added

- Added an Android lifecycle integration test that backgrounds the example app,
  resumes it, and verifies that video pixels are visible again.

## 2.1.1 - 2026-05-28

### Changed

- Aligned the plugin and example project scaffolding with the Flutter 3.44
  plugin template while preserving the existing VLC playback API and native
  implementations.
- Updated the Dart SDK constraint to `^3.12.0` and refreshed Android template
  tooling to AGP 9.0.1, Kotlin 2.3.20, and Gradle 9.1.0.
- Moved iOS and macOS Swift sources to the Flutter 3.44 plugin source layout
  while keeping the official CocoaPods `MobileVLCKit` and `VLCKit`
  dependencies.
- Pinned official Apple VLCKit CocoaPods to `3.7.3` to keep CI dependency
  resolution deterministic and avoid excessive CocoaPods spec lookups.

## 2.0.1 - 2026-05-19

### Changed

- Reduced duplicate Android, iOS, and macOS player events before they reach
  Dart, matching the existing Linux and Windows event de-duplication behavior.
- Expanded Dart regression coverage for source diagnostics, structured errors,
  playlist rollback, texture creation failures, and empty snapshot payloads.

## 2.0.0 - 2026-05-18

### Added

- Added `VlcPlayerController.getMediaStats()` and `VlcMediaStats` for
  best-effort LibVLC media read, demux, decoder, output, and stream-output
  counters.

### Changed

- Documented the `2.x` API stability policy and clarified the migration path
  from older stable releases.
- Reduced duplicate Linux and Windows player events before they reach Dart.
- Expanded widget and native regression coverage for platform-view creation,
  texture controller replacement, and desktop snapshot equality.

### Breaking

- Android now requires `minSdk 29` / Android 10 or newer.

## 1.0.0 - 2026-05-18

### Added

- Added `VlcPlayer.fit` with `VlcVideoFit.contain`, `cover`, `fill`, and
  `none` modes.
- Added `takeSnapshot()`, `setAudioDelay()`, and `setSubtitleDelay()` to
  `VlcPlayerController`, with native implementations on Android, iOS, macOS,
  Linux, and Windows.
- Added playlist mutation APIs: `jumpTo()`, `addToPlaylist()`,
  `insertIntoPlaylist()`, `removeFromPlaylistAt()`, `clearPlaylist()`, and
  `shufflePlaylist()`.
- Added `audioDelay` and `subtitleDelay` to `VlcPlayerValue`.
- Added CI validation for Android 16 KB native page-size support on 64-bit
  packaged libraries.

### Changed

- Promoted the package to `1.0.0` after the Dart API cleanup, native feature
  completion, and CI validation work.

### Breaking

- Android now requires `minSdk 26` because snapshots use Android `PixelCopy`
  directly.

## 0.8.0 - 2026-05-18

### Changed

- Promoted the pre-1.0 stabilization work to the `0.8.0` milestone after the
  API surface cleanup, public API regression coverage, internal controller
  typing, native invocation consolidation, and local format compatibility
  validation completed on `master`.
- Kept the application-facing API unchanged from the latest `0.7.x`
  stabilization builds.

## 0.7.25 - 2026-05-17

### Changed

- Reduced duplicated Dart controller native invocation code by centralizing
  attached-player argument construction, source argument construction, and
  `PlatformException` mapping.
- Avoided no-op desktop orientation channel calls in the example full-player
  page, which makes macOS driver integration tests finish reliably.
- Added regression coverage for texture-backed native player creation failures.

## 0.7.24 - 2026-05-17

### Changed

- Replaced dynamic widget-to-controller internal calls with an unexported typed
  internal controller contract, keeping the application-facing API unchanged
  while making attachment wiring statically checked.

## 0.7.23 - 2026-05-17

### Added

- Added public API surface tests that keep removed controller compatibility
  shortcuts and native attachment internals out of the exported Dart API.
- Documented the package's pre-1.0 API stability policy and migration path from
  the removed `setSource()` and constructor `source`/`httpHeaders`
  compatibility parameters.

## 0.7.22 - 2026-05-17

### Changed

- Tightened the pre-1.0 Dart API surface by removing the `setSource()` shortcut
  and the controller constructor's `source`/`httpHeaders` compatibility
  parameters. Use `VlcMediaSource` with `setMedia()` or `mediaSource` instead.
- Moved controller attachment, texture attachment, view type, and method-channel
  details out of the statically visible app-facing controller API.

## 0.7.21 - 2026-05-17

### Added

- Added opt-in controller event throttling for progress-only native updates,
  while keeping playback state changes and errors immediate.
- Added Dart tests for throttled event coalescing, critical-event bypass, error
  bypass, and disposal cleanup.

## 0.7.20 - 2026-05-17

### Changed

- Reduced desktop texture-frame buffer churn by reusing same-size video buffers
  and copying rendered pixels only when a new frame generation is available.
- Added shared native tests for desktop frame buffer reuse and texture copy
  generation tracking.

## 0.7.19 - 2026-05-17

### Changed

- Improved integration test diagnostics and cleaned temporary format fixtures
  after each test case.
- Added Dart-side event pressure tests for duplicate native events and repeated
  error payloads.

## 0.7.18 - 2026-05-17

### Changed

- Added value equality to player state snapshots so duplicate native events do
  not trigger redundant listener notifications.
- Stabilized macOS integration coverage for the full-player orientation
  control.

## 0.7.17 - 2026-05-17

### Changed

- Reduced duplicated integration and native test scaffolding with shared test
  helpers.
- Centralized release tag/version validation used by publish CI jobs.

## 0.7.16 - 2026-05-17

### Changed

- Expanded Windows and Linux native core tests for lifecycle, validation, and
  snapshot stability edge cases.

## 0.7.15 - 2026-05-17

### Changed

- Expanded Dart-side controller and value tests with shared method channel test
  utilities and additional edge-case coverage.

## 0.7.14 - 2026-05-17

### Changed

- Expanded README usage examples and public Dart API documentation.

## 0.7.13 - 2026-05-16

### Added

- Added CI coverage for local format compatibility integration tests, with
  smoke coverage on Android, full coverage on macOS and Windows, and iOS build
  validation.

## 0.7.12 - 2026-05-16

### Added

- Expanded local format compatibility integration coverage to MP3, AAC/M4A,
  FLAC, Ogg Vorbis, and Opus audio fixtures.

## 0.7.11 - 2026-05-16

### Added

- Expanded local format compatibility integration coverage to MOV, MKV, WebM,
  and MPEG-TS video fixtures.

## 0.7.10 - 2026-05-16

### Added

- Added local format compatibility integration fixtures and smoke coverage for
  MP4, HLS/M3U8, and external SRT subtitle loading.

## 0.7.9 - 2026-05-16

### Fixed

- Compared `VlcMediaInfo` and `VlcMediaTrackInfo` instances by value so media
  metadata snapshots can be reliably compared in application code and tests.

## 0.7.8 - 2026-05-16

### Fixed

- Compared structured `VlcPlayerError.details` payloads by value so equivalent
  Map/List details produce equal errors and matching hash codes.

## 0.7.7 - 2026-05-16

### Changed

- Pinned Windows CI validation to the `windows-2025-vs2026` runner image ahead
  of the GitHub-hosted Windows runner migration.

## 0.7.6 - 2026-05-16

### Fixed

- Restored the previous source and playlist state when replacing media fails in
  the native player.

## 0.7.5 - 2026-05-16

### Fixed

- Hardened media information and track description parsing so malformed native
  metadata payloads are ignored instead of throwing type errors.

## 0.7.4 - 2026-05-16

### Fixed

- Hardened Dart-side platform event parsing so malformed native payload fields
  are ignored instead of throwing during event handling.

## 0.7.3 - 2026-05-16

### Changed

- Updated GitHub Actions checkout steps to the Node 24 runtime generation to
  remove CI deprecation warnings.
- Updated Java setup and integration-test drive commands for more reliable
  GitHub Actions runs.
- Switched iOS integration CI to direct `flutter test` execution on a clean
  simulator to avoid Flutter Driver launch hangs.

## 0.7.2 - 2026-05-16

### Fixed

- Preserve playlist state when a pending playlist item is replayed during
  platform view or texture attachment.

## 0.7.1 - 2026-05-16

### Fixed

- Report playlist auto-advance loading failures through `VlcPlayerValue.error`
  instead of leaving them as unhandled asynchronous errors.

## 0.7.0 - 2026-05-16

### Added

- Added package topics and third-party notices for VLC, VLCKit, MobileVLCKit,
  and the vendored libvlcpp headers.
- Added release metadata tests that verify pubspec, podspec, README, and
  changelog version alignment.

### Changed

- Updated iOS and macOS podspec metadata to point at the project repository and
  package author.
- Replaced the example README template with plugin-specific run instructions.
- Hardened example integration tests to create native players without loading
  invalid media fixtures and to use VLC's dummy audio output on headless Linux
  CI, with Linux core coverage handled by native ctest.

### Fixed

- Avoided querying native VLC playback state before a media source is attached
  on desktop texture players.

## 0.6.0 - 2026-05-16

### Added

- Added `VlcPlaylistLoopMode` for playlist repeat behavior, including
  `loopOne` and `loopAll` handling for auto advance and manual navigation.

## 0.5.0 - 2026-05-16

### Added

- Added Dart-side playlist support with `setPlaylist()`, `next()`,
  `previous()`, current playlist state, and optional auto advance on ended
  playback.

## 0.4.0 - 2026-05-16

### Added

- Added `VlcMediaSource` and `VlcPlayerController.setMedia()` for loading media
  with HTTP headers, VLC media options, and an initial start position.

### Changed

- Kept `setSource()` as the simple URI API and route it through the richer
  media source flow.

## 0.3.0 - 2026-05-16

### Added

- Added `VlcPlayerError`, `VlcPlayerException`, and structured
  `VlcPlayerValue.error` playback errors.
- Normalized native platform error codes for Dart-facing command failures and
  playback error events.

## 0.2.0 - 2026-05-16

### Added

- Added readiness, seekability, live stream detection, decoded video size, and
  buffering progress fields to `VlcPlayerValue`.
- Surfaced the new playback status fields from Android, iOS, macOS, Windows,
  and Linux native players.

### Changed

- Updated the full player example to show loading state and disable seeking for
  non-seekable or live streams.

## 0.1.0 - 2026-05-16

### Changed

- Hardened controller and native player lifecycle handling when widgets are
  detached, replaced, or disposed during async attachment.
- Strengthened release and CI validation so Android, iOS, macOS, Windows, and
  Linux run real plugin integration tests.

### Fixed

- Rejected empty media URIs and non-finite playback speeds before they reach
  native VLC code.
- Returned `track_not_found` errors for missing iOS and macOS audio/subtitle
  track ids.

## 0.0.4 - 2026-05-16

### Added

- Added Windows and Linux desktop playback support.
- Added desktop APIs for source, playback controls, seeking, volume, speed, tracks, subtitles, and media info.
- Added CI integration tests across Android, iOS, macOS, Windows, and Linux.

### Fixed

- Improved native player lifecycle handling for desktop texture players.

## 0.0.3 - 2026-05-15

### Fixed

- Fixed the release workflow so pub.dev validation runs before platform builds mutate example lockfiles.

## 0.0.2 - 2026-05-15

### Added

- Added Windows support with bundled VLC runtime download.
- Added example pages for video, HLS, and full-player controls.
- Added GitHub Actions validation and pub.dev publishing workflow.

### Fixed

- Improved player lifecycle handling and event delivery across platforms.

## 0.0.1 - 2026-05-15

### Added

- Initial Android, iOS, and macOS implementation backed by VLC.
