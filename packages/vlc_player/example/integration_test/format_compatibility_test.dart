import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:vlc_player/vlc_player.dart';

import 'test_support.dart';

const String _assetRoot = 'assets/format_fixtures';
const String _formatSuite = String.fromEnvironment(
  'VLC_PLAYER_FORMAT_SUITE',
  defaultValue: 'all',
);

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('format compatibility ($_formatSuite)', () {
    for (final format in _formatsForSuite(_formatSuite)) {
      testWidgets('loads ${format.name}', (WidgetTester tester) async {
        await _runFormatCase(tester, format);
      });
    }

    if (_includesSubtitleCase(_formatSuite)) {
      testWidgets('adds an external SRT subtitle', (WidgetTester tester) async {
        await _runFormatCase(
          tester,
          const _FormatCase(
            name: 'MP4 with SRT subtitle',
            assetPath: '$_assetRoot/video.mp4',
            expectsVideo: true,
            subtitleAssetPath: '$_assetRoot/captions.srt',
          ),
        );
      });
    }
  });
}

const List<_FormatCase> _smokeFormats = <_FormatCase>[
  _FormatCase(
    name: 'MP4',
    assetPath: '$_assetRoot/video.mp4',
    expectsVideo: true,
  ),
  _FormatCase(
    name: 'HLS M3U8',
    hlsPlaylistAssetPath: '$_assetRoot/hls/playlist.m3u8',
    hlsSegmentAssetPath: '$_assetRoot/hls/segment.ts',
    expectsVideo: true,
  ),
];

const List<_FormatCase> _videoContainerFormats = <_FormatCase>[
  _FormatCase(
    name: 'MOV',
    assetPath: '$_assetRoot/video.mov',
    expectsVideo: true,
  ),
  _FormatCase(
    name: 'MKV',
    assetPath: '$_assetRoot/video.mkv',
    expectsVideo: true,
  ),
  _FormatCase(
    name: 'WebM',
    assetPath: '$_assetRoot/video.webm',
    expectsVideo: true,
  ),
  _FormatCase(
    name: 'MPEG-TS',
    assetPath: '$_assetRoot/video.ts',
    expectsVideo: true,
  ),
];

const List<_FormatCase> _audioFormats = <_FormatCase>[
  _FormatCase(
    name: 'MP3',
    assetPath: '$_assetRoot/audio.mp3',
    expectsAudio: true,
  ),
  _FormatCase(
    name: 'AAC M4A',
    assetPath: '$_assetRoot/audio.m4a',
    expectsAudio: true,
  ),
  _FormatCase(
    name: 'FLAC',
    assetPath: '$_assetRoot/audio.flac',
    expectsAudio: true,
  ),
  _FormatCase(
    name: 'Ogg Vorbis',
    assetPath: '$_assetRoot/audio.ogg',
    expectsAudio: true,
  ),
  _FormatCase(
    name: 'Opus',
    assetPath: '$_assetRoot/audio.opus',
    expectsAudio: true,
  ),
];

List<_FormatCase> _formatsForSuite(String suite) {
  switch (suite) {
    case 'all':
      return <_FormatCase>[
        ..._smokeFormats,
        ..._videoContainerFormats,
        ..._audioFormats,
      ];
    case 'smoke':
      return _smokeFormats;
    case 'video':
      return <_FormatCase>[..._smokeFormats, ..._videoContainerFormats];
    case 'audio':
      return _audioFormats;
  }
  throw ArgumentError.value(
    suite,
    'VLC_PLAYER_FORMAT_SUITE',
    'Use all, smoke, video, or audio.',
  );
}

bool _includesSubtitleCase(String suite) =>
    suite == 'all' || suite == 'smoke' || suite == 'video';

class _FormatCase {
  const _FormatCase({
    required this.name,
    this.assetPath,
    this.hlsPlaylistAssetPath,
    this.hlsSegmentAssetPath,
    this.expectsVideo = false,
    this.expectsAudio = false,
    this.subtitleAssetPath,
  }) : assert(
         assetPath != null ||
             (hlsPlaylistAssetPath != null && hlsSegmentAssetPath != null),
       );

  final String name;
  final String? assetPath;
  final String? hlsPlaylistAssetPath;
  final String? hlsSegmentAssetPath;
  final bool expectsVideo;
  final bool expectsAudio;
  final String? subtitleAssetPath;
}

Future<void> _runFormatCase(WidgetTester tester, _FormatCase format) async {
  final controller = VlcPlayerController(
    options: headlessPlayerOptions(requiresAudio: format.expectsAudio),
  );
  addTearDown(controller.dispose);

  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: Center(
          child: SizedBox(
            width: 240,
            height: 135,
            child: VlcPlayer(controller: controller),
          ),
        ),
      ),
    ),
  );

  await pumpUntil(
    tester,
    () => controller.isAttached,
    description: 'native player attachment for ${format.name}',
  );
  expect(controller.isAttached, isTrue);

  final sourceUri = await _materializeSource(format);
  await controller.setMedia(VlcMediaSource(uri: sourceUri), autoPlay: true);

  final subtitleAssetPath = format.subtitleAssetPath;
  if (subtitleAssetPath != null) {
    await controller.addSubtitle(await materializeAsset(subtitleAssetPath));
  }

  final value = await _waitForUsablePlayback(tester, controller, format.name);
  final info = await controller.getMediaInfo();

  expect(value.hasError, isFalse);
  if (format.expectsVideo) {
    expect(
      value.videoSize != null || info.videoTracks.isNotEmpty,
      isTrue,
      reason: '${format.name} should expose video metadata.',
    );
  }
  if (format.expectsAudio) {
    expect(
      info.audioTracks.isNotEmpty ||
          info.duration > Duration.zero ||
          value.duration > Duration.zero,
      isTrue,
      reason: '${format.name} should expose audio metadata or duration.',
    );
  }

  await controller.stop();
  await tester.pumpWidget(const SizedBox.shrink());
  await tester.pumpAndSettle(const Duration(milliseconds: 50));
}

Future<Uri> _materializeSource(_FormatCase format) async {
  final assetPath = format.assetPath;
  if (assetPath != null) {
    return materializeAsset(assetPath);
  }

  return materializeHlsFixture(
    segmentAssetPath: format.hlsSegmentAssetPath!,
    playlistAssetPath: format.hlsPlaylistAssetPath!,
  );
}

Future<VlcPlayerValue> _waitForUsablePlayback(
  WidgetTester tester,
  VlcPlayerController controller,
  String name,
) async {
  for (var attempt = 0; attempt < 80; attempt += 1) {
    await tester.pump(const Duration(milliseconds: 250));
    final value = controller.value;
    if (value.hasError) {
      fail('$name entered error state: ${value.error}');
    }
    if (_usableStates.contains(value.state) || value.isReady) {
      return value;
    }
  }
  fail('$name did not become playable. Last value: ${controller.value.state}');
}

const Set<VlcPlaybackState> _usableStates = <VlcPlaybackState>{
  VlcPlaybackState.playing,
  VlcPlaybackState.paused,
  VlcPlaybackState.stopped,
  VlcPlaybackState.ended,
};
