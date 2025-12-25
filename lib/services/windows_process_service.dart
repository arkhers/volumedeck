import 'dart:io';

import 'package:flutter/foundation.dart';

class WindowsProcessService {
  Future<List<Map<String, String>>> listRunningExeWithPath() async {
    if (!Platform.isWindows) return [];

    final psExe = _powershellExePath();

    // 1) PRIMARY: Get-Process (en stabil)
    final psScript1 = _oneLine(r'''
[Console]::OutputEncoding = [System.Text.UTF8Encoding]::new();
$ErrorActionPreference="SilentlyContinue";
$groups = Get-Process | Group-Object ProcessName;
foreach($grp in $groups){
  $p = $grp.Group | Where-Object { $_.Path -and $_.Path.Trim().Length -gt 0 } | Select-Object -First 1;
  if(-not $p){ $p = $grp.Group | Select-Object -First 1; }
  $name = $p.ProcessName;
  if(-not $name.ToLower().EndsWith(".exe")){ $name = "$name.exe"; }
  "$name|$($p.Path)"
}
''');

    final rows1 = await _runPsAndParse(psExe, psScript1, tag: 'Get-Process');

    // ✅ KRİTİK: çıktı geldiyse fallback’e ASLA düşme.
    // Path az olsa bile (ör. sadece 5 tanesi dolu) yine de ikonlar gelir.
    if (rows1.isNotEmpty) {
      return _dedupeAndSort(rows1);
    }

    // 2) SECONDARY: CIM/WMI
    final psScript2 = _oneLine(r'''
[Console]::OutputEncoding = [System.Text.UTF8Encoding]::new();
$ErrorActionPreference="SilentlyContinue";
Get-CimInstance Win32_Process |
  Group-Object Name |
  ForEach-Object {
    $g = $_.Group;
    $p = $g | Where-Object { $_.ExecutablePath -and $_.ExecutablePath.Trim().Length -gt 0 } | Select-Object -First 1;
    if (-not $p) { $p = $g | Select-Object -First 1; }
    "$($p.Name)|$($p.ExecutablePath)"
  }
''');

    final rows2 = await _runPsAndParse(psExe, psScript2, tag: 'CIM');
    if (rows2.isNotEmpty) {
      return _dedupeAndSort(rows2);
    }

    // 3) FALLBACK: tasklist (path yok)
    try {
      final res = await Process.run(
        'cmd',
        ['/c', 'tasklist', '/fo', 'csv', '/nh'],
        runInShell: false,
      );

      final out = (res.stdout ?? '').toString();
      final names = _parseTasklistCsv(out);
      final rows = names.map((n) => {'name': n, 'path': ''}).toList();

      if (kDebugMode) {
        final err = (res.stderr ?? '').toString().trim();
        debugPrint('[proc][tasklist] count=${rows.length} stderr=$err');
      }

      return _dedupeAndSort(rows);
    } catch (e) {
      if (kDebugMode) debugPrint('[proc][tasklist] failed: $e');
      return [];
    }
  }

  Future<List<Map<String, String>>> _runPsAndParse(
      String psExe,
      String psScript, {
        required String tag,
      }) async {
    try {
      final res = await Process.run(
        psExe,
        ['-NoProfile', '-NonInteractive', '-ExecutionPolicy', 'Bypass', '-Command', psScript],
        runInShell: false,
      );

      final out = (res.stdout ?? '').toString().trim();
      final err = (res.stderr ?? '').toString().trim();

      if (kDebugMode) {
        debugPrint('[proc][$tag] exitCode=${res.exitCode}');
        if (err.isNotEmpty) debugPrint('[proc][$tag] stderr=$err');
        debugPrint('[proc][$tag] outLen=${out.length}');
      }

      if (res.exitCode != 0 || out.isEmpty) return [];
      return _parseNamePathLines(out);
    } catch (e) {
      if (kDebugMode) debugPrint('[proc][$tag] failed: $e');
      return [];
    }
  }

  String _powershellExePath() {
    final sysRoot = Platform.environment['SystemRoot'] ?? r'C:\Windows';
    final p = r'\System32\WindowsPowerShell\v1.0\powershell.exe';
    final full = '$sysRoot$p';
    return File(full).existsSync() ? full : 'powershell';
  }

  String _oneLine(String s) {
    return s
        .replaceAll('\r\n', '\n')
        .split('\n')
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .join(' ');
  }

  List<Map<String, String>> _parseNamePathLines(String out) {
    final lines = out
        .split(RegExp(r'\r?\n'))
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty);

    final rows = <Map<String, String>>[];
    for (final line in lines) {
      final parts = line.split('|');
      if (parts.isEmpty) continue;

      final name = parts[0].trim();
      final path = parts.length >= 2 ? parts.sublist(1).join('|').trim() : '';

      if (name.isEmpty) continue;
      rows.add({'name': name, 'path': path});
    }
    return rows;
  }

  List<String> _parseTasklistCsv(String out) {
    final lines = out
        .split(RegExp(r'\r?\n'))
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty);

    final names = <String>[];
    for (final line in lines) {
      if (!line.startsWith('"')) continue;
      final firstEnd = line.indexOf('","');
      if (firstEnd <= 1) continue;
      final imageName = line.substring(1, firstEnd).trim();
      if (imageName.isNotEmpty) names.add(imageName);
    }
    return names;
  }

  List<Map<String, String>> _dedupeAndSort(List<Map<String, String>> rows) {
    final byName = <String, Map<String, String>>{};

    for (final r in rows) {
      final name = (r['name'] ?? '').trim();
      if (name.isEmpty) continue;

      final key = name.toLowerCase();
      final path = (r['path'] ?? '').trim();

      final existing = byName[key];
      if (existing == null) {
        byName[key] = {'name': name, 'path': path};
      } else {
        final existingPath = (existing['path'] ?? '').trim();
        if (existingPath.isEmpty && path.isNotEmpty) {
          byName[key] = {'name': name, 'path': path};
        }
      }
    }

    final uniq = byName.values.toList();
    uniq.sort((a, b) =>
        (a['name'] ?? '').toLowerCase().compareTo((b['name'] ?? '').toLowerCase()));
    return uniq;
  }
}
