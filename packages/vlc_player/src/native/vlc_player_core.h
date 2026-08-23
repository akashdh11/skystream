#ifndef VLC_PLAYER_NATIVE_VLC_PLAYER_CORE_H_
#define VLC_PLAYER_NATIVE_VLC_PLAYER_CORE_H_

#include <atomic>
#include <cstddef>
#include <cstdint>
#include <functional>
#include <memory>
#include <mutex>
#include <string>
#include <vector>

#include <vlcpp/vlc.hpp>

#include "vlc_player_types.h"

namespace vlc_player {

class VlcPlayerCore {
 public:
  using FrameAvailableCallback = std::function<void()>;

  explicit VlcPlayerCore(std::vector<std::string> options,
                         FrameAvailableCallback on_frame_available);
  ~VlcPlayerCore();

  VlcPlayerCore(const VlcPlayerCore&) = delete;
  VlcPlayerCore& operator=(const VlcPlayerCore&) = delete;

  bool is_valid() const;
  const std::string& error() const;

  std::string SetSource(const std::string& uri,
                        const std::vector<std::string>& headers,
                        const std::vector<std::string>& media_options,
                        int64_t start_position,
                        bool auto_play);
  std::string Play();
  std::string Pause();
  std::string Stop();
  std::string SeekTo(int64_t milliseconds);
  std::string SetVolume(int volume);
  std::string SetPlaybackSpeed(double speed);
  std::string SetAudioDelay(int64_t microseconds);
  std::string SetSubtitleDelay(int64_t microseconds);
  std::vector<uint8_t> TakeSnapshot(uint32_t width,
                                    uint32_t height,
                                    std::string* error);

  std::vector<VlcTrackDescription> GetAudioTracks();
  std::string SetAudioTrack(int id);
  std::vector<VlcTrackDescription> GetSubtitleTracks();
  std::string SetSubtitleTrack(int id);
  std::string DisableSubtitle();
  std::string AddSubtitle(const std::string& uri);
  VlcMediaInfo GetMediaInfo();
  VlcMediaStats GetMediaStats();

  VlcSnapshot Snapshot();
  bool CopyPixels(const uint8_t** out_buffer, uint32_t* width, uint32_t* height);
  void Dispose();

#ifdef VLC_PLAYER_TESTING
  void ResizeVideoBufferForTesting(uint32_t width,
                                   uint32_t height,
                                   uint32_t pitch);
  void SimulateFrameForTesting(uint8_t value);
  const uint8_t* FrameBufferDataForTesting() const;
  size_t FrameBufferSizeForTesting() const;
  uint64_t RenderGenerationForTesting() const;
  uint64_t TextureGenerationForTesting() const;
#endif  // VLC_PLAYER_TESTING

 private:
  uint32_t SetupFormat(char* chroma,
                       uint32_t* width,
                       uint32_t* height,
                       uint32_t* pitches,
                       uint32_t* lines);
  void* Lock(void** planes);
  void Unlock(void* picture, void* const* planes);
  void Display(void* picture);
  void ResizeVideoBuffer(uint32_t width, uint32_t height, uint32_t pitch);
  std::string ActiveError() const;

  static std::string StateName(libvlc_state_t state);
  static bool IsReadyState(const std::string& state);
  static bool IsLiveState(const std::string& state);
  static std::string FourCCString(uint32_t value);
  static std::string TrackTypeName(VLC::MediaTrack::Type type);
  static VlcMediaTrackInfo MediaTrackInfo(const VLC::MediaTrack& track);
  static std::vector<VlcTrackDescription> TrackDescriptions(
      const std::vector<VLC::TrackDescription>& tracks);

  FrameAvailableCallback on_frame_available_;
  std::unique_ptr<VLC::Instance> instance_;
  std::unique_ptr<VLC::MediaPlayer> player_;
  std::string init_error_;
  std::atomic<bool> disposed_ = false;

  mutable std::mutex video_mutex_;
  std::vector<uint8_t> frame_buffer_;
  std::vector<uint8_t> render_buffer_;
  std::vector<uint8_t> texture_buffer_;
  uint32_t video_width_ = 0;
  uint32_t video_height_ = 0;
  uint32_t video_pitch_ = 0;
  uint64_t render_generation_ = 0;
  uint64_t texture_generation_ = 0;

  mutable std::mutex state_mutex_;
  int volume_ = 100;
  std::string state_override_;
  std::string error_code_;
  std::string error_description_;
};

}  // namespace vlc_player

#endif  // VLC_PLAYER_NATIVE_VLC_PLAYER_CORE_H_
