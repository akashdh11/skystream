import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:integration_test/integration_test_driver.dart';

const int _defaultPort = 45937;
const String _activityName = 'com.example.vlc_player_example/.MainActivity';

Future<void> main() async {
  final port =
      int.tryParse(
        Platform.environment['VLC_PLAYER_ANDROID_LIFECYCLE_PORT'] ?? '',
      ) ??
      _defaultPort;
  final server = await HttpServer.bind(
    InternetAddress.loopbackIPv4,
    port,
    shared: true,
  );
  server.listen(_handleRequest);
  await integrationDriver();
}

Future<void> _handleRequest(HttpRequest request) async {
  if (request.method == 'GET' &&
      request.uri.path == '/android-lifecycle/screenshot') {
    await _handleScreenshot(request);
    return;
  }

  if (request.method == 'POST' &&
      request.uri.path == '/android-lifecycle/background-resume') {
    await _handleBackgroundResume(request);
    return;
  }

  request.response.statusCode = HttpStatus.notFound;
  await request.response.close();
}

Future<void> _handleBackgroundResume(HttpRequest request) async {
  await _writeResponse(request, () async {
    await _runAdb(<String>['shell', 'input', 'keyevent', 'KEYCODE_HOME']);
    await Future<void>.delayed(const Duration(seconds: 2));
    await _runAdb(<String>['shell', 'am', 'start', '-W', '-n', _activityName]);
    await Future<void>.delayed(const Duration(seconds: 1));
    request.response.statusCode = HttpStatus.ok;
    request.response.write('ok');
  });
}

Future<void> _handleScreenshot(HttpRequest request) async {
  await _writeResponse(request, () async {
    final screenshot = await _runAdbForBytes(<String>[
      'exec-out',
      'screencap',
      '-p',
    ]);
    request.response.statusCode = HttpStatus.ok;
    request.response.headers.contentType = ContentType('image', 'png');
    request.response.add(screenshot);
  });
}

Future<void> _writeResponse(
  HttpRequest request,
  Future<void> Function() writeSuccess,
) async {
  try {
    await writeSuccess();
  } catch (error) {
    request.response.statusCode = HttpStatus.internalServerError;
    request.response.write(error.toString());
  } finally {
    await request.response.close();
  }
}

Future<void> _runAdb(List<String> args) async {
  final result = await _runAdbProcess(args);
  if (result.exitCode != 0) {
    throw StateError(
      '${_adbExecutable()} ${args.join(' ')} failed with exit code '
      '${result.exitCode}\n${result.stdout}\n${result.stderr}',
    );
  }
}

Future<List<int>> _runAdbForBytes(List<String> args) async {
  final result = await _runAdbProcess(args, stdoutEncoding: null);
  if (result.exitCode != 0) {
    throw StateError(
      '${_adbExecutable()} ${args.join(' ')} failed with exit code '
      '${result.exitCode}\n${result.stderr}',
    );
  }
  return result.stdout as List<int>;
}

Future<ProcessResult> _runAdbProcess(
  List<String> args, {
  Encoding? stdoutEncoding = utf8,
}) {
  final serial = Platform.environment['ANDROID_SERIAL'] ?? 'emulator-5554';
  return Process.run(
    _adbExecutable(),
    <String>['-s', serial, ...args],
    stdoutEncoding: stdoutEncoding,
    stderrEncoding: utf8,
  );
}

String _adbExecutable() => Platform.environment['ADB'] ?? 'adb';
