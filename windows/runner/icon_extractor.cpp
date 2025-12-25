#include "icon_extractor.h"

#include <windows.h>
#include <shlobj.h>
#include <shellapi.h>
#include <wincodec.h>

#include <memory>
#include <string>
#include <vector>

#pragma comment(lib, "windowscodecs.lib")
#pragma comment(lib, "ole32.lib")
#pragma comment(lib, "shell32.lib")

static std::wstring Utf8ToWide(const std::string& s) {
    if (s.empty()) return L"";
    int len = MultiByteToWideChar(CP_UTF8, 0, s.c_str(), (int)s.size(), nullptr, 0);
    std::wstring out(len, L'\0');
    MultiByteToWideChar(CP_UTF8, 0, s.c_str(), (int)s.size(), &out[0], len);
    return out;
}

// Draw HICON into 32-bit BGRA DIB
static bool IconToBGRA(HICON hIcon, int size, std::vector<uint8_t>& outBGRA) {
    if (!hIcon) return false;

    BITMAPINFO bi{};
    bi.bmiHeader.biSize = sizeof(BITMAPINFOHEADER);
    bi.bmiHeader.biWidth = size;
    bi.bmiHeader.biHeight = -size; // top-down
    bi.bmiHeader.biPlanes = 1;
    bi.bmiHeader.biBitCount = 32;
    bi.bmiHeader.biCompression = BI_RGB;

    void* bits = nullptr;
    HDC hdc = GetDC(nullptr);
    HBITMAP dib = CreateDIBSection(hdc, &bi, DIB_RGB_COLORS, &bits, nullptr, 0);
    if (!dib || !bits) {
        if (dib) DeleteObject(dib);
        ReleaseDC(nullptr, hdc);
        return false;
    }

    HDC memdc = CreateCompatibleDC(hdc);
    HGDIOBJ old = SelectObject(memdc, dib);

    // Clear
    RECT rc{0, 0, size, size};
    HBRUSH brush = CreateSolidBrush(RGB(0, 0, 0));
    FillRect(memdc, &rc, brush);
    DeleteObject(brush);

    DrawIconEx(memdc, 0, 0, hIcon, size, size, 0, nullptr, DI_NORMAL);

    outBGRA.resize(size * size * 4);
    memcpy(outBGRA.data(), bits, outBGRA.size());

    SelectObject(memdc, old);
    DeleteDC(memdc);
    DeleteObject(dib);
    ReleaseDC(nullptr, hdc);
    return true;
}

static bool EncodePngWIC(const std::vector<uint8_t>& bgra, int size, std::vector<uint8_t>& pngOut) {
    HRESULT hr = CoInitializeEx(nullptr, COINIT_APARTMENTTHREADED);
    const bool didInit = SUCCEEDED(hr);

    IWICImagingFactory* factory = nullptr;
    hr = CoCreateInstance(CLSID_WICImagingFactory, nullptr, CLSCTX_INPROC_SERVER, IID_PPV_ARGS(&factory));
    if (FAILED(hr) || !factory) {
        if (didInit) CoUninitialize();
        return false;
    }

    IWICBitmap* bitmap = nullptr;
    hr = factory->CreateBitmapFromMemory(
            size, size,
            GUID_WICPixelFormat32bppBGRA,
            size * 4,
            (UINT)bgra.size(),
            (BYTE*)bgra.data(),
            &bitmap);
    if (FAILED(hr) || !bitmap) {
        factory->Release();
        if (didInit) CoUninitialize();
        return false;
    }

    IWICStream* stream = nullptr;
    hr = factory->CreateStream(&stream);
    if (FAILED(hr) || !stream) {
        bitmap->Release();
        factory->Release();
        if (didInit) CoUninitialize();
        return false;
    }

    hr = stream->InitializeFromMemory(nullptr, 0); // will fail
    // We need an IStream that grows: use CreateStreamOnHGlobal
    IStream* memStream = nullptr;
    hr = CreateStreamOnHGlobal(nullptr, TRUE, &memStream);
    if (FAILED(hr) || !memStream) {
        stream->Release();
        bitmap->Release();
        factory->Release();
        if (didInit) CoUninitialize();
        return false;
    }

    IWICBitmapEncoder* encoder = nullptr;
    hr = factory->CreateEncoder(GUID_ContainerFormatPng, nullptr, &encoder);
    if (FAILED(hr) || !encoder) {
        memStream->Release();
        stream->Release();
        bitmap->Release();
        factory->Release();
        if (didInit) CoUninitialize();
        return false;
    }

    hr = encoder->Initialize(memStream, WICBitmapEncoderNoCache);
    if (FAILED(hr)) {
        encoder->Release();
        memStream->Release();
        stream->Release();
        bitmap->Release();
        factory->Release();
        if (didInit) CoUninitialize();
        return false;
    }

    IWICBitmapFrameEncode* frame = nullptr;
    IPropertyBag2* props = nullptr;
    hr = encoder->CreateNewFrame(&frame, &props);
    if (props) props->Release();
    if (FAILED(hr) || !frame) {
        encoder->Release();
        memStream->Release();
        stream->Release();
        bitmap->Release();
        factory->Release();
        if (didInit) CoUninitialize();
        return false;
    }

    hr = frame->Initialize(nullptr);
    if (FAILED(hr)) {
        frame->Release();
        encoder->Release();
        memStream->Release();
        stream->Release();
        bitmap->Release();
        factory->Release();
        if (didInit) CoUninitialize();
        return false;
    }

    hr = frame->SetSize(size, size);
    if (FAILED(hr)) {
        frame->Release();
        encoder->Release();
        memStream->Release();
        stream->Release();
        bitmap->Release();
        factory->Release();
        if (didInit) CoUninitialize();
        return false;
    }

    WICPixelFormatGUID format = GUID_WICPixelFormat32bppBGRA;
    frame->SetPixelFormat(&format);

    hr = frame->WriteSource(bitmap, nullptr);
    if (FAILED(hr)) {
        frame->Release();
        encoder->Release();
        memStream->Release();
        stream->Release();
        bitmap->Release();
        factory->Release();
        if (didInit) CoUninitialize();
        return false;
    }

    frame->Commit();
    encoder->Commit();

    // Read bytes from memStream
    STATSTG stat{};
    memStream->Stat(&stat, STATFLAG_NONAME);
    ULONG sizeBytes = (ULONG)stat.cbSize.QuadPart;
    pngOut.resize(sizeBytes);

    LARGE_INTEGER zero{};
    memStream->Seek(zero, STREAM_SEEK_SET, nullptr);

    ULONG read = 0;
    memStream->Read(pngOut.data(), sizeBytes, &read);
    pngOut.resize(read);

    frame->Release();
    encoder->Release();
    memStream->Release();
    stream->Release();
    bitmap->Release();
    factory->Release();

    if (didInit) CoUninitialize();
    return true;
}

static bool GetIconForFile(const std::wstring& path, int size, std::vector<uint8_t>& pngOut) {
    SHFILEINFOW sfi{};
    UINT flags = SHGFI_ICON | (size <= 16 ? SHGFI_SMALLICON : SHGFI_LARGEICON);
    if (!SHGetFileInfoW(path.c_str(), 0, &sfi, sizeof(sfi), flags) || !sfi.hIcon) {
        return false;
    }

    std::vector<uint8_t> bgra;
    bool ok = IconToBGRA(sfi.hIcon, (size <= 16 ? 16 : 32), bgra);
    DestroyIcon(sfi.hIcon);
    if (!ok) return false;

    return EncodePngWIC(bgra, (size <= 16 ? 16 : 32), pngOut);
}

void RegisterIconExtractor(flutter::BinaryMessenger* messenger) {
    auto channel = std::make_unique<flutter::MethodChannel<flutter::EncodableValue>>(
            messenger, "volumedeck/icon", &flutter::StandardMethodCodec::GetInstance());

    channel->SetMethodCallHandler(
            [](const flutter::MethodCall<flutter::EncodableValue>& call,
               std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
                if (call.method_name() == "getExeIconPng") {
                    const auto* args = std::get_if<flutter::EncodableMap>(call.arguments());
                    if (!args) {
                        result->Error("bad_args", "Expected map args");
                        return;
                    }

                    std::string pathUtf8;
                    int size = 32;

                    auto itPath = args->find(flutter::EncodableValue("path"));
                    if (itPath != args->end()) {
                        if (auto p = std::get_if<std::string>(&itPath->second)) pathUtf8 = *p;
                    }
                    auto itSize = args->find(flutter::EncodableValue("size"));
                    if (itSize != args->end()) {
                        if (auto p = std::get_if<int>(&itSize->second)) size = *p;
                    }

                    if (pathUtf8.empty()) {
                        result->Success(flutter::EncodableValue(std::vector<uint8_t>{}));
                        return;
                    }

                    const std::wstring path = Utf8ToWide(pathUtf8);

                    std::vector<uint8_t> png;
                    if (!GetIconForFile(path, size, png)) {
                        result->Success(flutter::EncodableValue(std::vector<uint8_t>{}));
                        return;
                    }

                    result->Success(flutter::EncodableValue(png));
                    return;
                }

                result->NotImplemented();
            });

    // IMPORTANT: keep channel alive by leaking or storing globally
    // simplest: release ownership
    channel.release();
}
