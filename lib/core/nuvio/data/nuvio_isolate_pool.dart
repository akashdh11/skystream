import 'dart:async';
import 'dart:convert';
import 'dart:isolate';

import 'package:flutter/foundation.dart';

import 'nuvio_engine.dart';

/// Runs Nuvio plugins on worker isolates.
///
/// QuickJS evaluation is synchronous CPU work. Running it on the UI isolate
/// means a 1 MB bundle parse janks the app, and several scrapers at once take
/// turns on the same thread. The pool spreads them over real threads: the UI
/// stays responsive and slow providers stop starving the fast ones.
///
/// If an isolate cannot be spawned (rare, but the platform decides), the pool
/// falls back to running the plugin on the calling isolate, so plugin support
/// degrades in speed rather than disappearing.
class NuvioIsolatePool {
  NuvioIsolatePool({int size = 3}) : size = size < 1 ? 1 : size;

  /// Worker count. Three keeps memory and battery sane on a phone while still
  /// giving real parallelism; each worker takes several jobs concurrently
  /// because scrapers spend most of their time waiting on the network.
  final int size;

  /// Slots hold the *future* worker so that eight jobs starting at the same
  /// moment reserve three isolates, not eight.
  final List<Future<_Worker>> _slots = [];
  var _disposed = false;
  var _spawnFailed = false;

  /// Runs a plugin and returns the raw JSON document it produced.
  Future<String> execute(NuvioEngineRequest request) async {
    if (_disposed) {
      throw StateError('Nuvio isolate pool has been disposed');
    }
    if (!_spawnFailed) {
      try {
        final worker = await _leastBusyWorker();
        return await worker.run(request);
      } catch (error) {
        if (kDebugMode) debugPrint('[Nuvio] worker failed: $error');
        // One bad worker shouldn't take plugin support with it.
        if (error is _WorkerSpawnException) _spawnFailed = true;
      }
    }
    return NuvioEngine.execute(request);
  }

  Future<_Worker> _leastBusyWorker() async {
    if (_slots.length < size) {
      final slot = _Worker.spawn();
      _slots.add(slot);
      try {
        return await slot;
      } catch (error) {
        _slots.remove(slot);
        rethrow;
      }
    }
    final workers = await Future.wait(_slots);
    workers.sort((a, b) => a.pending.compareTo(b.pending));
    return workers.first;
  }

  /// How many workers are alive; used by tests.
  @visibleForTesting
  int get workerCount => _slots.length;

  void dispose() {
    _disposed = true;
    for (final slot in _slots) {
      unawaited(
        slot.then((worker) => worker.dispose()).catchError((Object _) {}),
      );
    }
    _slots.clear();
  }
}

class _WorkerSpawnException implements Exception {
  final Object cause;
  _WorkerSpawnException(this.cause);
  @override
  String toString() => 'Could not start a plugin worker: $cause';
}

class _Worker {
  _Worker._(this._responses);

  final ReceivePort _responses;
  final Map<int, Completer<String>> _inflight = {};
  Isolate? _isolate;
  SendPort? _commands;
  int _nextId = 0;

  int get pending => _inflight.length;

  static Future<_Worker> spawn() async {
    final responses = ReceivePort();
    final worker = _Worker._(responses);
    final ready = Completer<SendPort>();

    // One subscription for the whole life of the worker: the first message is
    // the worker's command port, everything after that is a job result.
    responses.listen((dynamic message) {
      if (!ready.isCompleted && message is SendPort) {
        ready.complete(message);
        return;
      }
      worker._handleResponse(message);
    });

    try {
      worker._isolate = await Isolate.spawn(
        _workerMain,
        responses.sendPort,
        errorsAreFatal: false,
        debugName: 'nuvio-plugin-worker',
      );
      worker._commands = await ready.future.timeout(
        const Duration(seconds: 10),
      );
    } catch (error) {
      worker.dispose();
      throw _WorkerSpawnException(error);
    }
    return worker;
  }

  void _handleResponse(dynamic message) {
    if (message is! Map) return;
    final id = (message['id'] as num?)?.toInt();
    if (id == null) return;
    final completer = _inflight.remove(id);
    if (completer == null || completer.isCompleted) return;
    if (message['ok'] == true) {
      completer.complete(message['json']?.toString() ?? '{}');
    } else {
      completer.complete(
        jsonEncode({'error': message['error']?.toString() ?? 'worker error'}),
      );
    }
  }

  Future<String> run(NuvioEngineRequest request) {
    final commands = _commands;
    if (commands == null) {
      throw _WorkerSpawnException('worker is not ready');
    }
    final id = _nextId++;
    final completer = Completer<String>();
    _inflight[id] = completer;
    commands.send({'id': id, 'request': request.toMap()});
    // The engine has its own budget; this is the backstop for a wedged worker.
    return completer.future.timeout(
      Duration(milliseconds: request.timeoutMs + 15000),
      onTimeout: () {
        _inflight.remove(id);
        return jsonEncode({'error': 'Plugin worker did not answer'});
      },
    );
  }

  void dispose() {
    for (final completer in _inflight.values) {
      if (!completer.isCompleted) {
        completer.complete(jsonEncode({'error': 'cancelled'}));
      }
    }
    _inflight.clear();
    _responses.close();
    _isolate?.kill(priority: Isolate.immediate);
    _isolate = null;
  }
}

/// Worker entry point: receives jobs, runs the engine, sends JSON back.
///
/// Jobs are started without awaiting so one worker can hold several scrapers
/// at once — they are network-bound most of the time.
void _workerMain(SendPort initialReply) {
  final commands = ReceivePort();
  initialReply.send(commands.sendPort);

  commands.listen((dynamic message) {
    if (message is! Map) return;
    final id = message['id'];
    final raw = message['request'];
    if (id == null || raw is! Map) return;

    unawaited(() async {
      try {
        final json = await NuvioEngine.execute(NuvioEngineRequest.fromMap(raw));
        initialReply.send({'id': id, 'ok': true, 'json': json});
      } catch (error) {
        initialReply.send({'id': id, 'ok': false, 'error': error.toString()});
      }
    }());
  });
}
