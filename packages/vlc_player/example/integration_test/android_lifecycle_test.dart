import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:vlc_player/vlc_player.dart';

import 'test_support.dart';

const String _assetRoot = 'assets/format_fixtures';
const String _hostControlAddress = String.fromEnvironment(
  'VLC_PLAYER_ANDROID_LIFECYCLE_HOST',
  defaultValue: '10.0.2.2',
);
const int _hostControlPort = int.fromEnvironment(
  'VLC_PLAYER_ANDROID_LIFECYCLE_PORT',
  defaultValue: 45937,
);

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'Android restores video output after app background',
    (WidgetTester tester) async {
      if (!Platform.isAndroid) {
        return;
      }

      final controller = VlcPlayerController(options: headlessPlayerOptions());
      addTearDown(controller.dispose);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            backgroundColor: Colors.black,
            body: SizedBox.expand(child: VlcPlayer(controller: controller)),
          ),
        ),
      );

      await pumpUntil(
        tester,
        () => controller.isAttached,
        description: 'native player attachment',
      );

      final sourceUri = await materializeAsset(
        '$_assetRoot/video_lifecycle.mp4',
      );
      await controller.setMedia(VlcMediaSource(uri: sourceUri), autoPlay: true);
      await _waitForUsablePlayback(tester, controller);
      await _waitForVisibleScreenVideo(
        tester,
        controller,
        description: 'initial video frame',
      );

      await _requestAndroidBackgroundResume();
      await pumpUntil(
        tester,
        () => controller.isAttached,
        description: 'native player attachment after resume',
      );
      await controller.play();
      await _waitForUsablePlayback(tester, controller);
      await _waitForVisibleScreenVideo(
        tester,
        controller,
        description: 'video frame after resume',
        restartWhenEnded: true,
      );

      await controller.stop();
      await tester.pumpWidget(const SizedBox.shrink());
      await pumpNavigation(tester);
    },
    timeout: const Timeout(Duration(minutes: 4)),
  );
}

Future<void> _waitForUsablePlayback(
  WidgetTester tester,
  VlcPlayerController controller,
) async {
  for (var attempt = 0; attempt < 80; attempt += 1) {
    await tester.pump(const Duration(milliseconds: 250));
    final value = controller.value;
    if (value.hasError) {
      fail('Playback entered error state: ${value.error}');
    }
    if (value.state == VlcPlaybackState.playing || value.videoSize != null) {
      return;
    }
    if (value.state == VlcPlaybackState.stopped ||
        value.state == VlcPlaybackState.ended) {
      fail('Playback ended before it became visible. Last value: $value');
    }
  }
  fail('Playback did not become usable. Last value: ${controller.value.state}');
}

Future<void> _waitForVisibleScreenVideo(
  WidgetTester tester,
  VlcPlayerController controller, {
  required String description,
  bool restartWhenEnded = false,
}) async {
  Object? lastScreenshotError;
  for (var attempt = 0; attempt < 80; attempt += 1) {
    await tester.pump(const Duration(milliseconds: 250));
    final value = controller.value;
    if (value.hasError) {
      fail('$description entered error state: ${value.error}');
    }
    if (value.state == VlcPlaybackState.stopped ||
        value.state == VlcPlaybackState.ended) {
      if (!restartWhenEnded) {
        fail('$description ended before a visible frame was captured.');
      }
      await controller.seekTo(Duration.zero);
      await controller.play();
      continue;
    }
    try {
      final screenshot = await _requestAndroidScreenshot();
      if (await _hasVisibleVideoPixels(screenshot)) {
        return;
      }
    } catch (error) {
      lastScreenshotError = error;
    }
  }
  fail(
    '$description stayed black. '
    'Last player state: ${controller.value.state}. '
    'Last screenshot error: $lastScreenshotError',
  );
}

Future<bool> _hasVisibleVideoPixels(Uint8List pngBytes) async {
  final codec = await ui.instantiateImageCodec(pngBytes);
  try {
    final frame = await codec.getNextFrame();
    final image = frame.image;
    try {
      final bytes = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
      if (bytes == null) {
        return false;
      }
      final pixels = bytes.buffer.asUint8List();
      var visiblePixels = 0;
      final startX = (image.width * 0.25).round();
      final endX = (image.width * 0.75).round();
      final startY = (image.height * 0.4).round();
      final endY = (image.height * 0.6).round();
      final pixelCount = (endX - startX) * (endY - startY);
      for (var y = startY; y < endY; y += 1) {
        for (var x = startX; x < endX; x += 1) {
          final offset = (y * image.width + x) * 4;
          final red = pixels[offset];
          final green = pixels[offset + 1];
          final blue = pixels[offset + 2];
          final maxChannel = math.max(red, math.max(green, blue));
          if (maxChannel > 40) {
            visiblePixels += 1;
          }
        }
      }
      return visiblePixels / pixelCount > 0.2;
    } finally {
      image.dispose();
    }
  } finally {
    codec.dispose();
  }
}

Future<Uint8List> _requestAndroidScreenshot() async {
  final uri = _hostControlUri('/android-lifecycle/screenshot');
  final client = HttpClient();
  try {
    final request = await client.getUrl(uri);
    final response = await request.close().timeout(const Duration(seconds: 10));
    final builder = BytesBuilder(copy: false);
    await for (final chunk in response) {
      builder.add(chunk);
    }
    final bytes = builder.takeBytes();
    if (response.statusCode != HttpStatus.ok) {
      throw StateError(
        'HTTP ${response.statusCode}: ${utf8.decode(bytes, allowMalformed: true)}',
      );
    }
    return bytes;
  } finally {
    client.close(force: true);
  }
}

Future<void> _requestAndroidBackgroundResume() async {
  final uri = _hostControlUri('/android-lifecycle/background-resume');
  final client = HttpClient();
  try {
    Object? lastError;
    for (var attempt = 0; attempt < 40; attempt += 1) {
      try {
        final request = await client.postUrl(uri);
        final response = await request.close().timeout(
          const Duration(seconds: 20),
        );
        final body = await response.transform(utf8.decoder).join();
        if (response.statusCode == HttpStatus.ok) {
          return;
        }
        lastError = 'HTTP ${response.statusCode}: $body';
      } catch (error) {
        lastError = error;
      }
      await Future<void>.delayed(const Duration(milliseconds: 250));
    }
    fail('Host lifecycle driver did not respond: $lastError');
  } finally {
    client.close(force: true);
  }
}

Uri _hostControlUri(String path) {
  return Uri(
    scheme: 'http',
    host: _hostControlAddress,
    port: _hostControlPort,
    path: path,
  );
}
