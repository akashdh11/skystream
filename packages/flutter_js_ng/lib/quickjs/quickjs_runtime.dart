import 'dart:convert';
import 'dart:ffi';
import 'dart:io';

import 'package:ffi/ffi.dart';
import 'package:flutter_js/flutter_js.dart';
import 'package:flutter_js/quickjs/utf8_null_terminated.dart';

import 'qjs_typedefs.dart';

final DynamicLibrary qjsDynamicLibrary = Platform.isAndroid
    ? DynamicLibrary.open("libfastdev_quickjs_runtime.so")
    : (Platform.isWindows
        ? DynamicLibrary.open('flutter_js_plugin.dll')
        : DynamicLibrary.process());

typedef FnBridgeCallback = Function(
    dynamic args); //String Function(String channel, String message);

final Map<String, FnBridgeCallback> mapJsBridge = {};

Pointer<JSValueConst> bridgeCallbackGlobalHandler(
  Pointer<JSContext> ctx,
  Pointer<Utf8NullTerminated> channelName,
  Pointer<Utf8NullTerminated> message,
) {
  final String channelNameStr = Utf8NullTerminated.fromUtf8(channelName);
  final String messageStr = Utf8NullTerminated.fromUtf8(message);

  if (mapJsBridge.containsKey(channelNameStr)) {
    String? result = 'NO RESULT YET';
    try {
      result = mapJsBridge[channelNameStr]!.call(jsonDecode(messageStr));
    } on Error catch (e) {
      result = e.toString();
      print('ERROR ------ $e');
    } on Exception catch (e) {
      result = e.toString();
      print('EXCEPTION ------ $e');
    }
    if (result == null) {
      final Pointer<JSValueConst> nullValue = calloc();
      QuickJsRuntime._jsGetNullValue(ctx, nullValue);
      return nullValue;
    } else {
      // The returned value has to reach JS as a *string literal*. Interpolating
      // it into single quotes breaks on every apostrophe, backslash, newline or
      // control character — which is most real-world HTML. jsonEncode produces
      // a literal that is valid JSON *and* valid JS, so the value survives
      // intact whatever it contains.
      return QuickJsRuntime.jsEval(ctx, jsonEncode(result)).rawResult;
    }
  }

  return QuickJsRuntime.jsEval(ctx,
          jsonEncode('No channel registered: ($channelNameStr) => $messageStr'))
      .rawResult;
}

Pointer<NativeFunction<ChannelCallback>>? consoleLogBridgeFunction;
Pointer<NativeFunction<ChannelCallback>>? setTimeoutBridgeFunction;
Pointer<NativeFunction<ChannelCallback>>? sendNativeBridgeFunction;

class QuickJsRuntime extends JavascriptRuntime {
  late Pointer<JSContext> _context;
  late Pointer<JSRuntime> _runtime;

  final String fileName;

  QuickJsRuntime(this.fileName) {
    _runtime = _jsNewRuntimeDartBridge();
    jsSetMaxStackSize(_runtime, 1024 * 1024);
    consoleLogBridgeFunction = Pointer.fromFunction<
        Pointer<JSValueConst> Function(
            Pointer<JSContext> ctx,
            Pointer<Utf8NullTerminated> channel,
            Pointer<Utf8NullTerminated> msg)>(bridgeCallbackGlobalHandler);
    setTimeoutBridgeFunction = Pointer.fromFunction<
        Pointer<JSValueConst> Function(
            Pointer<JSContext> ctx,
            Pointer<Utf8NullTerminated> channel,
            Pointer<Utf8NullTerminated> msg)>(bridgeCallbackGlobalHandler);
    sendNativeBridgeFunction = Pointer.fromFunction<
        Pointer<JSValueConst> Function(
            Pointer<JSContext> ctx,
            Pointer<Utf8NullTerminated> channel,
            Pointer<Utf8NullTerminated> msg)>(bridgeCallbackGlobalHandler);
    _context = _jsNewContext(
      _runtime,
      consoleLogBridgeFunction,
      setTimeoutBridgeFunction,
      sendNativeBridgeFunction,
    );

    init();
  }

  /// DLLEXPORT void jsSetMaxStackSize(JSRuntime *rt, size_t stack_size)
  final void Function(
    Pointer<JSRuntime>,
    int,
  ) jsSetMaxStackSize = qjsDynamicLibrary
      .lookup<
          NativeFunction<
              Void Function(
                Pointer<JSRuntime>,
                IntPtr,
              )>>('jsSetMaxStackSize')
      .asFunction();

  // NATIVE BRIDGE DECLARATIONS
  static final JSEvalWrapper _jsEvalWrapper = qjsDynamicLibrary
      .lookupFunction<JSEvalWrapperNative, JSEvalWrapper>('JSEvalWrapper');

  static final JS_NewRuntimeDartBridge _jsNewRuntimeDartBridge =
      qjsDynamicLibrary
          .lookup<NativeFunction<JS_NewRuntimeDartBridge>>(
            'JS_NewRuntimeDartBridge',
          )
          .asFunction();
  static final JS_NewContextFn _jsNewContext = qjsDynamicLibrary
      .lookup<NativeFunction<JS_NewContextFn>>('JS_NewContextDartBridge')
      .asFunction();

  static final JS_GetNullValue _jsGetNullValue = qjsDynamicLibrary
      .lookup<NativeFunction<JS_GetNullValue>>('JS_GetNullValue')
      .asFunction();

  static final JSExecutePendingJob _jsExecutePendingJob = qjsDynamicLibrary
      .lookupFunction<JSExecutePendingJobNative, JSExecutePendingJob>(
    'JS_ExecutePendingJob',
  );

  static final JSCallFunction1Arg _callJsFunction1Arg = qjsDynamicLibrary
      .lookupFunction<JSCallFunction1ArgNative, JSCallFunction1Arg>(
          'callJsFunction1Arg');

  static final JSGetTypeTag _jsGetTypeTag = qjsDynamicLibrary
      .lookupFunction<JSGetTypeTagNative, JSGetTypeTag>('getTypeTag');

  static final JSIsArray _jsIsArray = qjsDynamicLibrary
      .lookupFunction<JSIsArrayNative, JSIsArray>('JS_IsArrayDartWrapper');

  static final JSJSONStringify _jSJSONStringify =
      qjsDynamicLibrary.lookupFunction<JSJSONStringifyNative, JSJSONStringify>(
          'JS_JSONStringifyDartWrapper');
  // END NATIVE BRIDGE DECLARATIONS

  @override
  JsEvalResult callFunction(
    Pointer function,
    Pointer argument,
  ) {
    final Pointer result = calloc<JSValueConst>();
    final Pointer<Pointer<Utf8NullTerminated>> stringResult =
        calloc<Pointer<Utf8NullTerminated>>();
    final int operationResult = _callJsFunction1Arg(
        _context,
        function as Pointer<JSValueConst>,
        argument as Pointer<JSValueConst>,
        result as Pointer<JSValueConst>,
        stringResult);
    final String resultStr = Utf8NullTerminated.fromUtf8(stringResult.value);
    return JsEvalResult(
      resultStr,
      result,
      isError: operationResult == 0,
      isPromise: resultStr == '[object Promise]',
    );
  }

  @override
  void setInspectable(bool inspectable) {
    // Nothing to do.
  }

  static Type getTypeForJsValue(Pointer<JSValueConst> jsValue) {
    final int value = _jsGetTypeTag(jsValue);

    switch (value) {
      case JS_TAG_BOOL:
        return bool;
      case JS_TAG_NULL:
        return Null;
      case JS_TAG_INT:
        return int;
      case JS_TAG_STRING:
        return String;
      case JS_TAG_OBJECT:
        return Object;
      case JS_TAG_UNDEFINED:
        return Null;
      default:
        return Null;
    }
  }

  @override
  JsEvalResult evaluate(String js, {String? sourceUrl}) {
    return jsEval(_context, js);
  }

  static JsEvalResult jsEval(
    Pointer<JSContext> ctx,
    String js, {
    String fileName = 'nofile.js',
  }) {
    final Pointer<JSValueConst> result = calloc<JSValueConst>();
    final Pointer<Pointer<Utf8NullTerminated>> stringResult =
        calloc<Pointer<Utf8NullTerminated>>();
    final Pointer<Int32> errors = calloc<Int32>();
    _jsEvalWrapper(ctx, Utf8NullTerminated.toUtf8(js), js.length,
        Utf8NullTerminated.toUtf8(fileName), 0, errors, result, stringResult);

    final strResult = Utf8NullTerminated.fromUtf8(stringResult.value);
    return JsEvalResult(
      strResult,
      result,
      isError: errors.value == 1,
      isPromise: strResult == '[object Promise]',
    );
  }

  static T? convertToValue<T>(
      Pointer<JSContext> context, JsEvalResult evalResult) {
    final Type type = getTypeForJsValue(evalResult.rawResult);

    if (_jsIsArray(context, evalResult.rawResult) == 1) {
      final Pointer<JSValueConst> stringifiedValue = calloc();
      final Pointer<Pointer<Utf8NullTerminated>> stringResultPointer = calloc();
      _jSJSONStringify(
        context,
        evalResult.rawResult,
        stringifiedValue,
        stringResultPointer,
      );
      final stringResult =
          Utf8NullTerminated.fromUtf8(stringResultPointer.value);
      return jsonDecode(stringResult);
    }
    switch (type) {
      case int:
        return int.parse(evalResult.stringResult) as T;
      case bool:
        return (evalResult.stringResult == "true") as T;
      case String:
        return (evalResult.stringResult) as T;
      case Null:
        return null;
      case Object:
        final Pointer<JSValueConst> stringifiedValue = calloc<JSValueConst>();
        final Pointer<Pointer<Utf8NullTerminated>> stringResultPointer =
            calloc();

        _jSJSONStringify(
          context,
          evalResult.rawResult,
          stringifiedValue,
          stringResultPointer,
        );
        final stringResult =
            Utf8NullTerminated.fromUtf8(stringResultPointer.value);
        return jsonDecode(stringResult);
    }
    return null;
  }

  @override
  void dispose() {
    // Todo: free runtime and context
  }

  @override
  int executePendingJob() {
    final Pointer<JSContext> newContext = calloc<JSContext>();
    return _jsExecutePendingJob(_runtime, newContext);
  }

  @override
  String getEngineInstanceId() => _context.address.toString();

  @override
  void initChannelFunctions() {
    final sendMessageCreateFnResult = evaluate("""
        function sendMessage(channelName, message) {
          return FLUTTER_JS_NATIVE_BRIDGE_sendMessage.apply(globalThis, [channelName, message]);
        }
        sendMessage
      """);
    print('RESULT creating sendMessage function: $sendMessageCreateFnResult');
  }

  @override
  String jsonStringify(JsEvalResult jsValue) {
    final Pointer<JSValueConst> stringifiedValue = calloc();
    final Pointer<Pointer<Utf8NullTerminated>> stringResultPointer = calloc();
    _jSJSONStringify(
      _context,
      jsValue.rawResult,
      stringifiedValue,
      stringResultPointer,
    );
    final stringResult = Utf8NullTerminated.fromUtf8(stringResultPointer.value);
    return stringResult;
  }

  @override
  bool setupBridge(String channelName, void Function(dynamic args) fn) {
    mapJsBridge[channelName] = fn;
    return true;
  }

  @override
  T? convertValue<T>(JsEvalResult evalResult) {
    return convertToValue<T>(_context, evalResult)!;
  }

  @override
  Future<JsEvalResult> evaluateAsync(String code, {String? sourceUrl}) {
    return Future.value(evaluate(code));
  }
}
