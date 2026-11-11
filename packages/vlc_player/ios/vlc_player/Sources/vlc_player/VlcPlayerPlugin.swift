import CoreMedia
import Flutter
import MobileVLCKit
import UIKit

public class VlcPlayerPlugin: NSObject, FlutterPlugin {
  private let messenger: FlutterBinaryMessenger
  private let textures: FlutterTextureRegistry
  private let methodChannel: FlutterMethodChannel
  private var players: [Int64: VlcPlayerPlatformView] = [:]
  private let systemVolume = VlcSystemVolume()
  private var systemVolumeChannel: FlutterEventChannel?

  /// Texture players get their ids from here, counting down from -1.
  ///
  /// Platform-view players are keyed by the id Flutter assigned their view,
  /// which is always non-negative, so the two id spaces cannot collide even
  /// though a host is free to mix both renderers.
  private var nextTextureViewId: Int64 = -1

  public static func register(with registrar: FlutterPluginRegistrar) {
    let messenger = registrar.messenger()
    let instance = VlcPlayerPlugin(binaryMessenger: messenger, textures: registrar.textures())
    let factory = VlcPlayerViewFactory(messenger: messenger) { [weak instance] viewId, player in
      instance?.players.removeValue(forKey: viewId)?.dispose()
      instance?.players[viewId] = player
    }

    registrar.addMethodCallDelegate(instance, channel: instance.methodChannel)
    registrar.register(factory, withId: "plugins.lingjhf.com/vlc_player/view")
    let systemVolumeChannel = FlutterEventChannel(name: "vlc_player/system_volume", binaryMessenger: messenger)
    systemVolumeChannel.setStreamHandler(instance.systemVolume)
    instance.systemVolumeChannel = systemVolumeChannel
  }

  init(binaryMessenger: FlutterBinaryMessenger, textures: FlutterTextureRegistry) {
    messenger = binaryMessenger
    self.textures = textures
    methodChannel = FlutterMethodChannel(name: "vlc_player", binaryMessenger: binaryMessenger)
    super.init()
  }

  public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    // Deliberately ahead of the viewId guard: `create` is the call that mints
    // one, so it is the only method that arrives without it.
    if call.method == "create" {
      createTexturePlayer(arguments: call.arguments as? [String: Any] ?? [:], result: result)
      return
    }
    // The device's, not a player's: they name none.
    if handleDevice(call, result: result) {
      return
    }

    guard let arguments = call.arguments as? [String: Any],
          let viewId = Self.int64Value(arguments["viewId"]) else {
      result(FlutterError(code: "invalid_args", message: "A valid viewId is required.", details: nil))
      return
    }

    if call.method == "dispose" {
      disposePlayer(viewId: viewId, result: result)
      return
    }

    guard let player = players[viewId] else {
      result(FlutterError(code: "player_not_found", message: "No vlc_player player exists for viewId \(viewId).", details: nil))
      return
    }

    DispatchQueue.main.async {
      self.handle(call.method, arguments: arguments, player: player, result: result)
    }
  }

  /// The device's volume and brightness. True when [call] was one of theirs.
  private func handleDevice(_ call: FlutterMethodCall, result: @escaping FlutterResult) -> Bool {
    let arguments = call.arguments as? [String: Any] ?? [:]
    let level = (arguments["level"] as? NSNumber)?.doubleValue
    switch call.method {
    case "getSystemVolume":
      VlcSystemVolume.read { level in
        result(level)
      }
    case "setSystemVolume":
      guard let level = level else {
        result(FlutterError(code: "invalid_args", message: "A level is required.", details: nil))
        return true
      }
      VlcSystemVolume.setLevel(level)
      // The system slider takes any level.
      result(min(max(level, 0), 1))
    case "setPlayerShown":
      VlcSystemVolume.setPlayerShown(arguments["shown"] as? Bool ?? false)
      result(nil)
    case "isSystemVolumeFixed":
      result(false)
    case "getScreenBrightness":
      result(VlcScreenBrightness.shared.level())
    case "setScreenBrightness":
      guard let level = level else {
        result(FlutterError(code: "invalid_args", message: "A level is required.", details: nil))
        return true
      }
      VlcScreenBrightness.shared.set(level)
      result(nil)
    case "resetScreenBrightness":
      VlcScreenBrightness.shared.reset()
      result(nil)
    default:
      return false
    }
    return true
  }

  private func handle(
    _ method: String,
    arguments: [String: Any],
    player: VlcPlayerPlatformView,
    result: @escaping FlutterResult
  ) {
    guard !player.isDisposed else {
      result(Self.disposedError())
      return
    }

    switch method {
    case "setSource":
      guard let uri = arguments["uri"] as? String, !uri.isEmpty else {
        result(FlutterError(code: "invalid_args", message: "A non-empty uri is required.", details: nil))
        return
      }
      let autoPlay = arguments["autoPlay"] as? Bool ?? false
      let httpHeaders = arguments["httpHeaders"] as? [String: String] ?? [:]
      let mediaOptions = arguments["mediaOptions"] as? [String] ?? []
      let startPosition = Self.intValue(arguments["startPosition"]) ?? 0
      guard startPosition >= 0 else {
        result(FlutterError(code: "invalid_args", message: "A non-negative startPosition is required.", details: nil))
        return
      }
      player.setSource(
        uri,
        httpHeaders: httpHeaders,
        mediaOptions: mediaOptions,
        startPosition: startPosition,
        keepPicture: arguments["keepPicture"] as? Bool ?? false,
        autoPlay: autoPlay,
        result: result
      )
    case "play":
      player.play()
      result(nil)
    case "pause":
      player.pause()
      result(nil)
    case "stop":
      player.stop()
      result(nil)
    case "seekTo":
      guard let position = Self.intValue(arguments["position"]), position >= 0 else {
        result(FlutterError(code: "invalid_args", message: "A non-negative position is required.", details: nil))
        return
      }
      player.seekTo(milliseconds: position)
      result(nil)
    case "seekToFraction":
      guard let fraction = Self.doubleValue(arguments["fraction"]), fraction.isFinite, fraction >= 0, fraction <= 1 else {
        result(FlutterError(code: "invalid_args", message: "A fraction within 0..1 is required.", details: nil))
        return
      }
      player.seekToFraction(fraction)
      result(nil)
    case "setVolume":
      guard let volume = Self.intValue(arguments["volume"]) else {
        result(FlutterError(code: "invalid_args", message: "A volume value is required.", details: nil))
        return
      }
      player.setVolume(volume)
      result(nil)
    case "setPlaybackSpeed":
      guard let speed = Self.doubleValue(arguments["speed"]), speed.isFinite && speed > 0 else {
        result(FlutterError(code: "invalid_args", message: "A finite positive playback speed is required.", details: nil))
        return
      }
      player.setPlaybackSpeed(speed)
      result(nil)
    case "setAudioDelay":
      guard let delay = Self.intValue(arguments["delay"]) else {
        result(FlutterError(code: "invalid_args", message: "An audio delay value is required.", details: nil))
        return
      }
      player.setAudioDelay(delay)
      result(nil)
    case "setSubtitleLook":
      guard let textScale = Self.intValue(arguments["textScale"]),
            let color = Self.intValue(arguments["color"]),
            let backgroundColor = Self.intValue(arguments["backgroundColor"]),
            let backgroundOpacity = Self.intValue(arguments["backgroundOpacity"]),
            let outlineThickness = Self.intValue(arguments["outlineThickness"]),
            let raise = (arguments["raise"] as? NSNumber)?.doubleValue else {
        result(FlutterError(code: "invalid_args", message: "Every subtitle look value is required.", details: nil))
        return
      }
      result(player.setSubtitleLook(
        textScale: textScale,
        color: color,
        backgroundColor: backgroundColor,
        backgroundOpacity: backgroundOpacity,
        outlineThickness: outlineThickness,
        raise: raise))
    case "setSubtitleDelay":
      guard let delay = Self.intValue(arguments["delay"]) else {
        result(FlutterError(code: "invalid_args", message: "A subtitle delay value is required.", details: nil))
        return
      }
      player.setSubtitleDelay(delay)
      result(nil)
    case "takeSnapshot":
      let rawWidth = Self.intValue(arguments["width"])
      let rawHeight = Self.intValue(arguments["height"])
      if let rawWidth = rawWidth, rawWidth <= 0 {
        result(FlutterError(code: "invalid_args", message: "Snapshot dimensions must be positive.", details: nil))
        return
      }
      if let rawHeight = rawHeight, rawHeight <= 0 {
        result(FlutterError(code: "invalid_args", message: "Snapshot dimensions must be positive.", details: nil))
        return
      }
      let width = rawWidth ?? 0
      let height = rawHeight ?? 0
      player.takeSnapshot(width: width, height: height, result: result)
    case "getAudioTracks":
      result(player.getAudioTracks())
    case "setAudioTrack":
      guard let id = Self.intValue(arguments["id"]), id >= 0 else {
        result(FlutterError(code: "invalid_args", message: "A non-negative audio track id is required.", details: nil))
        return
      }
      guard player.setAudioTrack(id) else {
        result(FlutterError(code: "track_not_found", message: "Audio track \(id) was not found.", details: nil))
        return
      }
      result(nil)
    case "getSubtitleTracks":
      result(player.getSubtitleTracks())
    case "setSubtitleTrack":
      guard let id = Self.intValue(arguments["id"]), id >= 0 else {
        result(FlutterError(code: "invalid_args", message: "A non-negative subtitle track id is required.", details: nil))
        return
      }
      guard player.setSubtitleTrack(id) else {
        result(FlutterError(code: "track_not_found", message: "Subtitle track \(id) was not found.", details: nil))
        return
      }
      result(nil)
    case "disableSubtitle":
      player.disableSubtitle()
      result(nil)
    case "addSubtitle":
      guard let uri = arguments["uri"] as? String, !uri.isEmpty else {
        result(FlutterError(code: "invalid_args", message: "A non-empty subtitle uri is required.", details: nil))
        return
      }
      player.addSubtitle(uri, result: result)
    case "setFit":
      guard let fit = arguments["fit"] as? String else {
        result(FlutterError(code: "invalid_args", message: "A fit value is required.", details: nil))
        return
      }
      player.setFit(fit)
      result(nil)
    case "getMediaInfo":
      result(player.getMediaInfo())
    case "getMediaStats":
      result(player.getMediaStats())
    case "startPictureInPicture":
      result(player.startPictureInPicture(sourceRect: Self.pictureInPictureSourceRect(arguments)))
    case "stopPictureInPicture":
      player.stopPictureInPicture()
      result(nil)
    default:
      result(FlutterMethodNotImplemented)
    }
  }

  /// Builds a texture-backed player and hands Dart both ids it needs.
  ///
  /// Mirrors the macOS plugin's `create`: the widget has no platform view to
  /// wait on, so the reply carries the viewId every later call is keyed by and
  /// the textureId the `Texture` widget renders.
  private func createTexturePlayer(arguments: [String: Any], result: @escaping FlutterResult) {
    let create = {
      let options = arguments["options"] as? [String] ?? []
      let viewId = self.nextTextureViewId
      self.nextTextureViewId -= 1

      let player = VlcPlayerPlatformView(
        viewId: viewId,
        messenger: self.messenger,
        options: options,
        target: .texture
      )
      guard let renderer = player.textureRenderer else {
        player.dispose()
        result(FlutterError(code: "create_failed", message: "Unable to attach a vlc_player texture.", details: nil))
        return
      }

      let textureId = self.textures.register(renderer)
      renderer.onFrameAvailable = { [weak self] in
        self?.textures.textureFrameAvailable(textureId)
      }
      player.textureId = textureId
      self.players[viewId] = player
      result(["viewId": viewId, "textureId": textureId])
    }
    if Thread.isMainThread {
      create()
    } else {
      DispatchQueue.main.async(execute: create)
    }
  }

  private func disposePlayer(viewId: Int64, result: FlutterResult? = nil) {
    let dispose = {
      let player = self.players.removeValue(forKey: viewId)
      // Before dispose(), so the engine stops asking a detached renderer for
      // frames rather than after it has already been silenced.
      if let textureId = player?.textureId {
        self.textures.unregisterTexture(textureId)
      }
      player?.dispose()
      result?(nil)
    }
    if Thread.isMainThread {
      dispose()
    } else {
      DispatchQueue.main.async(execute: dispose)
    }
  }

  private static func disposedError() -> FlutterError {
    return FlutterError(code: "disposed", message: "The vlc_player has been disposed.", details: nil)
  }

  private static func int64Value(_ value: Any?) -> Int64? {
    if let number = value as? NSNumber {
      return number.int64Value
    }
    return value as? Int64
  }

  private static func intValue(_ value: Any?) -> Int? {
    if let number = value as? NSNumber {
      return number.intValue
    }
    return value as? Int
  }

  private static func doubleValue(_ value: Any?) -> Double? {
    if let number = value as? NSNumber {
      return number.doubleValue
    }
    return value as? Double
  }

  /// The PiP source rect Dart sends (the video picture's on-screen frame),
  /// or nil when it sends none or a degenerate one. The PiP controller
  /// falls back to the window's bounds for nil, so a bad rect can never
  /// strand the window on the 1x1 host that never opened it.
  private static func pictureInPictureSourceRect(
    _ arguments: [String: Any]
  ) -> CGRect? {
    guard let x = doubleValue(arguments["x"]),
          let y = doubleValue(arguments["y"]),
          let width = doubleValue(arguments["width"]),
          let height = doubleValue(arguments["height"]),
          x.isFinite, y.isFinite, width.isFinite, height.isFinite,
          width > 0, height > 0 else {
      return nil
    }
    return CGRect(x: x, y: y, width: width, height: height)
  }
}

final class VlcPlayerViewFactory: NSObject, FlutterPlatformViewFactory {
  private let messenger: FlutterBinaryMessenger
  private let onCreate: (Int64, VlcPlayerPlatformView) -> Void

  init(
    messenger: FlutterBinaryMessenger,
    onCreate: @escaping (Int64, VlcPlayerPlatformView) -> Void
  ) {
    self.messenger = messenger
    self.onCreate = onCreate
    super.init()
  }

  func create(
    withFrame frame: CGRect,
    viewIdentifier viewId: Int64,
    arguments args: Any?
  ) -> FlutterPlatformView {
    let options = (args as? [String: Any])?["options"] as? [String] ?? []
    let fit = (args as? [String: Any])?["fit"] as? String ?? "contain"
    // The factory owns the view it has to hand back, so the player never has
    // to expose an optional one for the texture case to leave nil.
    let container = VlcPlayerContainerView(frame: frame)
    let player = VlcPlayerPlatformView(
      viewId: viewId,
      messenger: messenger,
      options: options,
      target: .uiKitView(container, fit: fit)
    )
    onCreate(viewId, player)
    return container
  }

  func createArgsCodec() -> FlutterMessageCodec & NSObjectProtocol {
    return FlutterStandardMessageCodec.sharedInstance()
  }
}

/// Where a player puts its pixels.
///
/// iOS supports both. The texture is the default because a UiKitView makes the
/// embedder composite every Flutter widget drawn above the video into its own
/// overlay layer - the defect class the macOS AppKitView showed on hardware.
/// See `VlcPlayerConfig.darwinRenderer`.
enum VlcRenderTarget {
  case uiKitView(VlcPlayerContainerView, fit: String)
  case texture
}

final class VlcPlayerPlatformView: NSObject, VLCMediaPlayerDelegate {
  /// The registered Flutter texture id, set by the plugin after it registers
  /// `textureRenderer`. Nil for view-backed players.
  var textureId: Int64?

  private let renderTarget: VlcRenderTarget
  private(set) var textureRenderer: VlcTextureRenderer?
  /// libVLC's own events, the held picture and the refused-seek log, which
  /// VLCKit's delegate doesn't carry; moves with the player (replacePlayer).
  private var events: VlcPlayerEvents?
  /// Nil once disposed: dispose() hands the last reference to releaseLater.
  /// Every caller runs before that - the plugin drops a disposed player from
  /// its map, and the delegate and event callbacks check isDisposed first.
  private var mediaPlayer: VLCMediaPlayer!
  private let eventChannel: FlutterEventChannel
  private let eventHandler = VlcPlayerEventStreamHandler()
  private let audioInterruptions = VlcAudioInterruptionObserver()
  private var lastSentEvent: NSDictionary?
  /// Bumped whenever the audio + subtitle track SET changes. VLCKit has no
  /// per-ES delegate callback (only the `.esAdded` state, which does not say
  /// which kind of stream moved), so every snapshot diffs a fingerprint of
  /// the two lists instead.
  ///
  /// The fingerprint replaced a plain count, which could not see a same-size
  /// swap: an adaptive rendition change or an MPEG-TS PMT update replaces the
  /// tracks without changing how many there are, and a consumer that caches
  /// getAudioTracks() / getSubtitleTracks() off this counter was left drawing
  /// the previous names with nothing ticked, because the active id it matches
  /// no longer exists.
  private var trackRevision = 0
  private var lastTrackFingerprint: UInt64?
  private var interruption = "none"
  /// The iOS picture-in-picture window, when one is up or starting. Nil
  /// otherwise, and on a view-backed player, which has no texture to feed
  /// from. Owned here so dispose() can close it with the player.
  private var pictureInPicture: VlcPictureInPictureController?
  private var holdsAudioSession = false
  private(set) var isDisposed = false
  /// Whether this player has been given a source: the next one gets a fresh
  /// player (replacePlayer).
  private var hasHadSource = false
  /// The volume last set, for a fresh player; nil until one is set.
  private var volume: Int32?
  /// The subtitle look last set, applied again to a fresh player.
  private var subtitleLook: (
    textScale: Int, color: Int, backgroundColor: Int, backgroundOpacity: Int,
    outlineThickness: Int, raise: Double
  )?

  init(
    viewId: Int64,
    messenger: FlutterBinaryMessenger,
    options: [String],
    target: VlcRenderTarget
  ) {
    renderTarget = target
    var instanceOptions = options
    if case .texture = target {
      // The texture sink has libVLC scale every VideoToolbox picture two rows
      // taller so that subtitles can be drawn on it (kSubtitleRows in
      // VlcTextureRenderer.mm). macOS does that on the GPU; MobileVLCKit has
      // no CoreVideo scaler, so on iOS it is swscale on the CPU, and its
      // default bicubic costs several times what a two-row stretch shows.
      // Present in MobileVLCKit 3.7.3's and 3.7.4's option tables.
      instanceOptions.append("--swscale-mode=0")
    }
    mediaPlayer = VLCMediaPlayer(library: Self.library(for: instanceOptions))
    // libVLC's own log, which VLCKit drops unless a logger is set: the host's verbose switch (`--verbose=2`) reaches
    // the console only through one. A device's console isn't always within reach, so the same log also goes to
    // vlc-verbose.log in the app's caches, to copy off it.
    if instanceOptions.contains("--verbose=2") {
      let console = VLCConsoleLogger()
      console.level = .debug
      console.formatter.contextFlags = .levelContextModule
      var loggers: [VLCLogging] = [console]
      if let caches = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first {
        let path = caches.appendingPathComponent("vlc-verbose.log").path
        FileManager.default.createFile(atPath: path, contents: nil)
        if let handle = FileHandle(forWritingAtPath: path) {
          let file = VLCFileLogger(fileHandle: handle)
          file.level = .debug
          file.formatter.contextFlags = .levelContextModule
          loggers.append(file)
        }
      }
      mediaPlayer.libraryInstance.loggers = loggers
    }
    eventChannel = FlutterEventChannel(name: "vlc_player/events/\(viewId)", binaryMessenger: messenger)

    switch target {
    case let .uiKitView(container, fit):
      container.backgroundColor = .black
      Self.applyFit(fit, to: container)
      mediaPlayer.drawable = container
    case .texture:
      // Installed before any media is set: libVLC settles its video output
      // when playback starts, and callbacks added after that are ignored.
      textureRenderer = VlcTextureRenderer(mediaPlayer: mediaPlayer)
    }
    // libVLC's own buffering, track and time events, the held picture, and
    // its refused-seek log line, which VLCKit's delegate doesn't carry. The
    // log is read per library (library(for:)), and not under VLCKit's own
    // loggers, which take libVLC's one callback per instance.
    events = VlcPlayerEvents(
      mediaPlayer: mediaPlayer,
      renderer: textureRenderer,
      readLog: !instanceOptions.contains("--verbose=2"))

    super.init()

    events?.onChanged = { [weak self] in
      self?.sendSnapshot()
    }

    mediaPlayer.delegate = self
    eventHandler.onListen = { [weak self] in
      self?.sendSnapshot(force: true)
    }
    eventChannel.setStreamHandler(eventHandler)
    audioInterruptions.onEvent = { [weak self] event in
      self?.handleAudioInterruption(event)
    }
    sendSnapshot()
  }

  func setSource(
    _ uri: String,
    httpHeaders: [String: String],
    mediaOptions: [String],
    startPosition: Int,
    keepPicture: Bool,
    autoPlay: Bool,
    result: @escaping FlutterResult
  ) {
    guard let url = URL(string: uri) else {
      result(FlutterError(code: "invalid_uri", message: "The provided uri is invalid.", details: uri))
      return
    }

    let media = VLCMedia(url: url)
    // HTTP headers are translated to libVLC options in Dart
    // (vlc_http_headers.dart). libVLC 3.x can transmit only User-Agent and
    // Referer; there is no `http-header` option, and emitting one here
    // silently dropped every header.
    for option in mediaOptions {
      media.addOption(option)
    }
    if startPosition > 0 {
      media.addOption(":start-time=\(Double(startPosition) / 1000.0)")
    }
    if hasHadSource {
      replacePlayer()
    }
    hasHadSource = true
    events?.arm(withKeepPicture: keepPicture)
    mediaPlayer.media = media
    interruption = "none"
    pipPlaying = false
    sendSnapshot(force: true, stateOverride: "opening")
    if autoPlay {
      acquireAudioSession()
      mediaPlayer.play()
      pipPlaying = true
      // The PiP controller is built now, not on tap: the window can only
      // open once the layer has presented content, and the Home-swipe
      // auto-start needs a controller that already exists and is possible
      // before the app goes away.
      preparePictureInPicture()
    }
    result(nil)
  }

  func play() {
    acquireAudioSession()
    // Once the viewer has pressed something the interruption no longer
    // explains what the player is doing.
    interruption = "none"
    mediaPlayer.play()
    pipPlaying = true
    preparePictureInPicture()
    sendSnapshot()
  }

  func pause() {
    // The session is kept over a pause on purpose. Handing it back only to
    // take it again makes the next press of play slow and interrupts whatever
    // filled the gap.
    interruption = "none"
    mediaPlayer.pause()
    pipPlaying = false
    sendSnapshot()
  }

  func stop() {
    interruption = "none"
    pipPlaying = false
    events?.stop()
    mediaPlayer.stop()
    relinquishAudioSession()
    sendSnapshot(stateOverride: "stopped")
  }

  /// Opens the iOS picture-in-picture window, fed from this player's texture.
  ///
  /// False when the device cannot do PiP (no support, below iOS 15, or a
  /// view-backed player, which has no texture to feed from), or when there is
  /// no picture yet. True means the request went out; the result — started,
  /// or failed to start — arrives on the event channel as a
  /// `pictureInPicture` event (see [sendPictureInPictureEvent]).
  ///
  /// [sourceRect] is the video picture's on-screen frame, which the window
  /// opens from. Nil falls back to the window's bounds inside the PiP
  /// controller, so a caller that sends none still gets a real frame.
  ///
  /// The controller is normally the eager one [preparePictureInPicture]
  /// built when playback started; this builds one on tap when that never
  /// ran. Either way the start itself is gated on
  /// `isPictureInPicturePossible` inside the controller, so a fresh
  /// controller is never asked to start before the system will accept it.
  func startPictureInPicture(sourceRect: CGRect? = nil) -> Bool {
    guard !isDisposed else {
      return false
    }
    if let pictureInPicture, pictureInPicture.isActive {
      return true
    }
    if pictureInPicture == nil {
      pictureInPicture = makePictureInPictureController()
    }
    guard let pip = pictureInPicture, pip.start(sourceRect: sourceRect) else {
      return false
    }
    return true
  }

  /// Builds the PiP controller, layer and host view now, so a controller
  /// already exists — and is already possible — by the time the viewer taps
  /// PiP or leaves the app. Called when playback starts (see [play] and the
  /// autoplay branch of [setSource]); idempotent, and a no-op when the device
  /// cannot do PiP. The `canStartPictureInPictureAutomaticallyFromInline`
  /// auto-start only works when the controller exists and is possible BEFORE
  /// the app goes away, and a controller built on tap has neither.
  func preparePictureInPicture() {
    guard !isDisposed else {
      return
    }
    if pictureInPicture == nil {
      pictureInPicture = makePictureInPictureController()
    }
    if #available(iOS 15.0, *) {
      _ = pictureInPicture?.prepare()
    }
  }

  private func makePictureInPictureController() -> VlcPictureInPictureController {
    VlcPictureInPictureController(player: self) { [weak self] inPip, error in
      self?.sendPictureInPictureEvent(inPip, error: error)
    }
  }

  /// Closes the iOS picture-in-picture window, if one is up. The
  /// `pictureInPicture` event still arrives, from the stop completing.
  func stopPictureInPicture() {
    pictureInPicture?.stop()
  }

  /// Sends the iOS picture-in-picture state to Dart, through the event channel
  /// the snapshots already use.
  ///
  /// A minimal event, not a snapshot: Dart reads the `pictureInPicture` key
  /// off it directly, so a PiP-only event never disturbs the published value.
  /// A failed start also carries `pipError` (the failure in the system's
  /// words) and `pipPossible` (whether a start would be accepted right now) —
  /// the debug line Dart shows when a start fails.
  func sendPictureInPictureEvent(_ inPip: Bool, error: String? = nil) {
    guard !isDisposed else {
      return
    }
    var event: [String: Any] = ["pictureInPicture": inPip]
    if let error {
      event["pipError"] = error
    }
    if #available(iOS 15.0, *), let pip = pictureInPicture {
      event["pipPossible"] = pip.isPictureInPicturePossible
    }
    eventHandler.send(event)
  }

  /// The transport's playing state, for the PiP window's play/pause button
  /// and for the auto-PiP gate.
  ///
  /// Set by the explicit transport calls (`play`/`pause`/`stop`, a new source,
  /// the media ending or erroring, an audio interruption) — NOT read off
  /// `mediaPlayer.isPlaying`. libVLC's own flag flickers during HLS playback
  /// and across a seek (the input restarts, and `.buffering` is reported
  /// throughout healthy playback), so the PiP window's button flipped between
  /// play and pause while the film kept playing. The transport state is the
  /// one the viewer asked for — like AVPlayer's rate, which stays 1.0 while
  /// rebuffering — and it is also what the auto-PiP gate ("only a playing
  /// film floats") means.
  private var pipPlaying = false

  /// Whether the transport is playing, for the PiP window's play/pause.
  var pipIsPlaying: Bool {
    return pipPlaying
  }

  /// Seeks by [seconds], clamped to the media, for the PiP window's step.
  ///
  /// A seek restarts the input, and on some streams libVLC leaves the
  /// transport paused afterwards, so a playing film came back paused from a
  /// skip. The state it had before the seek is restored — playing stays
  /// playing, paused stays paused — so a skip never flips it.
  func pipSkip(by seconds: Double) {
    let wasPlaying = pipPlaying
    let position = Double(mediaPlayer.time.intValue) / 1000.0 + seconds
    let duration = Double(mediaPlayer.media?.length.intValue ?? 0) / 1000.0
    let clamped = duration > 0
      ? min(max(position, 0), duration)
      : max(position, 0)
    seekTo(milliseconds: Int(clamped * 1000))
    if wasPlaying {
      // A no-op when the seek left playback running; the resume when it did
      // not. `play()` is idempotent, so this cannot start a film the viewer
      // had paused.
      play()
    }
  }

  /// The scrub range the PiP window draws, or open-ended when the media has
  /// no length to draw from yet. An invalid range makes the system treat the
  /// playback delegate as broken, so a stream with no length reports an
  /// unbounded range instead — the safe default for live-style content.
  func pipTimeRange() -> CMTimeRange {
    guard let length = mediaPlayer.media?.length, length.intValue > 0 else {
      return CMTimeRange(start: .negativeInfinity, duration: .positiveInfinity)
    }
    return CMTimeRange(
      start: .zero,
      duration: CMTime(value: Int64(length.intValue), timescale: 1000))
  }

  func seekTo(milliseconds: Int) {
    mediaPlayer.time = VLCTime(number: NSNumber(value: milliseconds))
    sendSnapshot()
  }

  /// A place in a live HLS or DASH window, as libVLC's position fraction.
  func seekToFraction(_ fraction: Double) {
    mediaPlayer.position = Float(fraction)
    sendSnapshot()
  }

  func setVolume(_ volume: Int) {
    let clamped = Int32(max(0, min(200, volume)))
    self.volume = clamped
    mediaPlayer.audio?.volume = clamped
    sendSnapshot()
  }

  func setPlaybackSpeed(_ speed: Double) {
    mediaPlayer.rate = Float(speed)
    sendSnapshot()
  }

  func setAudioDelay(_ microseconds: Int) {
    mediaPlayer.currentAudioPlaybackDelay = microseconds
    sendSnapshot()
  }

  /// Restyles the subtitle lines libVLC draws, from their next line; whether
  /// this libVLC could. The variables stay on the player, for every media it
  /// is given after.
  ///
  /// [raise] is a share of the picture's height, and libVLC takes pixels of
  /// what it lays the lines out on: for the texture, the picture itself,
  /// blended into a buffer of its size. Dart sends the look again whenever the
  /// picture changes size. A drawable lays them out on the picture on screen,
  /// where the raise comes out smaller than asked when that is the larger.
  func setSubtitleLook(
    textScale: Int,
    color: Int,
    backgroundColor: Int,
    backgroundOpacity: Int,
    outlineThickness: Int,
    raise: Double
  ) -> Bool {
    subtitleLook = (
      textScale, color, backgroundColor, backgroundOpacity, outlineThickness,
      raise
    )
    let height = Double(mediaPlayer.videoSize.height)
    let margin = raise > 0 && height > 0 ? Int((min(raise, 0.5) * height).rounded()) : 0
    return VlcTextureRenderer.applySubtitleLook(
      to: mediaPlayer,
      textScale: textScale,
      color: color,
      backgroundColor: backgroundColor,
      backgroundOpacity: backgroundOpacity,
      outlineThickness: outlineThickness,
      margin: margin)
  }

  func setSubtitleDelay(_ microseconds: Int) {
    mediaPlayer.currentVideoSubTitleDelay = microseconds
    sendSnapshot()
  }

  func takeSnapshot(width: Int, height: Int, result: @escaping FlutterResult) {
    guard mediaPlayer.media != nil else {
      result(FlutterError(code: "snapshot_failed", message: "No media is loaded.", details: nil))
      return
    }

    let url = FileManager.default.temporaryDirectory.appendingPathComponent(
      "vlc_player_snapshot_\(UUID().uuidString).png"
    )
    try? FileManager.default.removeItem(at: url)
    mediaPlayer.saveVideoSnapshot(at: url.path, withWidth: Int32(width), andHeight: Int32(height))

    DispatchQueue.global(qos: .userInitiated).async {
      for _ in 0..<40 {
        if let data = try? Data(contentsOf: url), !data.isEmpty {
          try? FileManager.default.removeItem(at: url)
          DispatchQueue.main.async {
            result(FlutterStandardTypedData(bytes: data))
          }
          return
        }
        Thread.sleep(forTimeInterval: 0.05)
      }

      try? FileManager.default.removeItem(at: url)
      DispatchQueue.main.async {
        result(FlutterError(code: "snapshot_failed", message: "VLC did not produce snapshot image data.", details: nil))
      }
    }
  }

  func getAudioTracks() -> [[String: Any?]] {
    return trackDescriptions(indexes: mediaPlayer.audioTrackIndexes, names: mediaPlayer.audioTrackNames)
  }

  func setAudioTrack(_ id: Int) -> Bool {
    guard trackIndexes(mediaPlayer.audioTrackIndexes).contains(id) else {
      return false
    }
    mediaPlayer.currentAudioTrackIndex = Int32(id)
    // No ES delegate callback tells us the switch landed; publish it now.
    sendSnapshot(force: true)
    return true
  }

  func getSubtitleTracks() -> [[String: Any?]] {
    return trackDescriptions(indexes: mediaPlayer.videoSubTitlesIndexes, names: mediaPlayer.videoSubTitlesNames)
  }

  func setSubtitleTrack(_ id: Int) -> Bool {
    guard trackIndexes(mediaPlayer.videoSubTitlesIndexes).contains(id) else {
      return false
    }
    mediaPlayer.currentVideoSubTitleIndex = Int32(id)
    sendSnapshot(force: true)
    return true
  }

  func disableSubtitle() {
    mediaPlayer.currentVideoSubTitleIndex = -1
    sendSnapshot(force: true)
  }

  func addSubtitle(_ uri: String, result: @escaping FlutterResult) {
    guard let url = URL(string: uri) else {
      result(FlutterError(code: "invalid_uri", message: "The provided subtitle uri is invalid.", details: uri))
      return
    }
    let status = mediaPlayer.addPlaybackSlave(url, type: .subtitle, enforce: true)
    if status != 0 {
      result(FlutterError(code: "add_subtitle_failed", message: "Failed to add subtitle: \(uri)", details: status))
      return
    }
    // Unlike the three selection mutations above, this one cannot report its
    // own result: libVLC 3 posts an added slave to the input thread, so a
    // zero status only means the slave was accepted and this snapshot still
    // carries the pre-add track lists. It is forced to keep the rest of the
    // payload fresh, not to announce the subtitle. VLCKit surfaces the new
    // elementary stream as a `.esAdded` state change, and the snapshot sent
    // from there is the one whose trackFingerprint moves trackRevision -
    // which is what a caller has to wait on, not this result.
    sendSnapshot(force: true)
    result(nil)
  }

  func getMediaInfo() -> [String: Any?] {
    let media = mediaPlayer.media
    return [
      "title": media?.metaData.title,
      "artist": media?.metaData.artist,
      "album": media?.metaData.album,
      "duration": Self.milliseconds(from: media?.length),
      "videoTracks": mediaTracks(media, matching: "video"),
      "audioTracks": mediaTracks(media, matching: "audio"),
      "subtitleTracks": mediaTracks(media, matching: "subtitle"),
    ]
  }

  func getMediaStats() -> [String: Any] {
    guard let media = mediaPlayer.media else {
      return Self.emptyMediaStats()
    }

    let stats = media.statistics
    return [
      "available": true,
      "readBytes": Int(stats.readBytes),
      "inputBitrate": Double(stats.inputBitrate),
      "demuxReadBytes": Int(stats.demuxReadBytes),
      "demuxBitrate": Double(stats.demuxBitrate),
      "demuxCorrupted": Int(stats.demuxCorrupted),
      "demuxDiscontinuity": Int(stats.demuxDiscontinuity),
      "decodedVideo": Int(stats.decodedVideo),
      "decodedAudio": Int(stats.decodedAudio),
      "displayedPictures": Int(stats.displayedPictures),
      "lostPictures": Int(stats.lostPictures),
      "playedAudioBuffers": Int(stats.playedAudioBuffers),
      "lostAudioBuffers": Int(stats.lostAudioBuffers),
      "sentPackets": Int(stats.sentPackets),
      "sentBytes": Int(stats.sentBytes),
      "sendBitrate": Double(stats.sendBitrate),
    ]
  }

  /// libVLC instances by the options they were made with, kept for the
  /// process's life, so that no released player ever ends one.
  ///
  /// VLCKit gives a player made with options an instance of its own, and
  /// ending an instance saves libVLC's configuration while holding the
  /// configuration lock for reading, taken twice (3.0.24 file.c,
  /// config_AutoSaveConfigFile). Darwin's lock makes a reader wait behind a
  /// queued writer, and libVLC writes its configuration from its own threads
  /// (macOS's audio output at every start and close), so an instance ending
  /// beside such a write deadlocked both, and then every thread that read the
  /// configuration, main included (FORK.md 23). One instance per set of
  /// options, which is a handful, and none ends while the app runs.
  private static var libraries: [[String]: VLCLibrary] = [:]

  /// Main thread only, where every player is made.
  private static func library(for options: [String]) -> VLCLibrary {
    if let library = libraries[options] {
      return library
    }
    // Two of VLCKit's defaults off, after the host's options so they win over
    // VLCKit's own, which it puts in front (VLCLibrary.m, _defaultOptions):
    // macOS's --play-and-pause, which pauses at every end - a finished film and
    // a lost connection's false end alike - and volume-save, auhal's write of
    // the volume into libVLC's configuration at every sound start and volume
    // change, which can deadlock with the save VLCKit makes after every input
    // close (FORK.md 32). Nothing reads that configuration back: VLCKit leaves
    // ignore-config on.
    let library = VLCLibrary(options: options + ["--no-play-and-pause", "--no-volume-save"])
    if !options.contains("--verbose=2") {
      VlcPlayerEvents.readLog(of: library)
    }
    libraries[options] = library
    return library
  }

  /// Where released players go: concurrent, so one stuck behind a stalled
  /// download doesn't hold up the next.
  private static let releaseQueue = DispatchQueue(
    label: "vlc_player.release", qos: .utility, attributes: .concurrent)

  /// Holds the only reference the plugin has left, so the release happens
  /// exactly where it is let go.
  private final class Retired {
    var player: VLCMediaPlayer?
    init(_ player: VLCMediaPlayer) { self.player = player }
  }

  /// Lets [player] go off the main thread, then runs [then] on main.
  ///
  /// VLCKit 3.7.4's -[VLCMediaPlayer dealloc] releases the libVLC player,
  /// which waits for the stream an asynchronous stop began stopping (VLCKit's
  /// patch 0023): 130 s on a stalled HLS download (spec 3). VLCKit also holds
  /// the player for two main-queue turns after a stop - its Stopped handler
  /// runs on main and queues one more block there that sets the idle timer -
  /// so the reference is kept past both, then let go on a queue of its own.
  static func releaseLater(_ player: VLCMediaPlayer, then: (() -> Void)? = nil) {
    let retired = Retired(player)
    DispatchQueue.main.async {
      DispatchQueue.main.async {
        releaseQueue.async {
          retired.player = nil
          if let then {
            DispatchQueue.main.async(execute: then)
          }
        }
      }
    }
  }

  /// Puts a fresh player in place for the next source and hands the old one
  /// to releaseLater.
  ///
  /// VLCKit 3.7.4 starts a media set with set_media_async only once the old
  /// input has closed (patch 0023: play() sets open_next while close_input is
  /// pending, and the worker thread opens the new input after input_Close),
  /// and a stalled HLS segment kept that close waiting for as long as the
  /// stall: a reconnect from a stalled stream could not start. Android,
  /// Windows and Linux make a fresh player per source too (FORK.md 10 and 21).
  private func replacePlayer() {
    let old: VLCMediaPlayer = mediaPlayer
    let next = VLCMediaPlayer(library: old.libraryInstance)
    // What VLCKit keeps per player rather than per media. Audio and subtitle
    // delays are per input in libVLC 3, so every media starts without them.
    if let volume {
      next.audio?.volume = volume
    }
    let rate = old.rate
    if rate != 1 {
      next.rate = rate
    }
    old.delegate = nil
    // libvlc_media_player_stop_async: the stalled stream closes on a thread
    // of the old player's own, beside the new one.
    old.stop()
    old.drawable = nil
    switch renderTarget {
    case let .uiKitView(container, _):
      next.drawable = container
    case .texture:
      // The same texture and sink, so the picture on screen stays until the
      // new player draws.
      textureRenderer?.attach(to: next)
    }
    // The old player's stop is not the new media going: its events stop here.
    events?.attach(to: next)
    next.delegate = self
    mediaPlayer = next
    if let look = subtitleLook {
      _ = setSubtitleLook(
        textScale: look.textScale, color: look.color,
        backgroundColor: look.backgroundColor,
        backgroundOpacity: look.backgroundOpacity,
        outlineThickness: look.outlineThickness, raise: look.raise)
    }
    Self.releaseLater(old)
  }

  func dispose() {
    guard !isDisposed else {
      return
    }
    isDisposed = true
    // First: a PiP window outlives its player unless it is told to close,
    // and its feed reads the texture this dispose detaches below.
    pictureInPicture?.dispose()
    pictureInPicture = nil
    // libVLC stops calling in before anything else goes.
    events?.detach()
    events = nil
    audioInterruptions.stopObserving()
    eventChannel.setStreamHandler(nil)
    let player: VLCMediaPlayer = mediaPlayer
    player.delegate = nil
    // libvlc_media_player_stop_async: returns at once, and the stream stops on
    // a thread of VLCKit's.
    player.stop()
    player.drawable = nil
    // The stopping stream can still draw one last frame; Detach turns any
    // late callback into a no-op (vlc_video_output.cc).
    textureRenderer?.detach()
    textureRenderer = nil
    mediaPlayer = nil
    let heldSession = holdsAudioSession
    holdsAudioSession = false
    Self.releaseLater(player) {
      // After the player is gone, so VLC's audio unit has stopped before the
      // session deactivates under it.
      if heldSession {
        VlcAudioSession.shared.relinquish()
      }
    }
  }

  private func handleAudioInterruption(_ event: VlcAudioInterruptionEvent) {
    guard !isDisposed else {
      return
    }

    switch event {
    case .began:
      interruptPlayback("focusLostTransient")
    case .deviceLost:
      interruptPlayback("becameNoisy")
    case .endedNotResumable:
      // The call is over but the system is not offering the audio back. Saying
      // so withdraws the promise that anything is coming, and leaves the
      // restart to the viewer.
      guard interruption != "none" else {
        return
      }
      interruption = "focusLost"
      sendSnapshot()
    case .endedResumable:
      guard interruption != "none" else {
        return
      }
      interruption = "none"
      // Reported, not acted on. Whether playback should resume depends on the
      // app lifecycle and the background policy, and both of those live in
      // Dart; resuming from here would start a film in an app the viewer
      // walked away from ten minutes ago.
      sendSnapshot()
    }
  }

  /// Pauses for an interruption the viewer did not ask for.
  ///
  /// The pause happens here rather than after a round trip to Dart because an
  /// interruption has to be honoured in the instant it arrives - a film that
  /// waits for an event channel talks over the first ring of a phone call.
  private func interruptPlayback(_ reason: String) {
    if mediaPlayer.isPlaying {
      interruption = reason
      mediaPlayer.pause()
      pipPlaying = false
      sendSnapshot(stateOverride: "paused")
      return
    }
    if interruption != "none" {
      // Already silent for an earlier interruption. A transient loss that
      // turned permanent is still worth saying.
      interruption = reason
      sendSnapshot()
    }
  }

  private func acquireAudioSession() {
    if holdsAudioSession {
      // Already a holder, but iOS deactivates the session for the duration of
      // an interruption, so this is where a post-call play takes it back.
      VlcAudioSession.shared.activate()
      return
    }
    holdsAudioSession = true
    VlcAudioSession.shared.acquire()
  }

  private func relinquishAudioSession() {
    guard holdsAudioSession else {
      return
    }
    holdsAudioSession = false
    VlcAudioSession.shared.relinquish()
  }

  func mediaPlayerStateChanged(_ aNotification: Notification) {
    // A notification VLCKit queued before dispose() can still arrive.
    guard !isDisposed else {
      return
    }
    if mediaPlayer.state == .ended {
      // Nothing left to play: hold the session no longer, so whatever we
      // interrupted can come back on its own. A playlist advancing takes it
      // straight back.
      //
      // Not .stopped as well: replacing the media on a running player passes
      // through it, and this callback lands after setSource has already
      // claimed the session for the next item.
      pipPlaying = false
      relinquishAudioSession()
    }
    if mediaPlayer.state == .error {
      pipPlaying = false
      sendSnapshot(
        errorCode: "playback_error",
        errorDescription: "VLC encountered an error while playing the media."
      )
      return
    }
    sendSnapshot()
  }

  func mediaPlayerTimeChanged(_ aNotification: Notification) {
    guard !isDisposed else {
      return
    }
    sendSnapshot()
  }

  private func sendSnapshot(
    force: Bool = false,
    stateOverride: String? = nil,
    errorCode: String? = nil,
    errorDescription: String? = nil
  ) {
    guard !isDisposed else {
      return
    }
    guard eventHandler.isListening else {
      return
    }

    var stateName = stateOverride ?? Self.stateName(mediaPlayer)
    let prebuffer = events?.bufferingProgress ?? -1
    // libVLC says "playing" while it fills its buffer; only the Buffering
    // event says how full it is (one model on every platform, spec 4).
    if stateOverride == nil && stateName == "playing" && prebuffer >= 0 {
      stateName = "buffering"
    }
    let duration = Self.milliseconds(from: mediaPlayer.media?.length)
    let isSeekable = mediaPlayer.isSeekable
    let trackFingerprint = Self.trackFingerprint(mediaPlayer)
    if trackFingerprint != lastTrackFingerprint {
      lastTrackFingerprint = trackFingerprint
      trackRevision += 1
    }
    var event: [String: Any] = [
      "state": stateName,
      "position": Self.milliseconds(from: mediaPlayer.time),
      "duration": duration,
      "positionFraction": Double(mediaPlayer.position),
      "volume": Int(mediaPlayer.audio?.volume ?? 0),
      "playbackSpeed": Double(mediaPlayer.rate),
      "audioDelay": Int(mediaPlayer.currentAudioPlaybackDelay),
      "subtitleDelay": Int(mediaPlayer.currentVideoSubTitleDelay),
      // -1 when there is none / subtitles are off; Dart normalises to null.
      "audioTrack": Int(mediaPlayer.currentAudioTrackIndex),
      "subtitleTrack": Int(mediaPlayer.currentVideoSubTitleIndex),
      "trackRevision": trackRevision,
      "isReady": Self.isReadyState(stateName),
      "isSeekable": isSeekable,
      "isLive": Self.isLiveState(stateName) && duration == 0 && !isSeekable,
      "interruption": interruption,
    ]
    event["pictureHeld"] = events?.pictureHeld ?? false
    if prebuffer >= 0 {
      event["bufferingProgress"] = prebuffer
    }
    if let events, events.seekRefusals > 0 {
      event["seekRefusals"] = events.seekRefusals
      event["seekRefusedAt"] = events.seekRefusedAt
    }
    if let videoSize = Self.videoSizeMap(mediaPlayer.videoSize) {
      event["videoSize"] = videoSize
    }
    // The texture is the decoder's padded buffer, not the visible picture;
    // Dart clips the difference. Absent for view-backed players, whose
    // drawable already crops.
    if let renderer = textureRenderer,
       let codedSize = Self.videoSizeMap(renderer.codedSize) {
      event["codedSize"] = codedSize
    }
    if let errorDescription {
      event["errorCode"] = errorCode ?? "playback_error"
      event["errorDescription"] = errorDescription
    }
    let snapshot = NSDictionary(dictionary: event)
    if !force, let lastSentEvent = lastSentEvent, lastSentEvent.isEqual(snapshot) {
      return
    }
    lastSentEvent = snapshot
    eventHandler.send(event)
  }

  private static func milliseconds(from time: VLCTime?) -> Int {
    guard let time else {
      return 0
    }
    return max(0, Int(time.intValue))
  }

  private static func videoSizeMap(_ size: CGSize) -> [String: Int]? {
    let width = Int(size.width)
    let height = Int(size.height)
    guard width > 0 && height > 0 else {
      return nil
    }
    return ["width": width, "height": height]
  }

  private static func emptyMediaStats() -> [String: Any] {
    return [
      "available": false,
      "readBytes": 0,
      "inputBitrate": 0.0,
      "demuxReadBytes": 0,
      "demuxBitrate": 0.0,
      "demuxCorrupted": 0,
      "demuxDiscontinuity": 0,
      "decodedVideo": 0,
      "decodedAudio": 0,
      "displayedPictures": 0,
      "lostPictures": 0,
      "playedAudioBuffers": 0,
      "lostAudioBuffers": 0,
      "sentPackets": 0,
      "sentBytes": 0,
      "sendBitrate": 0.0,
    ]
  }

  func setFit(_ fit: String) {
    // A texture-backed player is fitted in Dart, by the widget that owns the
    // Texture, so there is nothing to push down here.
    guard case let .uiKitView(container, _) = renderTarget else {
      return
    }
    Self.applyFit(fit, to: container)
  }

  private static func applyFit(_ fit: String, to view: UIView) {
    view.clipsToBounds = true
    switch fit {
    case "cover":
      view.contentMode = .scaleAspectFill
    case "fill":
      view.contentMode = .scaleToFill
    case "none":
      view.contentMode = .center
    default:
      view.contentMode = .scaleAspectFit
    }
  }

  private func trackDescriptions(indexes: [Any]?, names: [Any]?) -> [[String: Any?]] {
    let trackIndexes = indexes as? [NSNumber] ?? []
    let trackNames = names as? [String] ?? []
    return trackIndexes.enumerated().map { offset, index in
      [
        "id": index.intValue,
        "name": offset < trackNames.count ? trackNames[offset] : "",
        "language": nil,
      ]
    }
  }

  /// An order-sensitive FNV-1a fingerprint of the audio + subtitle track set.
  ///
  /// Not a security hash: it only has to make two different track lists land
  /// on two different numbers, and it only ever gets compared against the
  /// previous snapshot's value inside this process.
  private static func trackFingerprint(_ mediaPlayer: VLCMediaPlayer) -> UInt64 {
    var hash: UInt64 = 0xcbf2_9ce4_8422_2325
    func fold(_ byte: UInt8) {
      hash = (hash ^ UInt64(byte)) &* 0x0000_0100_0000_01b3
    }
    func fold(indexes: [Any]?, names: [Any]?) {
      let trackIndexes = indexes as? [NSNumber] ?? []
      let trackNames = names as? [String] ?? []
      // A list separator, so an id that moves from the audio list to the
      // subtitle list cannot leave the fingerprint where it was.
      fold(0x1f)
      for (offset, index) in trackIndexes.enumerated() {
        withUnsafeBytes(of: Int32(truncatingIfNeeded: index.intValue)) { bytes in
          for byte in bytes {
            fold(byte)
          }
        }
        if offset < trackNames.count {
          for byte in trackNames[offset].utf8 {
            fold(byte)
          }
        }
        // A record separator, so ("a", "bc") and ("ab", "c") differ.
        fold(0x1e)
      }
    }
    fold(indexes: mediaPlayer.audioTrackIndexes, names: mediaPlayer.audioTrackNames)
    fold(indexes: mediaPlayer.videoSubTitlesIndexes, names: mediaPlayer.videoSubTitlesNames)
    return hash
  }

  private func trackIndexes(_ indexes: [Any]?) -> Set<Int> {
    return Set((indexes as? [NSNumber] ?? []).map(\.intValue))
  }

  private func mediaTracks(_ media: VLCMedia?, matching type: String) -> [[String: Any?]] {
    guard let tracks = media?.tracksInformation as? [[String: Any]] else {
      return []
    }

    return tracks.compactMap { track in
      guard Self.trackType(track[VLCMediaTracksInformationType]) == type else {
        return nil
      }
      var info: [String: Any?] = [
        "type": type,
        "codec": track[VLCMediaTracksInformationCodec],
        "language": track[VLCMediaTracksInformationLanguage],
        "bitrate": track[VLCMediaTracksInformationBitrate],
      ]
      if type == "video" {
        info["width"] = track[VLCMediaTracksInformationVideoWidth]
        info["height"] = track[VLCMediaTracksInformationVideoHeight]
      }
      if type == "audio" {
        info["channels"] = track[VLCMediaTracksInformationAudioChannelsNumber]
        info["sampleRate"] = track[VLCMediaTracksInformationAudioRate]
      }
      return info
    }
  }

  private static func trackType(_ value: Any?) -> String {
    let raw = String(describing: value ?? "").lowercased()
    if raw.contains("video") {
      return "video"
    }
    if raw.contains("audio") {
      return "audio"
    }
    if raw.contains("text") || raw.contains("subtitle") {
      return "subtitle"
    }
    return "unknown"
  }

  private static func stateName(_ player: VLCMediaPlayer) -> String {
    switch player.state {
    case .opening:
      return "opening"
    case .buffering:
      // VLCKit reports .buffering throughout healthy playback, not just while
      // stalled. Reporting it verbatim meant the player never said it was
      // playing - the spinner stuck, and every host feature gated on "playing"
      // (progress, scrobbling, completion, next episode) stopped firing.
      return player.isPlaying ? "playing" : "buffering"
    case .playing:
      return "playing"
    case .paused:
      return "paused"
    case .stopped:
      return "stopped"
    case .ended:
      return "ended"
    case .error:
      return "error"
    default:
      // VLCKit 3.x emits .esAdded during normal startup and whenever an
      // elementary stream appears (track switch, adaptive rendition change).
      // Mapping every unmodelled case to "idle" made isReady flip to false in
      // the middle of playback, so consumers saw the player go not-ready while
      // it was demonstrably playing. Derive from the transport instead, and
      // reserve "idle" for the genuine no-media case.
      if player.media == nil {
        return "idle"
      }
      return player.isPlaying ? "playing" : "opening"
    }
  }

  private static func isReadyState(_ state: String) -> Bool {
    return state == "playing" ||
      state == "paused" ||
      state == "stopped" ||
      state == "ended"
  }

  private static func isLiveState(_ state: String) -> Bool {
    // "buffering" is deliberately excluded. isLive is derived from
    // `duration == 0 && !isSeekable`, and both are trivially true while VLC is
    // still opening the stream — so including buffering made every VOD report
    // isLive for the first frames, long enough for a consumer to hide its seek
    // bar and speed controls and then have to put them back.
    return state == "playing" || state == "paused"
  }

  private static func isValidHeader(name: String, value: String) -> Bool {
    return !name.isEmpty &&
      !name.contains("\r") &&
      !name.contains("\n") &&
      !value.contains("\r") &&
      !value.contains("\n")
  }
}

/// Answers Flutter's `view()` for itself, so the view-backed path has a
/// `FlutterPlatformView` to hand back without the player - which may have no
/// view at all - having to be one.
final class VlcPlayerContainerView: UIView, FlutterPlatformView {
  func view() -> UIView {
    return self
  }
}

final class VlcPlayerEventStreamHandler: NSObject, FlutterStreamHandler {
  private var eventSink: FlutterEventSink?
  var onListen: (() -> Void)?
  var isListening: Bool {
    return eventSink != nil
  }

  func onListen(withArguments arguments: Any?, eventSink events: @escaping FlutterEventSink) -> FlutterError? {
    eventSink = events
    onListen?()
    return nil
  }

  func onCancel(withArguments arguments: Any?) -> FlutterError? {
    eventSink = nil
    return nil
  }

  /// Sends [event] at once on the main thread, where every snapshot is made,
  /// so an event sent before a method's answer reaches Dart before it:
  /// setSource's opening snapshot says whether the output holds by the time
  /// setMedia returns (FORK.md 33). From any other thread it goes to main.
  func send(_ event: [String: Any]) {
    if Thread.isMainThread {
      eventSink?(event)
      return
    }
    DispatchQueue.main.async { [weak self] in
      self?.eventSink?(event)
    }
  }
}
