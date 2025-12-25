#include "include/volumedeck_mixer/volumedeck_mixer_plugin_c_api.h"

#include <flutter/plugin_registrar_windows.h>

#include "volumedeck_mixer_plugin.h"

void VolumedeckMixerPluginCApiRegisterWithRegistrar(
    FlutterDesktopPluginRegistrarRef registrar) {
  volumedeck_mixer::VolumedeckMixerPlugin::RegisterWithRegistrar(
      flutter::PluginRegistrarManager::GetInstance()
          ->GetRegistrar<flutter::PluginRegistrarWindows>(registrar));
}
