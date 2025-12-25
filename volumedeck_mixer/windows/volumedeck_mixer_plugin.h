#ifndef FLUTTER_PLUGIN_VOLUMEDECK_MIXER_PLUGIN_H_
#define FLUTTER_PLUGIN_VOLUMEDECK_MIXER_PLUGIN_H_

#include <flutter/method_channel.h>
#include <flutter/plugin_registrar_windows.h>

#include <memory>

namespace volumedeck_mixer {

class VolumedeckMixerPlugin : public flutter::Plugin {
 public:
  static void RegisterWithRegistrar(flutter::PluginRegistrarWindows *registrar);

  VolumedeckMixerPlugin();

  virtual ~VolumedeckMixerPlugin();

  // Disallow copy and assign.
  VolumedeckMixerPlugin(const VolumedeckMixerPlugin&) = delete;
  VolumedeckMixerPlugin& operator=(const VolumedeckMixerPlugin&) = delete;

  // Called when a method is called on this plugin's channel from Dart.
  void HandleMethodCall(
      const flutter::MethodCall<flutter::EncodableValue> &method_call,
      std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result);
};

}  // namespace volumedeck_mixer

#endif  // FLUTTER_PLUGIN_VOLUMEDECK_MIXER_PLUGIN_H_
