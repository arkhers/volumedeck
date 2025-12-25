import 'dart:convert';
import 'dart:io';

class WindowsAudioService {
  Future<List<String>> listAudioEndpoints() async {
    final r = await Process.run(
      'powershell',
      [
        '-NoProfile',
        '-Command',
        r'''
Get-PnpDevice -Class AudioEndpoint |
  Where-Object {$_.Status -eq "OK"} |
  Select-Object -ExpandProperty FriendlyName |
  Sort-Object -Unique |
  ConvertTo-Json
'''
      ],
    );

    if (r.exitCode != 0) return [];

    final out = (r.stdout ?? '').toString().trim();
    if (out.isEmpty) return [];

    final decoded = jsonDecode(out);
    final List list = decoded is List ? decoded : [decoded];

    final items = list.map((e) => e.toString().trim()).where((e) => e.isNotEmpty).toSet().toList()
      ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));

    return items;
  }
}
