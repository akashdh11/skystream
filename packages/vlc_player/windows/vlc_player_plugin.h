#ifndef FLUTTER_PLUGIN_VLC_PLAYER_PLUGIN_H_
#define FLUTTER_PLUGIN_VLC_PLAYER_PLUGIN_H_

#ifndef NOMINMAX
#define NOMINMAX
#endif

#include <flutter/binary_messenger.h>
#include <flutter/method_channel.h>
#include <flutter/plugin_registrar_windows.h>
#include <flutter/standard_method_codec.h>
#include <flutter/texture_registrar.h>

#include <cstdint>
#include <mutex>
#include <memory>
#include <thread>
#include <unordered_map>
#include <vector>

namespace vlc_player {

class WindowsVlcPlayer;

class VlcPlayerPlugin : public flutter::Plugin {
 public:
  static void RegisterWithRegistrar(flutter::PluginRegistrarWindows *registrar);
  static void RegisterWithRegistrar(
      flutter::PluginRegistrarWindows *registrar,
      FlutterDesktopPluginRegistrarRef core_registrar);

  VlcPlayerPlugin(flutter::BinaryMessenger *messenger,
                  flutter::TextureRegistrar *texture_registrar,
                  FlutterDesktopMessengerRef messenger_ref = nullptr);

  virtual ~VlcPlayerPlugin();

  VlcPlayerPlugin(const VlcPlayerPlugin &) = delete;
  VlcPlayerPlugin &operator=(const VlcPlayerPlugin &) = delete;

  void HandleMethodCall(
      const flutter::MethodCall<flutter::EncodableValue> &method_call,
      std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result);

 private:
  std::shared_ptr<WindowsVlcPlayer> FindPlayer(
      const flutter::EncodableMap &arguments,
      flutter::MethodResult<flutter::EncodableValue> *result);

  void DisposePlayer(int64_t view_id);

  flutter::BinaryMessenger *messenger_;
  flutter::TextureRegistrar *texture_registrar_;
  FlutterDesktopMessengerRef messenger_ref_;
  int64_t next_view_id_ = 1;
  std::mutex players_mutex_;
  std::unordered_map<int64_t, std::shared_ptr<WindowsVlcPlayer>> players_;
  std::vector<std::thread> create_threads_;
  std::vector<std::thread> dispose_threads_;
};

}  // namespace vlc_player

#endif  // FLUTTER_PLUGIN_VLC_PLAYER_PLUGIN_H_
