import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

class WindowsIconService {
  WindowsIconService._();
  static final WindowsIconService I = WindowsIconService._();

  // Basit cache: "path|size" -> png bytes
  final Map<String, Uint8List?> _cache = {};

  Future<Uint8List?> getExeIconPng(String exePath, {int size = 20}) async {
    if (!Platform.isWindows) return null;

    final p = exePath.trim();
    if (p.isEmpty) return null;

    final key = '${p.toLowerCase()}|$size';
    if (_cache.containsKey(key)) return _cache[key];

    final psExe = _powershellExePath();

    // Base64 PNG üretip stdout’a basıyoruz (tek satır).
    // Parametreleri $args[0]=path, $args[1]=size şeklinde alıyoruz.
    const psScript = r'''
$ErrorActionPreference = "SilentlyContinue";

$p = $args[0];
$size = 32;
if ($args.Length -ge 2) { 
  $tmp = 0; 
  if ([int]::TryParse($args[1], [ref]$tmp)) { $size = $tmp } 
}

if ([string]::IsNullOrWhiteSpace($p)) { exit 0 }
if (-not (Test-Path -LiteralPath $p)) { exit 0 }

Add-Type -AssemblyName System.Drawing | Out-Null;

try {
  $ico = [System.Drawing.Icon]::ExtractAssociatedIcon($p);
  if ($null -eq $ico) { exit 0 }

  $bmp = $ico.ToBitmap();
  $ico.Dispose();

  # Kareye ölçekle (size x size)
  $resized = New-Object System.Drawing.Bitmap($bmp, $size, $size);
  $bmp.Dispose();

  $ms = New-Object System.IO.MemoryStream;
  $resized.Save($ms, [System.Drawing.Imaging.ImageFormat]::Png);
  $resized.Dispose();

  $b64 = [Convert]::ToBase64String($ms.ToArray());
  $ms.Dispose();

  [Console]::Out.Write($b64);
} catch {
  # sessiz çık
  exit 0
}
''';

    final encoded = _toEncodedCommand(psScript);

    try {
      final res = await Process.run(
        psExe,
        [
          '-NoProfile',
          '-NonInteractive',
          '-ExecutionPolicy',
          'Bypass',
          '-EncodedCommand',
          encoded,
          p,
          size.toString(),
        ],
        runInShell: true,
      );

      // İstersen log:
      // print('[icon] exit=${res.exitCode} outLen=${(res.stdout ?? '').toString().length}');
      // if (res.exitCode != 0) print('[icon] stderr=${res.stderr}');

      if (res.exitCode != 0) {
        _cache[key] = null;
        return null;
      }

      final out = (res.stdout ?? '').toString().trim();
      if (out.isEmpty) {
        _cache[key] = null;
        return null;
      }

      final bytes = base64Decode(out);
      _cache[key] = bytes;
      return bytes;
    } catch (_) {
      _cache[key] = null;
      return null;
    }
  }

  String _powershellExePath() {
    final sysRoot = Platform.environment['SystemRoot'] ?? r'C:\Windows';
    final full = r'\System32\WindowsPowerShell\v1.0\powershell.exe';
    final path = '$sysRoot$full';
    return File(path).existsSync() ? path : 'powershell';
  }

  /// PowerShell -EncodedCommand: UTF-16LE bytes -> base64
  String _toEncodedCommand(String script) {
    final units = script.codeUnits;
    final bytes = Uint8List(units.length * 2);
    var j = 0;
    for (final c in units) {
      bytes[j++] = c & 0xFF;
      bytes[j++] = (c >> 8) & 0xFF;
    }
    return base64Encode(bytes);
  }
}
