#include "include/volumedeck_mixer/volumedeck_mixer_plugin.h"

#include <flutter/method_channel.h>
#include <flutter/plugin_registrar_windows.h>
#include <flutter/standard_method_codec.h>

#include <windows.h>
#include <mmdeviceapi.h>
#include <endpointvolume.h>
#include <audiopolicy.h>
#include <psapi.h>
#include <wrl/client.h>

#include <memory>
#include <string>
#include <vector>
#include <optional>

namespace volumedeck_mixer {

// ---------- helpers ----------
    static std::string WideToUtf8(const std::wstring& w) {
        if (w.empty()) return {};
        int len = WideCharToMultiByte(CP_UTF8, 0, w.c_str(), (int)w.size(), nullptr, 0, nullptr, nullptr);
        std::string out(len, '\0');
        WideCharToMultiByte(CP_UTF8, 0, w.c_str(), (int)w.size(), out.data(), len, nullptr, nullptr);
        return out;
    }

    static std::string BasenameLower(const std::string& pathOrName) {
        std::string s = pathOrName;
        for (auto& c : s) if (c == '\\') c = '/';
        auto pos = s.find_last_of('/');
        std::string base = (pos == std::string::npos) ? s : s.substr(pos + 1);
        for (auto& c : base) c = (char)tolower((unsigned char)c);
        return base;
    }

    static std::string GetExePathByPid(DWORD pid) {
        std::string path;
        HANDLE h = OpenProcess(PROCESS_QUERY_LIMITED_INFORMATION | PROCESS_VM_READ, FALSE, pid);
        if (!h) return path;

        wchar_t buf[MAX_PATH];
        DWORD size = MAX_PATH;

        if (QueryFullProcessImageNameW(h, 0, buf, &size)) {
            CloseHandle(h);
            return WideToUtf8(std::wstring(buf, size));
        }

        HMODULE mod;
        DWORD needed = 0;
        if (EnumProcessModules(h, &mod, sizeof(mod), &needed)) {
            if (GetModuleFileNameExW(h, mod, buf, MAX_PATH)) {
                path = WideToUtf8(buf);
            }
        }

        CloseHandle(h);
        return path;
    }

    static double Clamp01(double x) {
        if (x < 0.0) return 0.0;
        if (x > 1.0) return 1.0;
        return x;
    }

    struct SessionInfo {
        std::string sessionId;
        DWORD pid = 0;
        std::string exeName;      // chrome.exe
        std::string exePath;      // full path
        std::string displayName;
        float volume = 1.0f;      // 0..1
        bool mute = false;
        float peak = 0.0f;        // 0..1
    };

    class CoreAudio {
    public:
        CoreAudio() { CoInitializeEx(nullptr, COINIT_APARTMENTTHREADED); }
        ~CoreAudio() { CoUninitialize(); }

        flutter::EncodableMap GetSnapshot(bool include_sessions) {
            flutter::EncodableMap out;

            out[flutter::EncodableValue("master")] = GetMaster();

            if (include_sessions) {
                flutter::EncodableList sessions;
                auto vec = ListSessions();
                for (auto& s : vec) {
                    flutter::EncodableMap m;
                    m[flutter::EncodableValue("sessionId")] = flutter::EncodableValue(s.sessionId);
                    m[flutter::EncodableValue("pid")] = flutter::EncodableValue((int)s.pid);
                    m[flutter::EncodableValue("exeName")] = flutter::EncodableValue(s.exeName);
                    m[flutter::EncodableValue("exePath")] = flutter::EncodableValue(s.exePath);
                    m[flutter::EncodableValue("displayName")] = flutter::EncodableValue(s.displayName);
                    m[flutter::EncodableValue("volume")] = flutter::EncodableValue((double)s.volume);
                    m[flutter::EncodableValue("mute")] = flutter::EncodableValue(s.mute);
                    m[flutter::EncodableValue("peak")] = flutter::EncodableValue((double)s.peak);
                    sessions.push_back(flutter::EncodableValue(m));
                }
                out[flutter::EncodableValue("sessions")] = flutter::EncodableValue(sessions);
            }

            return out;
        }

        std::optional<std::string> FindSessionIdByExeName(const std::string& exeName) {
            auto want = BasenameLower(exeName);
            auto vec = ListSessions();
            for (auto& s : vec) {
                if (BasenameLower(s.exeName) == want) return s.sessionId;
            }
            return std::nullopt;
        }

        bool SetMasterVolume(double v01) {
            Microsoft::WRL::ComPtr<IAudioEndpointVolume> ep;
            if (!GetEndpointVolume(ep)) return false;
            float v = (float)Clamp01(v01);
            return SUCCEEDED(ep->SetMasterVolumeLevelScalar(v, nullptr));
        }

        bool SetMasterMute(bool mute) {
            Microsoft::WRL::ComPtr<IAudioEndpointVolume> ep;
            if (!GetEndpointVolume(ep)) return false;
            return SUCCEEDED(ep->SetMute(mute ? TRUE : FALSE, nullptr));
        }

        bool SetSessionVolume(const std::string& sessionId, double v01) {
            auto s = FindSessionById(sessionId);
            if (!s) return false;
            return SetSimpleVolume(*s, (float)Clamp01(v01));
        }

        bool SetSessionMute(const std::string& sessionId, bool mute) {
            auto s = FindSessionById(sessionId);
            if (!s) return false;
            return SetSimpleMute(*s, mute);
        }

    private:
        bool GetDefaultRenderDevice(Microsoft::WRL::ComPtr<IMMDevice>& dev) {
            Microsoft::WRL::ComPtr<IMMDeviceEnumerator> en;
            if (FAILED(CoCreateInstance(__uuidof(MMDeviceEnumerator), nullptr, CLSCTX_ALL,
                                        __uuidof(IMMDeviceEnumerator), (void**)en.GetAddressOf())))
                return false;

            return SUCCEEDED(en->GetDefaultAudioEndpoint(eRender, eMultimedia, dev.GetAddressOf()));
        }

        bool GetEndpointVolume(Microsoft::WRL::ComPtr<IAudioEndpointVolume>& ep) {
            Microsoft::WRL::ComPtr<IMMDevice> dev;
            if (!GetDefaultRenderDevice(dev)) return false;

            Microsoft::WRL::ComPtr<IAudioEndpointVolume> v;
            if (FAILED(dev->Activate(__uuidof(IAudioEndpointVolume), CLSCTX_ALL, nullptr,
                                     (void**)v.GetAddressOf())))
                return false;

            ep = v;
            return true;
        }

        bool GetEndpointMeter(Microsoft::WRL::ComPtr<IAudioMeterInformation>& mi) {
            Microsoft::WRL::ComPtr<IMMDevice> dev;
            if (!GetDefaultRenderDevice(dev)) return false;

            Microsoft::WRL::ComPtr<IAudioMeterInformation> m;
            if (FAILED(dev->Activate(__uuidof(IAudioMeterInformation), CLSCTX_ALL, nullptr,
                                     (void**)m.GetAddressOf())))
                return false;

            mi = m;
            return true;
        }

        flutter::EncodableMap GetMaster() {
            flutter::EncodableMap m;
            double vol = 1.0;
            bool mute = false;
            double peak = 0.0;

            {
                Microsoft::WRL::ComPtr<IAudioEndpointVolume> ep;
                if (GetEndpointVolume(ep)) {
                    float v = 1.f;
                    BOOL mu = FALSE;
                    ep->GetMasterVolumeLevelScalar(&v);
                    ep->GetMute(&mu);
                    vol = v;
                    mute = (mu == TRUE);
                }
            }

            {
                Microsoft::WRL::ComPtr<IAudioMeterInformation> mi;
                if (GetEndpointMeter(mi)) {
                    float p = 0.f;
                    if (SUCCEEDED(mi->GetPeakValue(&p))) peak = p;
                }
            }

            m[flutter::EncodableValue("volume")] = flutter::EncodableValue(vol);
            m[flutter::EncodableValue("mute")] = flutter::EncodableValue(mute);
            m[flutter::EncodableValue("peak")] = flutter::EncodableValue(peak);
            return m;
        }

        std::vector<SessionInfo> ListSessions() {
            std::vector<SessionInfo> out;

            Microsoft::WRL::ComPtr<IMMDevice> dev;
            if (!GetDefaultRenderDevice(dev)) return out;

            Microsoft::WRL::ComPtr<IAudioSessionManager2> mgr;
            if (FAILED(dev->Activate(__uuidof(IAudioSessionManager2), CLSCTX_ALL, nullptr,
                                     (void**)mgr.GetAddressOf())))
                return out;

            Microsoft::WRL::ComPtr<IAudioSessionEnumerator> en;
            if (FAILED(mgr->GetSessionEnumerator(en.GetAddressOf())))
                return out;

            int count = 0;
            en->GetCount(&count);

            for (int i = 0; i < count; i++) {
                Microsoft::WRL::ComPtr<IAudioSessionControl> ctl;
                if (FAILED(en->GetSession(i, ctl.GetAddressOf()))) continue;

                Microsoft::WRL::ComPtr<IAudioSessionControl2> ctl2;
                if (FAILED(ctl.As(&ctl2))) continue;

                DWORD pid = 0;
                ctl2->GetProcessId(&pid);

                // sessionId
                LPWSTR sid = nullptr;
                std::string sessionId;
                if (SUCCEEDED(ctl2->GetSessionIdentifier(&sid)) && sid) {
                    sessionId = WideToUtf8(sid);
                    CoTaskMemFree(sid);
                }

                // display name
                LPWSTR dn = nullptr;
                std::string displayName;
                if (SUCCEEDED(ctl->GetDisplayName(&dn)) && dn) {
                    displayName = WideToUtf8(dn);
                    CoTaskMemFree(dn);
                }

                std::string exePath = (pid != 0) ? GetExePathByPid(pid) : "";
                std::string exeName = exePath.empty() ? "" : BasenameLower(exePath);
                if (exeName.empty()) exeName = (pid == 0) ? "system" : ("pid_" + std::to_string(pid));

                // volume + mute
                float volume = 1.0f;
                bool mute = false;
                {
                    Microsoft::WRL::ComPtr<ISimpleAudioVolume> sav;
                    if (SUCCEEDED(ctl2->QueryInterface(__uuidof(ISimpleAudioVolume), (void**)sav.GetAddressOf()))) {
                        float v = 1.0f;
                        BOOL mu = FALSE;
                        sav->GetMasterVolume(&v);
                        sav->GetMute(&mu);
                        volume = v;
                        mute = (mu == TRUE);
                    }
                }

                // peak
                float peak = 0.0f;
                {
                    Microsoft::WRL::ComPtr<IAudioMeterInformation> mi;
                    if (SUCCEEDED(ctl2->QueryInterface(__uuidof(IAudioMeterInformation), (void**)mi.GetAddressOf()))) {
                        float p = 0.f;
                        if (SUCCEEDED(mi->GetPeakValue(&p))) peak = p;
                    }
                }

                SessionInfo s;
                s.sessionId = sessionId;
                s.pid = pid;
                s.exeName = exeName;
                s.exePath = exePath;
                s.displayName = displayName;
                s.volume = volume;
                s.mute = mute;
                s.peak = peak;

                out.push_back(std::move(s));
            }

            return out;
        }

        std::optional<SessionInfo> FindSessionById(const std::string& sessionId) {
            auto vec = ListSessions();
            for (auto& s : vec) if (s.sessionId == sessionId) return s;
            return std::nullopt;
        }

        bool SetSimpleVolume(const SessionInfo& si, float vol) {
            Microsoft::WRL::ComPtr<IMMDevice> dev;
            if (!GetDefaultRenderDevice(dev)) return false;

            Microsoft::WRL::ComPtr<IAudioSessionManager2> mgr;
            if (FAILED(dev->Activate(__uuidof(IAudioSessionManager2), CLSCTX_ALL, nullptr,
                                     (void**)mgr.GetAddressOf())))
                return false;

            Microsoft::WRL::ComPtr<IAudioSessionEnumerator> en;
            if (FAILED(mgr->GetSessionEnumerator(en.GetAddressOf())))
                return false;

            int count = 0;
            en->GetCount(&count);

            for (int i = 0; i < count; i++) {
                Microsoft::WRL::ComPtr<IAudioSessionControl> ctl;
                if (FAILED(en->GetSession(i, ctl.GetAddressOf()))) continue;

                Microsoft::WRL::ComPtr<IAudioSessionControl2> ctl2;
                if (FAILED(ctl.As(&ctl2))) continue;

                LPWSTR sid = nullptr;
                std::string id;
                if (SUCCEEDED(ctl2->GetSessionIdentifier(&sid)) && sid) {
                    id = WideToUtf8(sid);
                    CoTaskMemFree(sid);
                }
                if (id != si.sessionId) continue;

                Microsoft::WRL::ComPtr<ISimpleAudioVolume> sav;
                if (FAILED(ctl2->QueryInterface(__uuidof(ISimpleAudioVolume), (void**)sav.GetAddressOf()))) return false;
                return SUCCEEDED(sav->SetMasterVolume(vol, nullptr));
            }
            return false;
        }

        bool SetSimpleMute(const SessionInfo& si, bool mute) {
            Microsoft::WRL::ComPtr<IMMDevice> dev;
            if (!GetDefaultRenderDevice(dev)) return false;

            Microsoft::WRL::ComPtr<IAudioSessionManager2> mgr;
            if (FAILED(dev->Activate(__uuidof(IAudioSessionManager2), CLSCTX_ALL, nullptr,
                                     (void**)mgr.GetAddressOf())))
                return false;

            Microsoft::WRL::ComPtr<IAudioSessionEnumerator> en;
            if (FAILED(mgr->GetSessionEnumerator(en.GetAddressOf())))
                return false;

            int count = 0;
            en->GetCount(&count);

            for (int i = 0; i < count; i++) {
                Microsoft::WRL::ComPtr<IAudioSessionControl> ctl;
                if (FAILED(en->GetSession(i, ctl.GetAddressOf()))) continue;

                Microsoft::WRL::ComPtr<IAudioSessionControl2> ctl2;
                if (FAILED(ctl.As(&ctl2))) continue;

                LPWSTR sid = nullptr;
                std::string id;
                if (SUCCEEDED(ctl2->GetSessionIdentifier(&sid)) && sid) {
                    id = WideToUtf8(sid);
                    CoTaskMemFree(sid);
                }
                if (id != si.sessionId) continue;

                Microsoft::WRL::ComPtr<ISimpleAudioVolume> sav;
                if (FAILED(ctl2->QueryInterface(__uuidof(ISimpleAudioVolume), (void**)sav.GetAddressOf()))) return false;
                return SUCCEEDED(sav->SetMute(mute ? TRUE : FALSE, nullptr));
            }
            return false;
        }
    };

// ---------- Flutter plugin wrapper ----------
    class VolumedeckMixerPlugin : public flutter::Plugin {
    public:
        static void RegisterWithRegistrar(flutter::PluginRegistrarWindows* registrar) {
            auto channel = std::make_unique<flutter::MethodChannel<flutter::EncodableValue>>(
                    registrar->messenger(), "volumedeck_mixer",
                            &flutter::StandardMethodCodec::GetInstance());

            auto plugin = std::make_unique<VolumedeckMixerPlugin>();

            channel->SetMethodCallHandler(
                    [plugin_ptr = plugin.get()](const auto& call, auto result) {
                        plugin_ptr->HandleMethodCall(call, std::move(result));
                    });

            registrar->AddPlugin(std::move(plugin));
        }

        VolumedeckMixerPlugin() = default;
        ~VolumedeckMixerPlugin() override = default;

    private:
        CoreAudio audio_;

        void HandleMethodCall(
                const flutter::MethodCall<flutter::EncodableValue>& call,
                std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {

            const auto& method = call.method_name();

            if (method == "getSnapshot") {
                bool include = true;
                if (call.arguments() && std::holds_alternative<flutter::EncodableMap>(*call.arguments())) {
                    auto args = std::get<flutter::EncodableMap>(*call.arguments());
                    auto it = args.find(flutter::EncodableValue("includeSessions"));
                    if (it != args.end() && std::holds_alternative<bool>(it->second)) {
                        include = std::get<bool>(it->second);
                    }
                }
                result->Success(flutter::EncodableValue(audio_.GetSnapshot(include)));
                return;
            }

            if (method == "findSessionIdByExe") {
                if (!call.arguments() || !std::holds_alternative<flutter::EncodableMap>(*call.arguments())) {
                    result->Error("bad_args", "args must be map");
                    return;
                }
                auto args = std::get<flutter::EncodableMap>(*call.arguments());
                auto it = args.find(flutter::EncodableValue("exeName"));
                if (it == args.end() || !std::holds_alternative<std::string>(it->second)) {
                    result->Error("bad_args", "exeName required");
                    return;
                }
                auto sid = audio_.FindSessionIdByExeName(std::get<std::string>(it->second));
                if (!sid) result->Success(flutter::EncodableValue()); // null
                else result->Success(flutter::EncodableValue(*sid));
                return;
            }

            if (method == "setMasterVolume") {
                auto args = std::get<flutter::EncodableMap>(*call.arguments());
                double v = 1.0;
                auto it = args.find(flutter::EncodableValue("value"));
                if (it != args.end() && std::holds_alternative<double>(it->second)) v = std::get<double>(it->second);
                result->Success(flutter::EncodableValue(audio_.SetMasterVolume(v)));
                return;
            }

            if (method == "setMasterMute") {
                auto args = std::get<flutter::EncodableMap>(*call.arguments());
                bool m = false;
                auto it = args.find(flutter::EncodableValue("mute"));
                if (it != args.end() && std::holds_alternative<bool>(it->second)) m = std::get<bool>(it->second);
                result->Success(flutter::EncodableValue(audio_.SetMasterMute(m)));
                return;
            }

            if (method == "setSessionVolume") {
                auto args = std::get<flutter::EncodableMap>(*call.arguments());
                auto itId = args.find(flutter::EncodableValue("sessionId"));
                auto itV  = args.find(flutter::EncodableValue("value"));
                if (itId == args.end() || !std::holds_alternative<std::string>(itId->second) ||
                    itV == args.end()  || !std::holds_alternative<double>(itV->second)) {
                    result->Error("bad_args", "sessionId + value required");
                    return;
                }
                result->Success(flutter::EncodableValue(
                        audio_.SetSessionVolume(std::get<std::string>(itId->second), std::get<double>(itV->second))
                ));
                return;
            }

            if (method == "setSessionMute") {
                auto args = std::get<flutter::EncodableMap>(*call.arguments());
                auto itId = args.find(flutter::EncodableValue("sessionId"));
                auto itM  = args.find(flutter::EncodableValue("mute"));
                if (itId == args.end() || !std::holds_alternative<std::string>(itId->second) ||
                    itM == args.end()  || !std::holds_alternative<bool>(itM->second)) {
                    result->Error("bad_args", "sessionId + mute required");
                    return;
                }
                result->Success(flutter::EncodableValue(
                        audio_.SetSessionMute(std::get<std::string>(itId->second), std::get<bool>(itM->second))
                ));
                return;
            }

            result->NotImplemented();
        }
    };

    void VolumedeckMixerPluginRegisterWithRegistrar(
            FlutterDesktopPluginRegistrarRef registrar) {
        VolumedeckMixerPlugin::RegisterWithRegistrar(
                flutter::PluginRegistrarManager::GetInstance()
                        ->GetRegistrar<flutter::PluginRegistrarWindows>(registrar));
    }

}  // namespace volumedeck_mixer
