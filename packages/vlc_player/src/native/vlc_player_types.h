#ifndef VLC_PLAYER_NATIVE_VLC_PLAYER_TYPES_H_
#define VLC_PLAYER_NATIVE_VLC_PLAYER_TYPES_H_

#include <cstdint>
#include <string>
#include <vector>

namespace vlc_player {

struct VlcTrackDescription {
  int id = -1;
  std::string name;
  std::string language;
};

struct VlcMediaTrackInfo {
  std::string type = "unknown";
  std::string codec;
  std::string language;
  int64_t bitrate = 0;
  int64_t width = 0;
  int64_t height = 0;
  int64_t channels = 0;
  int64_t sample_rate = 0;
};

struct VlcMediaInfo {
  std::string title;
  std::string artist;
  std::string album;
  int64_t duration = 0;
  std::vector<VlcMediaTrackInfo> video_tracks;
  std::vector<VlcMediaTrackInfo> audio_tracks;
  std::vector<VlcMediaTrackInfo> subtitle_tracks;
};

struct VlcMediaStats {
  bool available = false;
  int64_t read_bytes = 0;
  double input_bitrate = 0.0;
  int64_t demux_read_bytes = 0;
  double demux_bitrate = 0.0;
  int64_t demux_corrupted = 0;
  int64_t demux_discontinuity = 0;
  int64_t decoded_video = 0;
  int64_t decoded_audio = 0;
  int64_t displayed_pictures = 0;
  int64_t lost_pictures = 0;
  int64_t played_audio_buffers = 0;
  int64_t lost_audio_buffers = 0;
  int64_t sent_packets = 0;
  int64_t sent_bytes = 0;
  double send_bitrate = 0.0;
};

struct VlcSnapshot {
  std::string state = "idle";
  int64_t position = 0;
  int64_t duration = 0;
  int volume = 100;
  double playback_speed = 1.0;
  int64_t audio_delay = 0;
  int64_t subtitle_delay = 0;
  bool is_ready = false;
  bool is_seekable = false;
  bool is_live = false;
  int64_t video_width = 0;
  int64_t video_height = 0;
  double buffering_progress = -1.0;
  std::string error_code;
  std::string error_description;
};

inline bool operator==(const VlcSnapshot& lhs, const VlcSnapshot& rhs) {
  return lhs.state == rhs.state && lhs.position == rhs.position &&
         lhs.duration == rhs.duration && lhs.volume == rhs.volume &&
         lhs.playback_speed == rhs.playback_speed &&
         lhs.audio_delay == rhs.audio_delay &&
         lhs.subtitle_delay == rhs.subtitle_delay &&
         lhs.is_ready == rhs.is_ready && lhs.is_seekable == rhs.is_seekable &&
         lhs.is_live == rhs.is_live && lhs.video_width == rhs.video_width &&
         lhs.video_height == rhs.video_height &&
         lhs.buffering_progress == rhs.buffering_progress &&
         lhs.error_code == rhs.error_code &&
         lhs.error_description == rhs.error_description;
}

inline bool operator!=(const VlcSnapshot& lhs, const VlcSnapshot& rhs) {
  return !(lhs == rhs);
}

}  // namespace vlc_player

#endif  // VLC_PLAYER_NATIVE_VLC_PLAYER_TYPES_H_
