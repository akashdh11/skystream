#include "vlc_player_plugin.h"

#ifndef NOMINMAX
#define NOMINMAX
#endif
#include <windows.h>

#include <flutter/event_channel.h>
#include <flutter/event_sink.h>
#include <flutter/event_stream_handler_functions.h>
#include <flutter/method_channel.h>
#include <flutter/plugin_registrar_windows.h>
#include <flutter/standard_method_codec.h>
#include <flutter/texture_registrar.h>
#include <flutter_messenger.h>
#include <flutter_plugin_registrar.h>

#include <atomic>
#include <chrono>
#include <cmath>
#include <cstdint>
#include <memory>
#include <mutex>
#include <string>
#include <thread>
#include <utility>
#include <vector>

#include "vlc_player_core.h"

namespace vlc_player {
namespace {

using EncodableList = flutter::EncodableList;
using EncodableMap = flutter::EncodableMap;
using EncodableValue = flutter::EncodableValue;

std::wstring ExecutableDirectory() {
  std::wstring path(MAX_PATH, L'\0');
  while (true) {
    const DWORD length = GetModuleFileNameW(
        nullptr, path.data(), static_cast<DWORD>(path.size()));
    if (length == 0) {
      return L"";
    }
    if (static_cast<size_t>(length) < path.size()) {
      path.resize(length);
      break;
    }
    path.resize(path.size() * 2);
  }

  const size_t separator = path.find_last_of(L"\\/");
  return separator == std::wstring::npos ? L"" : path.substr(0, separator);
}

bool FileExists(const std::wstring &path) {
  const DWORD attributes = GetFileAttributesW(path.c_str());
  return attributes != INVALID_FILE_ATTRIBUTES &&
         (attributes & FILE_ATTRIBUTE_DIRECTORY) == 0;
}

bool DirectoryExists(const std::wstring &path) {
  const DWORD attributes = GetFileAttributesW(path.c_str());
  return attributes != INVALID_FILE_ATTRIBUTES &&
         (attributes & FILE_ATTRIBUTE_DIRECTORY) != 0;
}

bool ConfigureVlcRuntime(std::string *error) {
  const std::wstring app_directory = ExecutableDirectory();
  if (app_directory.empty()) {
    *error = "Unable to locate the Windows app directory.";
    return false;
  }

  const std::wstring bundled_libvlc = app_directory + L"\\libvlc.dll";
  const std::wstring bundled_libvlccore = app_directory + L"\\libvlccore.dll";
  const std::wstring plugins_directory = app_directory + L"\\plugins";
  if (!FileExists(bundled_libvlc) || !FileExists(bundled_libvlccore) ||
      !DirectoryExists(plugins_directory)) {
    *error =
        "The VLC Windows runtime is missing from the app bundle. Rebuild the "
        "Windows app so the plugin can download and bundle VLC.";
    return false;
  }

  SetEnvironmentVariableW(L"VLC_PLUGIN_PATH", plugins_directory.c_str());
  return true;
}

const EncodableValue *FindValue(const EncodableMap &map, const char *key) {
  auto it = map.find(EncodableValue(key));
  return it == map.end() ? nullptr : &it->second;
}

bool ReadInt64(const EncodableMap &map, const char *key, int64_t *value) {
  const EncodableValue *raw = FindValue(map, key);
  if (raw == nullptr) {
    return false;
  }
  if (const auto int_value = std::get_if<int32_t>(raw)) {
    *value = *int_value;
    return true;
  }
  if (const auto long_value = std::get_if<int64_t>(raw)) {
    *value = *long_value;
    return true;
  }
  return false;
}

bool ReadDouble(const EncodableMap &map, const char *key, double *value) {
  const EncodableValue *raw = FindValue(map, key);
  if (raw == nullptr) {
    return false;
  }
  if (const auto double_value = std::get_if<double>(raw)) {
    *value = *double_value;
    return true;
  }
  if (const auto int_value = std::get_if<int32_t>(raw)) {
    *value = *int_value;
    return true;
  }
  if (const auto long_value = std::get_if<int64_t>(raw)) {
    *value = static_cast<double>(*long_value);
    return true;
  }
  return false;
}

std::string ReadString(const EncodableMap &map, const char *key) {
  const EncodableValue *raw = FindValue(map, key);
  if (raw == nullptr) {
    return "";
  }
  if (const auto string_value = std::get_if<std::string>(raw)) {
    return *string_value;
  }
  return "";
}

bool ReadBool(const EncodableMap &map, const char *key) {
  const EncodableValue *raw = FindValue(map, key);
  if (raw == nullptr) {
    return false;
  }
  if (const auto bool_value = std::get_if<bool>(raw)) {
    return *bool_value;
  }
  return false;
}

std::vector<std::string> ReadStringList(const EncodableMap &map,
                                        const char *key) {
  std::vector<std::string> values;
  const EncodableValue *raw = FindValue(map, key);
  const auto list = raw == nullptr ? nullptr : std::get_if<EncodableList>(raw);
  if (list == nullptr) {
    return values;
  }
  for (const auto &item : *list) {
    if (const auto string_value = std::get_if<std::string>(&item)) {
      values.push_back(*string_value);
    }
  }
  return values;
}

// HTTP headers are translated to libVLC options in Dart
// (lib/src/vlc_http_headers.dart). libVLC 3.x can transmit only User-Agent and
// Referer, via :http-user-agent and :http-referrer; there is no `http-header`
// option in any VLC 3.x build, and emitting one here silently discarded every
// header the caller supplied. The raw map is still delivered in the payload for
// platform-specific mechanisms, but it produces no media options.
std::vector<std::string> ReadHeaders(const EncodableMap &map) {
  (void)map;
  return {};
}

EncodableValue NullableString(const std::string &value) {
  return value.empty() ? EncodableValue() : EncodableValue(value);
}

EncodableList TrackDescriptions(
    const std::vector<VlcTrackDescription> &tracks) {
  EncodableList result;
  for (const auto &track : tracks) {
    EncodableMap item;
    item[EncodableValue("id")] = EncodableValue(track.id);
    item[EncodableValue("name")] = EncodableValue(track.name);
    item[EncodableValue("language")] = NullableString(track.language);
    result.push_back(EncodableValue(item));
  }
  return result;
}

EncodableValue MediaTrackInfo(const VlcMediaTrackInfo &track) {
  EncodableMap info;
  info[EncodableValue("type")] = EncodableValue(track.type);
  info[EncodableValue("codec")] = NullableString(track.codec);
  info[EncodableValue("language")] = NullableString(track.language);
  info[EncodableValue("bitrate")] = EncodableValue(track.bitrate);
  if (track.width > 0) {
    info[EncodableValue("width")] = EncodableValue(track.width);
  }
  if (track.height > 0) {
    info[EncodableValue("height")] = EncodableValue(track.height);
  }
  if (track.channels > 0) {
    info[EncodableValue("channels")] = EncodableValue(track.channels);
  }
  if (track.sample_rate > 0) {
    info[EncodableValue("sampleRate")] = EncodableValue(track.sample_rate);
  }
  return EncodableValue(info);
}

EncodableList MediaTracks(const std::vector<VlcMediaTrackInfo> &tracks) {
  EncodableList result;
  for (const auto &track : tracks) {
    result.push_back(MediaTrackInfo(track));
  }
  return result;
}

EncodableMap MediaInfo(const VlcMediaInfo &info) {
  EncodableMap result;
  result[EncodableValue("title")] = NullableString(info.title);
  result[EncodableValue("artist")] = NullableString(info.artist);
  result[EncodableValue("album")] = NullableString(info.album);
  result[EncodableValue("duration")] = EncodableValue(info.duration);
  result[EncodableValue("videoTracks")] =
      EncodableValue(MediaTracks(info.video_tracks));
  result[EncodableValue("audioTracks")] =
      EncodableValue(MediaTracks(info.audio_tracks));
  result[EncodableValue("subtitleTracks")] =
      EncodableValue(MediaTracks(info.subtitle_tracks));
  return result;
}

EncodableMap MediaStats(const VlcMediaStats &stats) {
  EncodableMap result;
  result[EncodableValue("available")] = EncodableValue(stats.available);
  result[EncodableValue("readBytes")] = EncodableValue(stats.read_bytes);
  result[EncodableValue("inputBitrate")] = EncodableValue(stats.input_bitrate);
  result[EncodableValue("demuxReadBytes")] =
      EncodableValue(stats.demux_read_bytes);
  result[EncodableValue("demuxBitrate")] = EncodableValue(stats.demux_bitrate);
  result[EncodableValue("demuxCorrupted")] =
      EncodableValue(stats.demux_corrupted);
  result[EncodableValue("demuxDiscontinuity")] =
      EncodableValue(stats.demux_discontinuity);
  result[EncodableValue("decodedVideo")] = EncodableValue(stats.decoded_video);
  result[EncodableValue("decodedAudio")] = EncodableValue(stats.decoded_audio);
  result[EncodableValue("displayedPictures")] =
      EncodableValue(stats.displayed_pictures);
  result[EncodableValue("lostPictures")] = EncodableValue(stats.lost_pictures);
  result[EncodableValue("playedAudioBuffers")] =
      EncodableValue(stats.played_audio_buffers);
  result[EncodableValue("lostAudioBuffers")] =
      EncodableValue(stats.lost_audio_buffers);
  result[EncodableValue("sentPackets")] = EncodableValue(stats.sent_packets);
  result[EncodableValue("sentBytes")] = EncodableValue(stats.sent_bytes);
  result[EncodableValue("sendBitrate")] = EncodableValue(stats.send_bitrate);
  return result;
}

}  // namespace

class WindowsVlcPlayer {
 public:
  WindowsVlcPlayer(int64_t view_id, flutter::BinaryMessenger *messenger,
                   flutter::TextureRegistrar *texture_registrar,
                   FlutterDesktopMessengerRef messenger_ref)
      : texture_registrar_(texture_registrar),
        messenger_ref_(messenger_ref),
        event_channel_(messenger, "vlc_player/events/" + std::to_string(view_id),
                       &flutter::StandardMethodCodec::GetInstance()) {
    auto stream_handler =
        std::make_unique<flutter::StreamHandlerFunctions<EncodableValue>>(
            [this](const EncodableValue *arguments,
                   std::unique_ptr<flutter::EventSink<EncodableValue>> &&events)
                -> std::unique_ptr<
                    flutter::StreamHandlerError<EncodableValue>> {
              {
                std::lock_guard<std::mutex> lock(event_mutex_);
                event_sink_ = std::move(events);
              }
              SendSnapshot(false, true);
              return nullptr;
            },
            [this](const EncodableValue *arguments)
                -> std::unique_ptr<
                    flutter::StreamHandlerError<EncodableValue>> {
              std::lock_guard<std::mutex> lock(event_mutex_);
              event_sink_.reset();
              return nullptr;
            });
    event_channel_.SetStreamHandler(std::move(stream_handler));

    texture_ = std::make_unique<flutter::TextureVariant>(
        flutter::PixelBufferTexture([this](size_t width, size_t height) {
          return CopyPixelBuffer(width, height);
        }));
    texture_id_ = texture_registrar_->RegisterTexture(texture_.get());
    if (texture_id_ == -1) {
      init_error_ = "Unable to register the vlc_player texture.";
    }
  }

  void Initialize(const std::vector<std::string> &options) {
    std::lock_guard<std::mutex> lock(lifecycle_mutex_);
    if (!init_error_.empty() || disposed_.load()) {
      return;
    }
    core_ = std::make_unique<VlcPlayerCore>(options, [this] {
      if (!disposed_.load() && texture_id_ != -1) {
        texture_registrar_->MarkTextureFrameAvailable(texture_id_);
      }
    });
    if (!core_->is_valid()) {
      init_error_ = core_->error();
      return;
    }

    polling_ = true;
    polling_thread_ = std::thread([this] {
      while (polling_.load()) {
        std::this_thread::sleep_for(std::chrono::milliseconds(500));
        SendSnapshot(true);
      }
    });
  }

  ~WindowsVlcPlayer() {
    DetachFromFlutter();
    DisposeCore();
  }

  bool is_valid() const {
    return init_error_.empty() && texture_id_ != -1 && core_ != nullptr;
  }
  const std::string &error() const { return init_error_; }
  int64_t texture_id() const { return texture_id_; }

  std::string SetSource(const std::string &uri,
                        const std::vector<std::string> &headers,
                        const std::vector<std::string> &media_options,
                        int64_t start_position,
                        bool auto_play) {
    const std::string error =
        core_->SetSource(uri, headers, media_options, start_position, false);
    SendSnapshot();
    if (!error.empty() || !auto_play) {
      return error;
    }
    return Play();
  }

  std::string Play() {
    return RunAndSendSnapshot([this] { return core_->Play(); });
  }

  std::string Pause() {
    return RunAndSendSnapshot([this] { return core_->Pause(); });
  }

  std::string Stop() {
    return RunAndSendSnapshot([this] { return core_->Stop(); });
  }

  std::string SeekTo(int64_t milliseconds) {
    return RunAndSendSnapshot([this, milliseconds] {
      return core_->SeekTo(milliseconds);
    });
  }

  std::string SetVolume(int volume) {
    return RunAndSendSnapshot([this, volume] {
      return core_->SetVolume(volume);
    });
  }

  std::string SetPlaybackSpeed(double speed) {
    return RunAndSendSnapshot([this, speed] {
      return core_->SetPlaybackSpeed(speed);
    });
  }

  std::string SetAudioDelay(int64_t microseconds) {
    return RunAndSendSnapshot([this, microseconds] {
      return core_->SetAudioDelay(microseconds);
    });
  }

  std::string SetSubtitleDelay(int64_t microseconds) {
    return RunAndSendSnapshot([this, microseconds] {
      return core_->SetSubtitleDelay(microseconds);
    });
  }

  std::vector<uint8_t> TakeSnapshot(uint32_t width,
                                    uint32_t height,
                                    std::string *error) {
    std::vector<uint8_t> data = core_->TakeSnapshot(width, height, error);
    SendSnapshot();
    return data;
  }

  EncodableList GetAudioTracks() {
    return TrackDescriptions(core_->GetAudioTracks());
  }

  std::string SetAudioTrack(int id) { return core_->SetAudioTrack(id); }

  EncodableList GetSubtitleTracks() {
    return TrackDescriptions(core_->GetSubtitleTracks());
  }

  std::string SetSubtitleTrack(int id) { return core_->SetSubtitleTrack(id); }
  std::string DisableSubtitle() { return core_->DisableSubtitle(); }
  std::string AddSubtitle(const std::string &uri) {
    return core_->AddSubtitle(uri);
  }
  EncodableMap GetMediaInfo() { return MediaInfo(core_->GetMediaInfo()); }
  EncodableMap GetMediaStats() { return MediaStats(core_->GetMediaStats()); }

  void DetachFromFlutter() {
    if (flutter_detached_.exchange(true)) {
      return;
    }
    {
      std::lock_guard<std::mutex> lock(event_mutex_);
      event_sink_.reset();
    }
    event_channel_.SetStreamHandler(nullptr);
  }

  void DisposeCore() {
    if (disposed_.exchange(true)) {
      return;
    }
    std::lock_guard<std::mutex> lock(lifecycle_mutex_);
    polling_ = false;
    if (polling_thread_.joinable()) {
      polling_thread_.join();
    }

    if (core_ != nullptr) {
      core_->Dispose();
      core_.reset();
    }
    if (texture_id_ != -1) {
      texture_registrar_->UnregisterTexture(texture_id_);
      texture_id_ = -1;
    }
    texture_.reset();
  }

 private:
  template <typename Operation>
  std::string RunAndSendSnapshot(Operation operation) {
    const std::string error = operation();
    SendSnapshot();
    return error;
  }

  const FlutterDesktopPixelBuffer *CopyPixelBuffer(size_t width,
                                                   size_t height) {
    if (core_ == nullptr) {
      return nullptr;
    }
    const uint8_t *buffer = nullptr;
    uint32_t pixel_width = 0;
    uint32_t pixel_height = 0;
    if (!core_->CopyPixels(&buffer, &pixel_width, &pixel_height)) {
      return nullptr;
    }
    pixel_buffer_.buffer = buffer;
    pixel_buffer_.width = pixel_width;
    pixel_buffer_.height = pixel_height;
    pixel_buffer_.release_callback = nullptr;
    pixel_buffer_.release_context = nullptr;
    return &pixel_buffer_;
  }

  void SendSnapshot(bool lock_messenger = false, bool force = false) {
    if (disposed_.load() || core_ == nullptr) {
      return;
    }
    {
      std::lock_guard<std::mutex> lock(event_mutex_);
      if (!event_sink_) {
        return;
      }
    }

    const VlcSnapshot snapshot = core_->Snapshot();

    std::lock_guard<std::mutex> lock(event_mutex_);
    if (!event_sink_) {
      return;
    }
    if (!force && has_last_sent_snapshot_ &&
        snapshot == last_sent_snapshot_) {
      return;
    }
    last_sent_snapshot_ = snapshot;
    has_last_sent_snapshot_ = true;

    EncodableMap event;
    event[EncodableValue("state")] = EncodableValue(snapshot.state);
    event[EncodableValue("position")] = EncodableValue(snapshot.position);
    event[EncodableValue("duration")] = EncodableValue(snapshot.duration);
    event[EncodableValue("volume")] = EncodableValue(snapshot.volume);
    event[EncodableValue("playbackSpeed")] =
        EncodableValue(snapshot.playback_speed);
    event[EncodableValue("audioDelay")] =
        EncodableValue(snapshot.audio_delay);
    event[EncodableValue("subtitleDelay")] =
        EncodableValue(snapshot.subtitle_delay);
    event[EncodableValue("isReady")] = EncodableValue(snapshot.is_ready);
    event[EncodableValue("isSeekable")] = EncodableValue(snapshot.is_seekable);
    event[EncodableValue("isLive")] = EncodableValue(snapshot.is_live);
    if (snapshot.video_width > 0 && snapshot.video_height > 0) {
      EncodableMap video_size;
      video_size[EncodableValue("width")] =
          EncodableValue(snapshot.video_width);
      video_size[EncodableValue("height")] =
          EncodableValue(snapshot.video_height);
      event[EncodableValue("videoSize")] = EncodableValue(video_size);
    }
    if (snapshot.buffering_progress >= 0.0) {
      event[EncodableValue("bufferingProgress")] =
          EncodableValue(snapshot.buffering_progress);
    }
    if (!snapshot.error_description.empty()) {
      const std::string error_code =
          snapshot.error_code.empty() ? "playback_error" : snapshot.error_code;
      event[EncodableValue("errorCode")] = EncodableValue(error_code);
      event[EncodableValue("errorDescription")] =
          EncodableValue(snapshot.error_description);
    }

    if (lock_messenger && messenger_ref_ != nullptr) {
      FlutterDesktopMessengerLock(messenger_ref_);
      if (FlutterDesktopMessengerIsAvailable(messenger_ref_)) {
        event_sink_->Success(EncodableValue(event));
      }
      FlutterDesktopMessengerUnlock(messenger_ref_);
      return;
    }
    event_sink_->Success(EncodableValue(event));
  }

  flutter::TextureRegistrar *texture_registrar_;
  FlutterDesktopMessengerRef messenger_ref_;
  flutter::EventChannel<EncodableValue> event_channel_;
  std::unique_ptr<flutter::EventSink<EncodableValue>> event_sink_;
  std::mutex event_mutex_;
  bool has_last_sent_snapshot_ = false;
  VlcSnapshot last_sent_snapshot_;

  std::unique_ptr<VlcPlayerCore> core_;
  std::string init_error_;
  std::atomic<bool> disposed_ = false;
  std::atomic<bool> flutter_detached_ = false;
  std::mutex lifecycle_mutex_;
  std::atomic<bool> polling_ = false;
  std::thread polling_thread_;

  std::unique_ptr<flutter::TextureVariant> texture_;
  int64_t texture_id_ = -1;
  FlutterDesktopPixelBuffer pixel_buffer_ = {};
};

// static
void VlcPlayerPlugin::RegisterWithRegistrar(
    flutter::PluginRegistrarWindows *registrar) {
  RegisterWithRegistrar(registrar, nullptr);
}

void VlcPlayerPlugin::RegisterWithRegistrar(
    flutter::PluginRegistrarWindows *registrar,
    FlutterDesktopPluginRegistrarRef core_registrar) {
  auto channel =
      std::make_unique<flutter::MethodChannel<EncodableValue>>(
          registrar->messenger(), "vlc_player",
          &flutter::StandardMethodCodec::GetInstance());

  FlutterDesktopMessengerRef messenger_ref = nullptr;
  if (core_registrar != nullptr) {
    FlutterDesktopMessengerRef registrar_messenger =
        FlutterDesktopPluginRegistrarGetMessenger(core_registrar);
    if (registrar_messenger != nullptr) {
      messenger_ref = FlutterDesktopMessengerAddRef(registrar_messenger);
    }
  }

  auto plugin = std::make_unique<VlcPlayerPlugin>(
      registrar->messenger(), registrar->texture_registrar(), messenger_ref);

  channel->SetMethodCallHandler(
      [plugin_pointer = plugin.get()](const auto &call, auto result) {
        plugin_pointer->HandleMethodCall(call, std::move(result));
      });

  registrar->AddPlugin(std::move(plugin));
}

VlcPlayerPlugin::VlcPlayerPlugin(flutter::BinaryMessenger *messenger,
                                 flutter::TextureRegistrar *texture_registrar,
                                 FlutterDesktopMessengerRef messenger_ref)
    : messenger_(messenger),
      texture_registrar_(texture_registrar),
      messenger_ref_(messenger_ref) {}

VlcPlayerPlugin::~VlcPlayerPlugin() {
  for (auto &thread : create_threads_) {
    if (thread.joinable()) {
      thread.join();
    }
  }
  for (auto &thread : dispose_threads_) {
    if (thread.joinable()) {
      thread.join();
    }
  }
  {
    std::lock_guard<std::mutex> lock(players_mutex_);
    players_.clear();
  }
  if (messenger_ref_ != nullptr) {
    FlutterDesktopMessengerRelease(messenger_ref_);
    messenger_ref_ = nullptr;
  }
}

void VlcPlayerPlugin::HandleMethodCall(
    const flutter::MethodCall<EncodableValue> &method_call,
    std::unique_ptr<flutter::MethodResult<EncodableValue>> result) {
  const auto *arguments = std::get_if<EncodableMap>(method_call.arguments());

  if (method_call.method_name() == "create") {
    const auto options = arguments == nullptr
                             ? std::vector<std::string>()
                             : ReadStringList(*arguments, "options");
    const int64_t view_id = next_view_id_++;
    std::string runtime_error;
    if (!ConfigureVlcRuntime(&runtime_error)) {
      result->Error("vlc_not_found", runtime_error);
      return;
    }
    auto player = std::make_shared<WindowsVlcPlayer>(
        view_id, messenger_, texture_registrar_, messenger_ref_);
    if (player->texture_id() == -1) {
      result->Error("create_failed", player->error());
      return;
    }
    {
      std::lock_guard<std::mutex> lock(players_mutex_);
      players_[view_id] = player;
    }
    create_threads_.emplace_back(
        [this, view_id, options, player,
         result = std::move(result)]() mutable {
          player->Initialize(options);
          if (!player->is_valid()) {
            const std::string error = player->error();
            {
              std::lock_guard<std::mutex> lock(players_mutex_);
              const auto it = players_.find(view_id);
              if (it != players_.end() && it->second == player) {
                players_.erase(it);
              }
            }
            player->DetachFromFlutter();
            player->DisposeCore();
            result->Error("create_failed", error);
            return;
          }

          const int64_t texture_id = player->texture_id();
          {
            std::lock_guard<std::mutex> lock(players_mutex_);
            const auto it = players_.find(view_id);
            if (it == players_.end() || it->second != player) {
              result->Error("player_not_found",
                            "The vlc_player was disposed during creation.");
              return;
            }
          }

          EncodableMap response;
          response[EncodableValue("viewId")] = EncodableValue(view_id);
          response[EncodableValue("textureId")] = EncodableValue(texture_id);
          result->Success(EncodableValue(response));
        });
    return;
  }

  if (arguments == nullptr) {
    result->Error("invalid_args", "A valid argument map is required.");
    return;
  }

  int64_t view_id = 0;
  if (!ReadInt64(*arguments, "viewId", &view_id)) {
    result->Error("invalid_args", "A valid viewId is required.");
    return;
  }

  if (method_call.method_name() == "dispose") {
    DisposePlayer(view_id);
    result->Success();
    return;
  }

  std::shared_ptr<WindowsVlcPlayer> player = FindPlayer(*arguments, result.get());
  if (!player) {
    return;
  }

  std::string error;
  if (method_call.method_name() == "setSource") {
    int64_t start_position = 0;
    if (ReadInt64(*arguments, "startPosition", &start_position) &&
        start_position < 0) {
      result->Error("invalid_args",
                    "A non-negative startPosition is required.");
      return;
    }
    error = player->SetSource(ReadString(*arguments, "uri"),
                              ReadHeaders(*arguments),
                              ReadStringList(*arguments, "mediaOptions"),
                              start_position,
                              ReadBool(*arguments, "autoPlay"));
    if (error == "A non-empty uri is required.") {
      result->Error("invalid_args", error);
      return;
    }
  } else if (method_call.method_name() == "play") {
    error = player->Play();
  } else if (method_call.method_name() == "pause") {
    error = player->Pause();
  } else if (method_call.method_name() == "stop") {
    error = player->Stop();
  } else if (method_call.method_name() == "seekTo") {
    int64_t position = 0;
    if (!ReadInt64(*arguments, "position", &position) || position < 0) {
      result->Error("invalid_args", "A non-negative position is required.");
      return;
    }
    error = player->SeekTo(position);
  } else if (method_call.method_name() == "setVolume") {
    int64_t volume = 0;
    if (!ReadInt64(*arguments, "volume", &volume)) {
      result->Error("invalid_args", "A volume value is required.");
      return;
    }
    error = player->SetVolume(static_cast<int>(volume));
  } else if (method_call.method_name() == "setPlaybackSpeed") {
    double speed = 0;
    if (!ReadDouble(*arguments, "speed", &speed) ||
        !std::isfinite(speed) || speed <= 0) {
      result->Error("invalid_args",
                    "A finite positive playback speed is required.");
      return;
    }
    error = player->SetPlaybackSpeed(speed);
  } else if (method_call.method_name() == "setAudioDelay") {
    int64_t delay = 0;
    if (!ReadInt64(*arguments, "delay", &delay)) {
      result->Error("invalid_args", "An audio delay value is required.");
      return;
    }
    error = player->SetAudioDelay(delay);
  } else if (method_call.method_name() == "setSubtitleDelay") {
    int64_t delay = 0;
    if (!ReadInt64(*arguments, "delay", &delay)) {
      result->Error("invalid_args", "A subtitle delay value is required.");
      return;
    }
    error = player->SetSubtitleDelay(delay);
  } else if (method_call.method_name() == "takeSnapshot") {
    int64_t width = 0;
    int64_t height = 0;
    if (ReadInt64(*arguments, "width", &width) && width <= 0) {
      result->Error("invalid_args", "Snapshot dimensions must be positive.");
      return;
    }
    if (ReadInt64(*arguments, "height", &height) && height <= 0) {
      result->Error("invalid_args", "Snapshot dimensions must be positive.");
      return;
    }
    std::string snapshot_error;
    const std::vector<uint8_t> data = player->TakeSnapshot(
        static_cast<uint32_t>(width), static_cast<uint32_t>(height),
        &snapshot_error);
    if (!snapshot_error.empty()) {
      result->Error("snapshot_failed", snapshot_error);
      return;
    }
    result->Success(EncodableValue(data));
    return;
  } else if (method_call.method_name() == "getAudioTracks") {
    result->Success(EncodableValue(player->GetAudioTracks()));
    return;
  } else if (method_call.method_name() == "setAudioTrack") {
    int64_t id = 0;
    if (!ReadInt64(*arguments, "id", &id) || id < 0) {
      result->Error("invalid_args",
                    "A non-negative audio track id is required.");
      return;
    }
    error = player->SetAudioTrack(static_cast<int>(id));
  } else if (method_call.method_name() == "getSubtitleTracks") {
    result->Success(EncodableValue(player->GetSubtitleTracks()));
    return;
  } else if (method_call.method_name() == "setSubtitleTrack") {
    int64_t id = 0;
    if (!ReadInt64(*arguments, "id", &id) || id < 0) {
      result->Error("invalid_args",
                    "A non-negative subtitle track id is required.");
      return;
    }
    error = player->SetSubtitleTrack(static_cast<int>(id));
  } else if (method_call.method_name() == "disableSubtitle") {
    error = player->DisableSubtitle();
  } else if (method_call.method_name() == "addSubtitle") {
    error = player->AddSubtitle(ReadString(*arguments, "uri"));
    if (error == "A non-empty subtitle uri is required.") {
      result->Error("invalid_args", error);
      return;
    }
  } else if (method_call.method_name() == "setFit") {
    result->Success();
    return;
  } else if (method_call.method_name() == "getMediaInfo") {
    result->Success(EncodableValue(player->GetMediaInfo()));
    return;
  } else if (method_call.method_name() == "getMediaStats") {
    result->Success(EncodableValue(player->GetMediaStats()));
    return;
  } else {
    result->NotImplemented();
    return;
  }

  if (!error.empty()) {
    result->Error("vlc_error", error);
    return;
  }
  result->Success();
}

std::shared_ptr<WindowsVlcPlayer> VlcPlayerPlugin::FindPlayer(
    const EncodableMap &arguments,
    flutter::MethodResult<EncodableValue> *result) {
  int64_t view_id = 0;
  if (!ReadInt64(arguments, "viewId", &view_id)) {
    result->Error("invalid_args", "A valid viewId is required.");
    return nullptr;
  }

  std::lock_guard<std::mutex> lock(players_mutex_);
  auto it = players_.find(view_id);
  if (it == players_.end()) {
    result->Error("player_not_found",
                  "No vlc_player player exists for viewId " +
                      std::to_string(view_id) + ".");
    return nullptr;
  }
  return it->second;
}

void VlcPlayerPlugin::DisposePlayer(int64_t view_id) {
  std::shared_ptr<WindowsVlcPlayer> player;
  {
    std::lock_guard<std::mutex> lock(players_mutex_);
    auto it = players_.find(view_id);
    if (it != players_.end()) {
      player = std::move(it->second);
      players_.erase(it);
    }
  }
  if (!player) {
    return;
  }
  player->DetachFromFlutter();
  dispose_threads_.emplace_back([player = std::move(player)] {
    player->DisposeCore();
  });
}

}  // namespace vlc_player
