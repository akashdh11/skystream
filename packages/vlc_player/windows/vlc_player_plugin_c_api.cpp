#include "include/vlc_player/vlc_player_plugin_c_api.h"

#include <flutter/plugin_registrar_windows.h>

#include "vlc_player_plugin.h"

void VlcPlayerPluginCApiRegisterWithRegistrar(
    FlutterDesktopPluginRegistrarRef registrar) {
  vlc_player::VlcPlayerPlugin::RegisterWithRegistrar(
      flutter::PluginRegistrarManager::GetInstance()
          ->GetRegistrar<flutter::PluginRegistrarWindows>(registrar),
      registrar);
}
