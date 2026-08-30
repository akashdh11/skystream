import Flutter
import MobileVLCKit
import UIKit

public class VlcPlayerPlugin: NSObject, FlutterPlugin {
  private let messenger: FlutterBinaryMessenger
  private let methodChannel: FlutterMethodChannel
  private var players: [Int64: VlcPlayerPlatformView] = [:]

  public static func register(with registrar: FlutterPluginRegistrar) {
    let messenger = registrar.messenger()
    let instance = VlcPlayerPlugin(binaryMessenger: messenger)
    let factory = VlcPlayerViewFactory(messenger: messenger) { [weak instance] viewId, player in
      instance?.players.removeValue(forKey: viewId)?.dispose()
      instance?.players[viewId] = player
    }

    registrar.addMethodCallDelegate(instance, channel: instance.methodChannel)
    registrar.register(factory, withId: "plugins.lingjhf.com/vlc_player/view")
  }

  init(binaryMessenger: FlutterBinaryMessenger) {
    messenger = binaryMessenger
    methodChannel = FlutterMethodChannel(name: "vlc_player", binaryMessenger: binaryMessenger)
    super.init()
  }

  public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
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
    case "getMediaInfo":
      result(player.getMediaInfo())
    case "getMediaStats":
      result(player.getMediaStats())
    default:
      result(FlutterMethodNotImplemented)
    }
  }

  private func disposePlayer(viewId: Int64, result: FlutterResult? = nil) {
    let dispose = {
      self.players.removeValue(forKey: viewId)?.dispose()
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
    let platformView = VlcPlayerPlatformView(
      frame: frame,
      viewId: viewId,
      messenger: messenger,
      options: options,
      fit: fit
    )
    onCreate(viewId, platformView)
    return platformView
  }

  func createArgsCodec() -> FlutterMessageCodec & NSObjectProtocol {
    return FlutterStandardMessageCodec.sharedInstance()
  }
}

final class VlcPlayerPlatformView: NSObject, FlutterPlatformView, VLCMediaPlayerDelegate {
  private let uiView: VlcPlayerContainerView
  private let mediaPlayer: VLCMediaPlayer
  private let eventChannel: FlutterEventChannel
  private let eventHandler = VlcPlayerEventStreamHandler()
  private var lastSentEvent: NSDictionary?
  private(set) var isDisposed = false

  init(
    frame: CGRect,
    viewId: Int64,
    messenger: FlutterBinaryMessenger,
    options: [String],
    fit: String
  ) {
    uiView = VlcPlayerContainerView(frame: frame)
    mediaPlayer = VLCMediaPlayer(options: options)
    eventChannel = FlutterEventChannel(name: "vlc_player/events/\(viewId)", binaryMessenger: messenger)
    super.init()

    uiView.backgroundColor = .black
    Self.applyFit(fit, to: uiView)
    mediaPlayer.drawable = uiView
    mediaPlayer.delegate = self
    eventHandler.onListen = { [weak self] in
      self?.sendSnapshot(force: true)
    }
    eventChannel.setStreamHandler(eventHandler)
    sendSnapshot()
  }

  func view() -> UIView {
    return uiView
  }

  func setSource(
    _ uri: String,
    httpHeaders: [String: String],
    mediaOptions: [String],
    startPosition: Int,
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
    mediaPlayer.media = media
    sendSnapshot(force: true, stateOverride: "opening")
    if autoPlay {
      mediaPlayer.play()
    }
    result(nil)
  }

  func play() {
    mediaPlayer.play()
    sendSnapshot()
  }

  func pause() {
    mediaPlayer.pause()
    sendSnapshot()
  }

  func stop() {
    mediaPlayer.stop()
    sendSnapshot(stateOverride: "stopped")
  }

  func seekTo(milliseconds: Int) {
    mediaPlayer.time = VLCTime(number: NSNumber(value: milliseconds))
    sendSnapshot()
  }

  func setVolume(_ volume: Int) {
    mediaPlayer.audio?.volume = Int32(max(0, min(200, volume)))
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
    return true
  }

  func disableSubtitle() {
    mediaPlayer.currentVideoSubTitleIndex = -1
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

  func dispose() {
    guard !isDisposed else {
      return
    }
    isDisposed = true
    eventChannel.setStreamHandler(nil)
    mediaPlayer.delegate = nil
    mediaPlayer.stop()
    mediaPlayer.drawable = nil
  }

  func mediaPlayerStateChanged(_ aNotification: Notification) {
    if mediaPlayer.state == .error {
      sendSnapshot(
        errorCode: "playback_error",
        errorDescription: "VLC encountered an error while playing the media."
      )
      return
    }
    sendSnapshot()
  }

  func mediaPlayerTimeChanged(_ aNotification: Notification) {
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

    let stateName = stateOverride ?? Self.stateName(mediaPlayer)
    let duration = Self.milliseconds(from: mediaPlayer.media?.length)
    let isSeekable = mediaPlayer.isSeekable
    var event: [String: Any] = [
      "state": stateName,
      "position": Self.milliseconds(from: mediaPlayer.time),
      "duration": duration,
      "volume": Int(mediaPlayer.audio?.volume ?? 0),
      "playbackSpeed": Double(mediaPlayer.rate),
      "audioDelay": Int(mediaPlayer.currentAudioPlaybackDelay),
      "subtitleDelay": Int(mediaPlayer.currentVideoSubTitleDelay),
      "isReady": Self.isReadyState(stateName),
      "isSeekable": isSeekable,
      "isLive": Self.isLiveState(stateName) && duration == 0 && !isSeekable,
    ]
    if let videoSize = Self.videoSizeMap(mediaPlayer.videoSize) {
      event["videoSize"] = videoSize
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

final class VlcPlayerContainerView: UIView {}

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

  func send(_ event: [String: Any]) {
    DispatchQueue.main.async { [weak self] in
      self?.eventSink?(event)
    }
  }
}
