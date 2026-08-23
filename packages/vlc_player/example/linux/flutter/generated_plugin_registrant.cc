//
//  Generated file. Do not edit.
//

// clang-format off

#include "generated_plugin_registrant.h"

#include <vlc_player/vlc_player_plugin.h>

void fl_register_plugins(FlPluginRegistry* registry) {
  g_autoptr(FlPluginRegistrar) vlc_player_registrar =
      fl_plugin_registry_get_registrar_for_plugin(registry, "VlcPlayerPlugin");
  vlc_player_plugin_register_with_registrar(vlc_player_registrar);
}
