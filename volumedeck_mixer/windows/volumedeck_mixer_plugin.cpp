#include <flutter/method_channel.h>
#include <flutter/plugin_registrar_windows.h>
#include <flutter/standard_method_codec.h>

#include <memory>
#include <string>

namespace volumedeck_mixer {

    class VolumedeckMixerPlugin : public flutter::Plugin {
    public:
        static void RegisterWithRegistrar(flutter::PluginRegistrarWindows *registrar);

        VolumedeckMixerPlugin() {}
        virtual ~VolumedeckMixerPlugin() {}

    private:
        void HandleMethodCall(
                const flutter::MethodCall<flutter::EncodableValue> &method_call,
                std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result);
    };

    void VolumedeckMixerPlugin::RegisterWithRegistrar(
            flutter::PluginRegistrarWindows *registrar) {
        auto channel =
                std::make_unique<flutter::MethodChannel<flutter::EncodableValue>>(
                        registrar->messenger(), "volumedeck_mixer",
                                &flutter::StandardMethodCodec::GetInstance());

        auto plugin = std::make_unique<VolumedeckMixerPlugin>();

        channel->SetMethodCallHandler(
                [plugin_pointer = plugin.get()](const auto &call, auto result) {
                    plugin_pointer->HandleMethodCall(call, std::move(result));
                });

        registrar->AddPlugin(std::move(plugin));
    }

    void VolumedeckMixerPlugin::HandleMethodCall(
            const flutter::MethodCall<flutter::EncodableValue> &method_call,
            std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {

        const auto &method = method_call.method_name();

        if (method == "getSnapshot") {
            flutter::EncodableMap m;
            m[flutter::EncodableValue("ok")] = flutter::EncodableValue(true);
            m[flutter::EncodableValue("master")] = flutter::EncodableValue(0.75); // örnek
            result->Success(flutter::EncodableValue(m));
            return;
        }

        result->NotImplemented();
    }

}  // namespace volumedeck_mixer

void VolumedeckMixerPluginRegisterWithRegistrar(
        FlutterDesktopPluginRegistrarRef registrar) {
    volumedeck_mixer::VolumedeckMixerPlugin::RegisterWithRegistrar(
            flutter::PluginRegistrarManager::GetInstance()
                    ->GetRegistrar<flutter::PluginRegistrarWindows>(registrar));
}
