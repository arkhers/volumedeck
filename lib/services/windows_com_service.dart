import 'dart:convert';
import 'dart:io';

class WindowsComService {
  Future<List<Map<String, String>>> listComPorts() async {
    final ps = await Process.run(
      'powershell',
      [
        '-NoProfile',
        '-Command',
        r"Get-CimInstance Win32_SerialPort | Select-Object DeviceID,Name | ConvertTo-Json"
      ],
    );

    if (ps.exitCode != 0) return [];

    final out = (ps.stdout ?? '').toString().trim();
    if (out.isEmpty) return [];

    final dynamic decoded = jsonDecode(out);
    final List items = decoded is List ? decoded : [decoded];

    return items.map<Map<String, String>>((e) {
      return {
        'deviceId': (e['DeviceID'] ?? '').toString(), // COM7
        'name': (e['Name'] ?? '').toString(), // Arduino Uno (COM7)
      };
    }).where((m) => (m['deviceId'] ?? '').isNotEmpty).toList();
  }

  String? guessArduinoCom(List<Map<String, String>> ports) {
    final keywords = [
      'arduino',
      'ch340',
      'cp210',
      'usb-serial',
      'silicon labs',
      'ftdi',
      'wch'
    ];
    for (final p in ports) {
      final n = (p['name'] ?? '').toLowerCase();
      if (keywords.any((k) => n.contains(k))) return p['deviceId'];
    }
    return ports.isNotEmpty ? ports.first['deviceId'] : null;
  }
}
