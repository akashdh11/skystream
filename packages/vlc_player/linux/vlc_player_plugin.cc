#include "include/vlc_player/vlc_player_plugin.h"

#include <flutter_linux/flutter_linux.h>
#include <gtk/gtk.h>
#include <sys/utsname.h>

#include <atomic>
#include <chrono>
#include <cmath>
#include <cstring>
#include <map>
#include <memory>
#include <mutex>
#include <string>
#include <thread>
#include <vector>

#include "vlc_player_plugin_private.h"
#include "vlc_player_core.h"

#define VLC_PLAYER_PLUGIN(obj) \
  (G_TYPE_CHECK_INSTANCE_CAST((obj), vlc_player_plugin_get_type(), \
                              VlcPlayerPlugin))

namespace {

class LinuxVlcPlayer;

typedef struct _VlcPixelBufferTexture {
  FlPixelBufferTexture parent_instance;
  LinuxVlcPlayer* player;
} VlcPixelBufferTexture;

typedef struct {
  FlPixelBufferTextureClass parent_class;
} VlcPixelBufferTextureClass;

G_DEFINE_TYPE(VlcPixelBufferTexture,
              vlc_pixel_buffer_texture,
              fl_pixel_buffer_texture_get_type())

FlValue* StringOrNull(const std::string& value) {
  return value.empty() ? fl_value_new_null()
                       : fl_value_new_string(value.c_str());
}

FlValue* TrackDescriptions(
    const std::vector<vlc_player::VlcTrackDescription>& tracks) {
  FlValue* result = fl_value_new_list();
  for (const auto& track : tracks) {
    FlValue* item = fl_value_new_map();
    fl_value_set_string_take(item, "id", fl_value_new_int(track.id));
    fl_value_set_string_take(item, "name",
                             fl_value_new_string(track.name.c_str()));
    fl_value_set_string_take(item, "language", StringOrNull(track.language));
    fl_value_append_take(result, item);
  }
  return result;
}

FlValue* MediaTrackInfo(const vlc_player::VlcMediaTrackInfo& track) {
  FlValue* info = fl_value_new_map();
  fl_value_set_string_take(info, "type", fl_value_new_string(track.type.c_str()));
  fl_value_set_string_take(info, "codec", StringOrNull(track.codec));
  fl_value_set_string_take(info, "language", StringOrNull(track.language));
  fl_value_set_string_take(info, "bitrate", fl_value_new_int(track.bitrate));
  if (track.width > 0) {
    fl_value_set_string_take(info, "width", fl_value_new_int(track.width));
  }
  if (track.height > 0) {
    fl_value_set_string_take(info, "height", fl_value_new_int(track.height));
  }
  if (track.channels > 0) {
    fl_value_set_string_take(info, "channels",
                             fl_value_new_int(track.channels));
  }
  if (track.sample_rate > 0) {
    fl_value_set_string_take(info, "sampleRate",
                             fl_value_new_int(track.sample_rate));
  }
  return info;
}

FlValue* MediaTracks(
    const std::vector<vlc_player::VlcMediaTrackInfo>& tracks) {
  FlValue* result = fl_value_new_list();
  for (const auto& track : tracks) {
    fl_value_append_take(result, MediaTrackInfo(track));
  }
  return result;
}

FlValue* MediaInfo(const vlc_player::VlcMediaInfo& media_info) {
  FlValue* info = fl_value_new_map();
  fl_value_set_string_take(info, "title", StringOrNull(media_info.title));
  fl_value_set_string_take(info, "artist", StringOrNull(media_info.artist));
  fl_value_set_string_take(info, "album", StringOrNull(media_info.album));
  fl_value_set_string_take(info, "duration",
                           fl_value_new_int(media_info.duration));
  fl_value_set_string_take(info, "videoTracks",
                           MediaTracks(media_info.video_tracks));
  fl_value_set_string_take(info, "audioTracks",
                           MediaTracks(media_info.audio_tracks));
  fl_value_set_string_take(info, "subtitleTracks",
                           MediaTracks(media_info.subtitle_tracks));
  return info;
}

FlValue* MediaStats(const vlc_player::VlcMediaStats& stats) {
  FlValue* result = fl_value_new_map();
  fl_value_set_string_take(result, "available",
                           fl_value_new_bool(stats.available));
  fl_value_set_string_take(result, "readBytes",
                           fl_value_new_int(stats.read_bytes));
  fl_value_set_string_take(result, "inputBitrate",
                           fl_value_new_float(stats.input_bitrate));
  fl_value_set_string_take(result, "demuxReadBytes",
                           fl_value_new_int(stats.demux_read_bytes));
  fl_value_set_string_take(result, "demuxBitrate",
                           fl_value_new_float(stats.demux_bitrate));
  fl_value_set_string_take(result, "demuxCorrupted",
                           fl_value_new_int(stats.demux_corrupted));
  fl_value_set_string_take(result, "demuxDiscontinuity",
                           fl_value_new_int(stats.demux_discontinuity));
  fl_value_set_string_take(result, "decodedVideo",
                           fl_value_new_int(stats.decoded_video));
  fl_value_set_string_take(result, "decodedAudio",
                           fl_value_new_int(stats.decoded_audio));
  fl_value_set_string_take(result, "displayedPictures",
                           fl_value_new_int(stats.displayed_pictures));
  fl_value_set_string_take(result, "lostPictures",
                           fl_value_new_int(stats.lost_pictures));
  fl_value_set_string_take(result, "playedAudioBuffers",
                           fl_value_new_int(stats.played_audio_buffers));
  fl_value_set_string_take(result, "lostAudioBuffers",
                           fl_value_new_int(stats.lost_audio_buffers));
  fl_value_set_string_take(result, "sentPackets",
                           fl_value_new_int(stats.sent_packets));
  fl_value_set_string_take(result, "sentBytes",
                           fl_value_new_int(stats.sent_bytes));
  fl_value_set_string_take(result, "sendBitrate",
                           fl_value_new_float(stats.send_bitrate));
  return result;
}

FlValue* FindValue(FlValue* map, const gchar* key) {
  if (map == nullptr || fl_value_get_type(map) != FL_VALUE_TYPE_MAP) {
    return nullptr;
  }
  return fl_value_lookup_string(map, key);
}

std::string ReadString(FlValue* map, const gchar* key) {
  FlValue* value = FindValue(map, key);
  if (value == nullptr || fl_value_get_type(value) != FL_VALUE_TYPE_STRING) {
    return "";
  }
  return fl_value_get_string(value);
}

bool ReadBool(FlValue* map, const gchar* key) {
  FlValue* value = FindValue(map, key);
  return value != nullptr && fl_value_get_type(value) == FL_VALUE_TYPE_BOOL &&
         fl_value_get_bool(value);
}

bool ReadInt(FlValue* map, const gchar* key, int64_t* result) {
  FlValue* value = FindValue(map, key);
  if (value == nullptr || fl_value_get_type(value) != FL_VALUE_TYPE_INT) {
    return false;
  }
  *result = fl_value_get_int(value);
  return true;
}

bool ReadDouble(FlValue* map, const gchar* key, double* result) {
  FlValue* value = FindValue(map, key);
  if (value == nullptr) {
    return false;
  }
  if (fl_value_get_type(value) == FL_VALUE_TYPE_FLOAT) {
    *result = fl_value_get_float(value);
    return true;
  }
  if (fl_value_get_type(value) == FL_VALUE_TYPE_INT) {
    *result = static_cast<double>(fl_value_get_int(value));
    return true;
  }
  return false;
}

std::vector<std::string> ReadStringList(FlValue* map, const gchar* key) {
  std::vector<std::string> result;
  FlValue* value = FindValue(map, key);
  if (value == nullptr || fl_value_get_type(value) != FL_VALUE_TYPE_LIST) {
    return result;
  }
  const size_t length = fl_value_get_length(value);
  for (size_t i = 0; i < length; ++i) {
    FlValue* item = fl_value_get_list_value(value, i);
    if (fl_value_get_type(item) == FL_VALUE_TYPE_STRING) {
      result.push_back(fl_value_get_string(item));
    }
  }
  return result;
}

// HTTP headers are translated to libVLC options in Dart
// (lib/src/vlc_http_headers.dart). libVLC 3.x can transmit only User-Agent and
// Referer, via :http-user-agent and :http-referrer; there is no `http-header`
// option in any VLC 3.x build, and emitting one here silently discarded every
// header the caller supplied. The raw map is still delivered in the payload for
// platform-specific mechanisms, but it produces no media options.
std::vector<std::string> ReadHeaders(FlValue* map) {
  (void)map;
  return {};
}

class LinuxVlcPlayer {
 public:
  LinuxVlcPlayer(int64_t view_id,
                 FlBinaryMessenger* messenger,
                 FlTextureRegistrar* texture_registrar,
                 const std::vector<std::string>& options)
      : texture_registrar_(texture_registrar) {
    g_autoptr(FlStandardMethodCodec) codec = fl_standard_method_codec_new();
    event_channel_ = fl_event_channel_new(
        messenger, ("vlc_player/events/" + std::to_string(view_id)).c_str(),
        FL_METHOD_CODEC(codec));
    fl_event_channel_set_stream_handlers(event_channel_, Listen, Cancel, this,
                                         nullptr);

    core_ = std::make_unique<vlc_player::VlcPlayerCore>(options, [this] {
      if (!disposed_.load() && texture_ != nullptr) {
        fl_texture_registrar_mark_texture_frame_available(
            texture_registrar_, FL_TEXTURE(texture_));
      }
    });
    if (!core_->is_valid()) {
      init_error_ = core_->error();
      return;
    }

    texture_ = reinterpret_cast<VlcPixelBufferTexture*>(
        g_object_new(vlc_pixel_buffer_texture_get_type(), nullptr));
    texture_->player = this;
    if (!fl_texture_registrar_register_texture(
            texture_registrar_, FL_TEXTURE(texture_))) {
      init_error_ = "Unable to register Flutter texture.";
      return;
    }
    texture_id_ = fl_texture_get_id(FL_TEXTURE(texture_));

    polling_ = true;
    polling_thread_ = std::thread([this] {
      while (polling_.load()) {
        std::this_thread::sleep_for(std::chrono::milliseconds(500));
        SendSnapshot();
      }
    });
  }

  ~LinuxVlcPlayer() { Dispose(); }

  bool is_valid() const { return init_error_.empty() && texture_id_ != -1; }
  const std::string& error() const { return init_error_; }
  int64_t texture_id() const { return texture_id_; }

  std::string SetSource(const std::string& uri,
                        const std::vector<std::string>& headers,
                        const std::vector<std::string>& media_options,
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
                                    std::string* error) {
    std::vector<uint8_t> data = core_->TakeSnapshot(width, height, error);
    SendSnapshot();
    return data;
  }

  FlValue* GetAudioTracks() {
    return TrackDescriptions(core_->GetAudioTracks());
  }

  std::string SetAudioTrack(int id) { return core_->SetAudioTrack(id); }

  FlValue* GetSubtitleTracks() {
    return TrackDescriptions(core_->GetSubtitleTracks());
  }

  std::string SetSubtitleTrack(int id) { return core_->SetSubtitleTrack(id); }
  std::string DisableSubtitle() { return core_->DisableSubtitle(); }
  std::string AddSubtitle(const std::string& uri) {
    return core_->AddSubtitle(uri);
  }
  FlValue* GetMediaInfo() { return MediaInfo(core_->GetMediaInfo()); }
  FlValue* GetMediaStats() { return MediaStats(core_->GetMediaStats()); }

  bool CopyPixels(const uint8_t** out_buffer,
                  uint32_t* width,
                  uint32_t* height) {
    return core_ != nullptr && core_->CopyPixels(out_buffer, width, height);
  }

  void Dispose() {
    if (disposed_.exchange(true)) {
      return;
    }
    polling_ = false;
    if (polling_thread_.joinable()) {
      polling_thread_.join();
    }
    if (event_channel_ != nullptr) {
      fl_event_channel_set_stream_handlers(event_channel_, nullptr, nullptr,
                                           nullptr, nullptr);
      g_clear_object(&event_channel_);
    }
    if (core_ != nullptr) {
      core_->Dispose();
      core_.reset();
    }
    if (texture_ != nullptr) {
      fl_texture_registrar_unregister_texture(texture_registrar_,
                                              FL_TEXTURE(texture_));
      g_clear_object(&texture_);
      texture_id_ = -1;
    }
  }

 private:
  struct EventPayload {
    FlEventChannel* channel;
    FlValue* event;
  };

  template <typename Operation>
  std::string RunAndSendSnapshot(Operation operation) {
    const std::string error = operation();
    SendSnapshot();
    return error;
  }

  static gboolean SendEventOnMain(gpointer data) {
    auto* payload = static_cast<EventPayload*>(data);
    fl_event_channel_send(payload->channel, payload->event, nullptr, nullptr);
    fl_value_unref(payload->event);
    g_object_unref(payload->channel);
    delete payload;
    return G_SOURCE_REMOVE;
  }

  static FlMethodErrorResponse* Listen(FlEventChannel* channel,
                                       FlValue* args,
                                       gpointer user_data) {
    auto* player = static_cast<LinuxVlcPlayer*>(user_data);
    player->listening_ = true;
    player->SendSnapshot(true);
    return nullptr;
  }

  static FlMethodErrorResponse* Cancel(FlEventChannel* channel,
                                       FlValue* args,
                                       gpointer user_data) {
    static_cast<LinuxVlcPlayer*>(user_data)->listening_ = false;
    return nullptr;
  }

  void SendSnapshot(bool force = false) {
    if (disposed_.load() || core_ == nullptr || !listening_.load()) {
      return;
    }

    const vlc_player::VlcSnapshot snapshot = core_->Snapshot();
    {
      std::lock_guard<std::mutex> lock(snapshot_mutex_);
      if (!force && has_last_sent_snapshot_ &&
          snapshot == last_sent_snapshot_) {
        return;
      }
      last_sent_snapshot_ = snapshot;
      has_last_sent_snapshot_ = true;
    }

    FlValue* event = fl_value_new_map();
    fl_value_set_string_take(event, "state",
                             fl_value_new_string(snapshot.state.c_str()));
    fl_value_set_string_take(event, "position",
                             fl_value_new_int(snapshot.position));
    fl_value_set_string_take(event, "duration",
                             fl_value_new_int(snapshot.duration));
    fl_value_set_string_take(event, "volume", fl_value_new_int(snapshot.volume));
    fl_value_set_string_take(event, "playbackSpeed",
                             fl_value_new_float(snapshot.playback_speed));
    fl_value_set_string_take(event, "audioDelay",
                             fl_value_new_int(snapshot.audio_delay));
    fl_value_set_string_take(event, "subtitleDelay",
                             fl_value_new_int(snapshot.subtitle_delay));
    fl_value_set_string_take(event, "isReady",
                             fl_value_new_bool(snapshot.is_ready));
    fl_value_set_string_take(event, "isSeekable",
                             fl_value_new_bool(snapshot.is_seekable));
    fl_value_set_string_take(event, "isLive",
                             fl_value_new_bool(snapshot.is_live));
    if (snapshot.video_width > 0 && snapshot.video_height > 0) {
      FlValue* video_size = fl_value_new_map();
      fl_value_set_string_take(video_size, "width",
                               fl_value_new_int(snapshot.video_width));
      fl_value_set_string_take(video_size, "height",
                               fl_value_new_int(snapshot.video_height));
      fl_value_set_string_take(event, "videoSize", video_size);
    }
    if (snapshot.buffering_progress >= 0.0) {
      fl_value_set_string_take(event, "bufferingProgress",
                               fl_value_new_float(snapshot.buffering_progress));
    }
    if (!snapshot.error_description.empty()) {
      const std::string error_code =
          snapshot.error_code.empty() ? "playback_error" : snapshot.error_code;
      fl_value_set_string_take(event, "errorCode",
                               fl_value_new_string(error_code.c_str()));
      fl_value_set_string_take(event, "errorDescription",
                               fl_value_new_string(snapshot.error_description.c_str()));
    }
    auto* payload = new EventPayload{
        FL_EVENT_CHANNEL(g_object_ref(event_channel_)),
        event,
    };
    g_main_context_invoke(nullptr, SendEventOnMain, payload);
  }

  FlTextureRegistrar* texture_registrar_;
  FlEventChannel* event_channel_ = nullptr;
  VlcPixelBufferTexture* texture_ = nullptr;
  std::unique_ptr<vlc_player::VlcPlayerCore> core_;
  std::string init_error_;
  std::atomic<bool> disposed_ = false;
  std::atomic<bool> polling_ = false;
  std::atomic<bool> listening_ = false;
  std::mutex snapshot_mutex_;
  bool has_last_sent_snapshot_ = false;
  vlc_player::VlcSnapshot last_sent_snapshot_;
  std::thread polling_thread_;
  int64_t texture_id_ = -1;
};

gboolean vlc_pixel_buffer_texture_copy_pixels(FlPixelBufferTexture* texture,
                                              const uint8_t** buffer,
                                              uint32_t* width,
                                              uint32_t* height,
                                              GError** error) {
  auto* self = reinterpret_cast<VlcPixelBufferTexture*>(texture);
  return self->player != nullptr &&
         self->player->CopyPixels(buffer, width, height);
}

void vlc_pixel_buffer_texture_class_init(VlcPixelBufferTextureClass* klass) {
  FL_PIXEL_BUFFER_TEXTURE_CLASS(klass)->copy_pixels =
      vlc_pixel_buffer_texture_copy_pixels;
}

void vlc_pixel_buffer_texture_init(VlcPixelBufferTexture* self) {
  self->player = nullptr;
}

}  // namespace

struct _VlcPlayerPlugin {
  GObject parent_instance;
  FlBinaryMessenger* messenger;
  FlTextureRegistrar* texture_registrar;
  FlMethodChannel* channel;
  std::map<int64_t, std::unique_ptr<LinuxVlcPlayer>>* players;
  int64_t next_view_id;
};

G_DEFINE_TYPE(VlcPlayerPlugin, vlc_player_plugin, g_object_get_type())

FlMethodResponse* get_platform_version() {
  struct utsname uname_data = {};
  uname(&uname_data);
  g_autofree gchar* version = g_strdup_printf("Linux %s", uname_data.version);
  g_autoptr(FlValue) result = fl_value_new_string(version);
  return FL_METHOD_RESPONSE(fl_method_success_response_new(result));
}

static FlMethodResponse* success_null() {
  return FL_METHOD_RESPONSE(fl_method_success_response_new(nullptr));
}

static FlMethodResponse* error_response(const gchar* code,
                                        const std::string& message) {
  return FL_METHOD_RESPONSE(
      fl_method_error_response_new(code, message.c_str(), nullptr));
}

static LinuxVlcPlayer* find_player(VlcPlayerPlugin* self,
                                   FlValue* arguments,
                                   FlMethodResponse** response) {
  int64_t view_id = 0;
  if (!ReadInt(arguments, "viewId", &view_id)) {
    *response = error_response("invalid_args", "A valid viewId is required.");
    return nullptr;
  }
  auto it = self->players->find(view_id);
  if (it == self->players->end()) {
    *response = error_response(
        "player_not_found",
        "No vlc_player player exists for viewId " + std::to_string(view_id) +
            ".");
    return nullptr;
  }
  return it->second.get();
}

static FlMethodResponse* handle_method(VlcPlayerPlugin* self,
                                       const gchar* method,
                                       FlValue* arguments) {
  if (strcmp(method, "getPlatformVersion") == 0) {
    return get_platform_version();
  }

  if (strcmp(method, "create") == 0) {
    const int64_t view_id = self->next_view_id++;
    auto player = std::make_unique<LinuxVlcPlayer>(
        view_id, self->messenger, self->texture_registrar,
        ReadStringList(arguments, "options"));
    if (!player->is_valid()) {
      return error_response("create_failed", player->error());
    }

    const int64_t texture_id = player->texture_id();
    (*self->players)[view_id] = std::move(player);
    g_autoptr(FlValue) result = fl_value_new_map();
    fl_value_set_string_take(result, "viewId", fl_value_new_int(view_id));
    fl_value_set_string_take(result, "textureId", fl_value_new_int(texture_id));
    return FL_METHOD_RESPONSE(fl_method_success_response_new(result));
  }

  if (arguments == nullptr || fl_value_get_type(arguments) != FL_VALUE_TYPE_MAP) {
    return error_response("invalid_args", "A valid argument map is required.");
  }

  int64_t view_id = 0;
  if (!ReadInt(arguments, "viewId", &view_id)) {
    return error_response("invalid_args", "A valid viewId is required.");
  }

  if (strcmp(method, "dispose") == 0) {
    self->players->erase(view_id);
    return success_null();
  }

  FlMethodResponse* lookup_response = nullptr;
  LinuxVlcPlayer* player = find_player(self, arguments, &lookup_response);
  if (player == nullptr) {
    return lookup_response;
  }

  std::string error;
  if (strcmp(method, "setSource") == 0) {
    int64_t start_position = 0;
    if (ReadInt(arguments, "startPosition", &start_position) &&
        start_position < 0) {
      return error_response("invalid_args",
                            "A non-negative startPosition is required.");
    }
    error = player->SetSource(ReadString(arguments, "uri"),
                              ReadHeaders(arguments),
                              ReadStringList(arguments, "mediaOptions"),
                              start_position,
                              ReadBool(arguments, "autoPlay"));
    if (error == "A non-empty uri is required.") {
      return error_response("invalid_args", error);
    }
  } else if (strcmp(method, "play") == 0) {
    error = player->Play();
  } else if (strcmp(method, "pause") == 0) {
    error = player->Pause();
  } else if (strcmp(method, "stop") == 0) {
    error = player->Stop();
  } else if (strcmp(method, "seekTo") == 0) {
    int64_t position = 0;
    if (!ReadInt(arguments, "position", &position) || position < 0) {
      return error_response("invalid_args",
                            "A non-negative position is required.");
    }
    error = player->SeekTo(position);
  } else if (strcmp(method, "setVolume") == 0) {
    int64_t volume = 0;
    if (!ReadInt(arguments, "volume", &volume)) {
      return error_response("invalid_args", "A volume value is required.");
    }
    error = player->SetVolume(static_cast<int>(volume));
  } else if (strcmp(method, "setPlaybackSpeed") == 0) {
    double speed = 0;
    if (!ReadDouble(arguments, "speed", &speed) || !std::isfinite(speed) ||
        speed <= 0) {
      return error_response("invalid_args",
                            "A finite positive playback speed is required.");
    }
    error = player->SetPlaybackSpeed(speed);
  } else if (strcmp(method, "setAudioDelay") == 0) {
    int64_t delay = 0;
    if (!ReadInt(arguments, "delay", &delay)) {
      return error_response("invalid_args",
                            "An audio delay value is required.");
    }
    error = player->SetAudioDelay(delay);
  } else if (strcmp(method, "setSubtitleDelay") == 0) {
    int64_t delay = 0;
    if (!ReadInt(arguments, "delay", &delay)) {
      return error_response("invalid_args",
                            "A subtitle delay value is required.");
    }
    error = player->SetSubtitleDelay(delay);
  } else if (strcmp(method, "takeSnapshot") == 0) {
    int64_t width = 0;
    int64_t height = 0;
    if (ReadInt(arguments, "width", &width) && width <= 0) {
      return error_response("invalid_args",
                            "Snapshot dimensions must be positive.");
    }
    if (ReadInt(arguments, "height", &height) && height <= 0) {
      return error_response("invalid_args",
                            "Snapshot dimensions must be positive.");
    }
    std::string snapshot_error;
    const std::vector<uint8_t> data = player->TakeSnapshot(
        static_cast<uint32_t>(width), static_cast<uint32_t>(height),
        &snapshot_error);
    if (!snapshot_error.empty()) {
      return error_response("snapshot_failed", snapshot_error);
    }
    g_autoptr(FlValue) result =
        fl_value_new_uint8_list(data.data(), data.size());
    return FL_METHOD_RESPONSE(fl_method_success_response_new(result));
  } else if (strcmp(method, "getAudioTracks") == 0) {
    g_autoptr(FlValue) result = player->GetAudioTracks();
    return FL_METHOD_RESPONSE(fl_method_success_response_new(result));
  } else if (strcmp(method, "setAudioTrack") == 0) {
    int64_t id = 0;
    if (!ReadInt(arguments, "id", &id) || id < 0) {
      return error_response("invalid_args",
                            "A non-negative audio track id is required.");
    }
    error = player->SetAudioTrack(static_cast<int>(id));
  } else if (strcmp(method, "getSubtitleTracks") == 0) {
    g_autoptr(FlValue) result = player->GetSubtitleTracks();
    return FL_METHOD_RESPONSE(fl_method_success_response_new(result));
  } else if (strcmp(method, "setSubtitleTrack") == 0) {
    int64_t id = 0;
    if (!ReadInt(arguments, "id", &id) || id < 0) {
      return error_response("invalid_args",
                            "A non-negative subtitle track id is required.");
    }
    error = player->SetSubtitleTrack(static_cast<int>(id));
  } else if (strcmp(method, "disableSubtitle") == 0) {
    error = player->DisableSubtitle();
  } else if (strcmp(method, "addSubtitle") == 0) {
    error = player->AddSubtitle(ReadString(arguments, "uri"));
    if (error == "A non-empty subtitle uri is required.") {
      return error_response("invalid_args", error);
    }
  } else if (strcmp(method, "getMediaInfo") == 0) {
    g_autoptr(FlValue) result = player->GetMediaInfo();
    return FL_METHOD_RESPONSE(fl_method_success_response_new(result));
  } else if (strcmp(method, "getMediaStats") == 0) {
    g_autoptr(FlValue) result = player->GetMediaStats();
    return FL_METHOD_RESPONSE(fl_method_success_response_new(result));
  } else {
    return FL_METHOD_RESPONSE(fl_method_not_implemented_response_new());
  }

  if (!error.empty()) {
    return error_response("vlc_error", error);
  }
  return success_null();
}

static void vlc_player_plugin_handle_method_call(VlcPlayerPlugin* self,
                                                 FlMethodCall* method_call) {
  FlValue* arguments = fl_method_call_get_args(method_call);
  const gchar* method = fl_method_call_get_name(method_call);
  g_autoptr(FlMethodResponse) response =
      handle_method(self, method, arguments);
  fl_method_call_respond(method_call, response, nullptr);
}

static void vlc_player_plugin_dispose(GObject* object) {
  VlcPlayerPlugin* self = VLC_PLAYER_PLUGIN(object);
  if (self->players != nullptr) {
    self->players->clear();
    delete self->players;
    self->players = nullptr;
  }
  g_clear_object(&self->channel);
  G_OBJECT_CLASS(vlc_player_plugin_parent_class)->dispose(object);
}

static void vlc_player_plugin_class_init(VlcPlayerPluginClass* klass) {
  G_OBJECT_CLASS(klass)->dispose = vlc_player_plugin_dispose;
}

static void vlc_player_plugin_init(VlcPlayerPlugin* self) {
  self->players =
      new std::map<int64_t, std::unique_ptr<LinuxVlcPlayer>>();
  self->next_view_id = 1;
}

static void method_call_cb(FlMethodChannel* channel,
                           FlMethodCall* method_call,
                           gpointer user_data) {
  VlcPlayerPlugin* plugin = VLC_PLAYER_PLUGIN(user_data);
  vlc_player_plugin_handle_method_call(plugin, method_call);
}

void vlc_player_plugin_register_with_registrar(FlPluginRegistrar* registrar) {
  VlcPlayerPlugin* plugin =
      VLC_PLAYER_PLUGIN(g_object_new(vlc_player_plugin_get_type(), nullptr));
  plugin->messenger = fl_plugin_registrar_get_messenger(registrar);
  plugin->texture_registrar =
      fl_plugin_registrar_get_texture_registrar(registrar);

  g_autoptr(FlStandardMethodCodec) codec = fl_standard_method_codec_new();
  plugin->channel =
      fl_method_channel_new(plugin->messenger, "vlc_player",
                            FL_METHOD_CODEC(codec));
  fl_method_channel_set_method_call_handler(
      plugin->channel, method_call_cb, g_object_ref(plugin), g_object_unref);

  g_object_unref(plugin);
}
