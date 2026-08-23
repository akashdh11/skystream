/// Runtime statistics for the current VLC media session.
///
/// Values are best-effort and depend on the media, stream type, VLC backend,
/// and playback state. When VLC cannot provide statistics, [isAvailable] is
/// `false` and all counters are zero.
class VlcMediaStats {
  /// Creates media statistics.
  const VlcMediaStats({
    this.isAvailable = false,
    this.readBytes = 0,
    this.inputBitrate = 0,
    this.demuxReadBytes = 0,
    this.demuxBitrate = 0,
    this.demuxCorrupted = 0,
    this.demuxDiscontinuity = 0,
    this.decodedVideo = 0,
    this.decodedAudio = 0,
    this.displayedPictures = 0,
    this.lostPictures = 0,
    this.playedAudioBuffers = 0,
    this.lostAudioBuffers = 0,
    this.sentPackets = 0,
    this.sentBytes = 0,
    this.sendBitrate = 0,
  });

  /// Creates media statistics from a native platform map.
  factory VlcMediaStats.fromMap(Map<Object?, Object?> map) {
    return VlcMediaStats(
      isAvailable: _boolValue(map['available']),
      readBytes: _intValue(map['readBytes']),
      inputBitrate: _doubleValue(map['inputBitrate']),
      demuxReadBytes: _intValue(map['demuxReadBytes']),
      demuxBitrate: _doubleValue(map['demuxBitrate']),
      demuxCorrupted: _intValue(map['demuxCorrupted']),
      demuxDiscontinuity: _intValue(map['demuxDiscontinuity']),
      decodedVideo: _intValue(map['decodedVideo']),
      decodedAudio: _intValue(map['decodedAudio']),
      displayedPictures: _intValue(map['displayedPictures']),
      lostPictures: _intValue(map['lostPictures']),
      playedAudioBuffers: _intValue(map['playedAudioBuffers']),
      lostAudioBuffers: _intValue(map['lostAudioBuffers']),
      sentPackets: _intValue(map['sentPackets']),
      sentBytes: _intValue(map['sentBytes']),
      sendBitrate: _doubleValue(map['sendBitrate']),
    );
  }

  /// Whether VLC reported that media statistics are available.
  final bool isAvailable;

  /// Bytes read by the current input module.
  final int readBytes;

  /// Current input bitrate.
  final double inputBitrate;

  /// Bytes read by the current demux module.
  final int demuxReadBytes;

  /// Current demux bitrate.
  final double demuxBitrate;

  /// Corrupted demux packets observed in the current session.
  final int demuxCorrupted;

  /// Demux discontinuities observed in the current session.
  final int demuxDiscontinuity;

  /// Decoded video blocks in the current session.
  final int decodedVideo;

  /// Decoded audio blocks in the current session.
  final int decodedAudio;

  /// Displayed pictures in the current session.
  final int displayedPictures;

  /// Lost pictures in the current session.
  final int lostPictures;

  /// Played audio buffers in the current session.
  final int playedAudioBuffers;

  /// Lost audio buffers in the current session.
  final int lostAudioBuffers;

  /// Sent stream-output packets in the current session.
  final int sentPackets;

  /// Sent stream-output bytes in the current session.
  final int sentBytes;

  /// Current stream-output send bitrate.
  final double sendBitrate;

  @override
  bool operator ==(Object other) {
    return other is VlcMediaStats &&
        other.isAvailable == isAvailable &&
        other.readBytes == readBytes &&
        other.inputBitrate == inputBitrate &&
        other.demuxReadBytes == demuxReadBytes &&
        other.demuxBitrate == demuxBitrate &&
        other.demuxCorrupted == demuxCorrupted &&
        other.demuxDiscontinuity == demuxDiscontinuity &&
        other.decodedVideo == decodedVideo &&
        other.decodedAudio == decodedAudio &&
        other.displayedPictures == displayedPictures &&
        other.lostPictures == lostPictures &&
        other.playedAudioBuffers == playedAudioBuffers &&
        other.lostAudioBuffers == lostAudioBuffers &&
        other.sentPackets == sentPackets &&
        other.sentBytes == sentBytes &&
        other.sendBitrate == sendBitrate;
  }

  @override
  int get hashCode => Object.hash(
    isAvailable,
    readBytes,
    inputBitrate,
    demuxReadBytes,
    demuxBitrate,
    demuxCorrupted,
    demuxDiscontinuity,
    decodedVideo,
    decodedAudio,
    displayedPictures,
    lostPictures,
    playedAudioBuffers,
    lostAudioBuffers,
    sentPackets,
    sentBytes,
    sendBitrate,
  );
}

bool _boolValue(Object? value) => value is bool && value;

int _intValue(Object? value) {
  if (value is int) {
    return value;
  }
  if (value is num && value.isFinite) {
    return value.toInt();
  }
  return 0;
}

double _doubleValue(Object? value) {
  if (value is num && value.isFinite) {
    return value.toDouble();
  }
  return 0;
}
