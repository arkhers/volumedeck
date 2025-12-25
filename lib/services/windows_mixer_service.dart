import 'dart:async';
import 'dart:io';
import 'package:flutter/services.dart';

class MixerSnapshot {
  final double masterVolume;
  final bool masterMute;
  final double masterPeak;
  final List<MixerSession> sessions;

  MixerSnapshot({
    required this.masterVolume,
    required this.masterMute,
    required this.masterPeak,
    required this.sessions,
  });

  factory MixerSnapshot.fromMap(Map<dynamic, dynamic> m) {
    final master = (m['master'] as Map).cast<dynamic, dynamic>();
    final sessions = (m['sessions'] as List? ?? const [])
        .map((e) => MixerSession.fromMap((e as Map).cast<dynamic, dynamic>()))
        .toList();

    return MixerSnapshot(
      masterVolume: (master['volume'] as num?)?.toDouble() ?? 1.0,
      masterMute: master['mute'] == true,
      masterPeak: (master['peak'] as num?)?.toDouble() ?? 0.0,
      sessions: sessions,
    );
  }
}

class MixerSession {
  final String sessionId;
  final int pid;
  final String exeName;
  final String exePath;
  final String displayName;
  final double volume;
  final bool mute;
  final double peak;

  MixerSession({
    required this.sessionId,
    required this.pid,
    required this.exeName,
    required this.exePath,
    required this.displayName,
    required this.volume,
    required this.mute,
    required this.peak,
  });

  factory MixerSession.fromMap(Map<dynamic, dynamic> m) {
    return MixerSession(
      sessionId: (m['sessionId'] ?? '').toString(),
      pid: (m['pid'] as num?)?.toInt() ?? 0,
      exeName: (m['exeName'] ?? '').toString(),
      exePath: (m['exePath'] ?? '').toString(),
      displayName: (m['displayName'] ?? '').toString(),
      volume: (m['volume'] as num?)?.toDouble() ?? 1.0,
      mute: m['mute'] == true,
      peak: (m['peak'] as num?)?.toDouble() ?? 0.0,
    );
  }
}

class WindowsMixerService {
  static const MethodChannel _ch = MethodChannel('volumedeck_mixer');

  Future<MixerSnapshot> getSnapshot({bool includeSessions = true}) async {
    if (!Platform.isWindows) {
      return MixerSnapshot(masterVolume: 1, masterMute: false, masterPeak: 0, sessions: []);
    }
    final res = await _ch.invokeMethod<Map>('getSnapshot', {
      'includeSessions': includeSessions,
    });
    return MixerSnapshot.fromMap(res ?? {});
  }

  Future<String?> findSessionIdByExe(String exeName) async {
    final res = await _ch.invokeMethod('findSessionIdByExe', {'exeName': exeName});
    return res as String?;
  }

  Future<void> setMasterVolume(double v01) async {
    await _ch.invokeMethod('setMasterVolume', {'value': v01});
  }

  Future<void> setMasterMute(bool mute) async {
    await _ch.invokeMethod('setMasterMute', {'mute': mute});
  }

  Future<void> setSessionVolume(String sessionId, double v01) async {
    await _ch.invokeMethod('setSessionVolume', {'sessionId': sessionId, 'value': v01});
  }

  Future<void> setSessionMute(String sessionId, bool mute) async {
    await _ch.invokeMethod('setSessionMute', {'sessionId': sessionId, 'mute': mute});
  }
}
