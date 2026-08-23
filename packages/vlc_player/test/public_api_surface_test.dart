import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('package library exports only the supported public entry points', () {
    final library = _fileText('lib/vlc_player.dart');

    expect(library, contains("export 'src/vlc_player_controller.dart';"));
    expect(library, contains("export 'src/vlc_player.dart';"));
    expect(library, contains("export 'src/vlc_media_source.dart';"));
    expect(library, contains("export 'src/vlc_media_stats.dart';"));
    expect(library, contains("export 'src/vlc_player_value.dart';"));
    expect(library, contains("export 'src/vlc_media_info.dart';"));
    expect(library, contains("export 'src/vlc_player_error.dart';"));
    expect(
      library,
      isNot(contains("export 'src/vlc_player_controller_internals.dart';")),
    );
    expect(library, isNot(contains("export 'src/texture")));
    expect(library, isNot(contains("export 'src/method_channel")));
  });

  test('controller constructor exposes only the supported public API', () {
    final controllerClass = _classBlock(
      _fileText('lib/src/vlc_player_controller.dart'),
      'VlcPlayerController',
    );
    final constructor = _factoryConstructorBlock(controllerClass);

    expect(constructor, contains('VlcMediaSource? mediaSource'));
    expect(constructor, contains('bool autoPlay = false'));
    expect(constructor, contains('List<String> options = const <String>[]'));
    expect(constructor, contains('Duration? eventThrottleInterval'));
    expect(constructor, isNot(contains('Uri? source')));
    expect(constructor, isNot(contains('String source')));
    expect(constructor, isNot(contains('Map<String, String> httpHeaders')));
  });

  test(
    'controller public surface excludes widget and method-channel internals',
    () {
      final controllerClass = _classBlock(
        _fileText('lib/src/vlc_player_controller.dart'),
        'VlcPlayerController',
      );

      expect(controllerClass, contains('Future<void> setMedia('));
      expect(controllerClass, contains('Future<void> setPlaylist('));
      expect(
        controllerClass,
        contains('Future<VlcMediaStats> getMediaStats()'),
      );
      expect(controllerClass, isNot(contains('setSource(')));
      expect(controllerClass, isNot(contains('MethodChannel')));
      expect(controllerClass, isNot(contains('viewType')));
      expect(controllerClass, isNot(contains(RegExp(r'\battach\('))));
      expect(controllerClass, isNot(contains(RegExp(r'\bdetach\('))));
      expect(controllerClass, isNot(contains('attachTexturePlayer')));
    },
  );

  test('README API reference documents the current controller surface', () {
    final readme = _fileText('README.md');
    final controllerReference = _section(
      readme,
      '### VlcPlayerController',
      '### VlcMediaSource',
    );

    expect(readme, contains('## API stability'));
    expect(readme, contains('## Migrating from 1.x or 0.8.x'));
    expect(readme, contains('## Migrating from 0.7.21 or earlier'));
    expect(controllerReference, contains('mediaSource'));
    expect(controllerReference, contains('setMedia(VlcMediaSource source'));
    expect(controllerReference, isNot(contains('setSource(')));
    expect(controllerReference, isNot(contains('Uri? source')));
    expect(controllerReference, isNot(contains('httpHeaders` compatibility')));
  });

  test('widget-to-controller internals stay statically typed', () {
    final player = _fileText('lib/src/vlc_player.dart');
    final harness = _fileText('test/vlc_method_channel_harness.dart');

    expect(player, contains('VlcPlayerControllerInternals'));
    expect(harness, contains('VlcPlayerControllerInternals'));
    expect(player, isNot(contains('as dynamic')));
    expect(harness, isNot(contains('as dynamic')));
  });
}

String _fileText(String path) => File(path).readAsStringSync();

String _classBlock(String source, String className) {
  final declaration = RegExp(
    '\\bclass\\s+$className\\b|\\babstract\\s+class\\s+$className\\b',
  ).firstMatch(source);
  if (declaration == null) {
    fail('Could not find class $className.');
  }

  final start = source.indexOf('{', declaration.start);
  if (start == -1) {
    fail('Could not find opening brace for class $className.');
  }

  var depth = 0;
  for (var index = start; index < source.length; index += 1) {
    final char = source.codeUnitAt(index);
    if (char == 0x7b) {
      depth += 1;
    } else if (char == 0x7d) {
      depth -= 1;
      if (depth == 0) {
        return source.substring(declaration.start, index + 1);
      }
    }
  }

  fail('Could not find closing brace for class $className.');
}

String _factoryConstructorBlock(String controllerClass) {
  final declaration = controllerClass.indexOf('factory VlcPlayerController');
  if (declaration == -1) {
    fail('Could not find VlcPlayerController factory constructor.');
  }

  final bodyStart = controllerClass.indexOf('}) {', declaration);
  if (bodyStart == -1) {
    fail('Could not find VlcPlayerController factory constructor body.');
  }

  return controllerClass.substring(declaration, bodyStart + 1);
}

String _section(String text, String startHeading, String endHeading) {
  final start = text.indexOf(startHeading);
  if (start == -1) {
    fail('Could not find section $startHeading.');
  }
  final end = text.indexOf(endHeading, start + startHeading.length);
  if (end == -1) {
    fail('Could not find section boundary $endHeading.');
  }
  return text.substring(start, end);
}
