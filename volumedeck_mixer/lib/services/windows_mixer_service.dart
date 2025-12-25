import 'dart:async';
import 'package:flutter/services.dart';

class WindowsMixerService {
  WindowsMixerService._();
  static final WindowsMixerService I = WindowsMixerService._();

  // ✅ Kanal adı C++ tarafıyla birebir aynı olmalı: "volumedeck_mixer"
  static const MethodChannel _ch = MethodChannel('volumedeck_mixer');

  /// Native taraftan snapshot alır:
  /// örnek dönüş: {"ok":true, "master":0.75, "apps":[...]} gibi
  Future<Map<String, dynamic>> getSnapshot() async {
    final res = await _ch.invokeMethod('getSnapshot');
    if (res == null) return <String, dynamic>{};
    return Map<String, dynamic>.from(res as Map);
  }
}
