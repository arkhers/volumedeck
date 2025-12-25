import 'dart:async';
import 'package:flutter/material.dart';
import '../../services/windows_mixer_service.dart';

class DeckView extends StatefulWidget {
  const DeckView({super.key});

  @override
  State<DeckView> createState() => _DeckViewState();
}

class _DeckViewState extends State<DeckView> {
  final _mixer = WindowsMixerService();
  Timer? _t;

  MixerSnapshot? snap;

  // 3 örnek kanal (sen arttırırsın)
  final channels = <_DeckChannel>[
    _DeckChannel(title: 'XLR Dock', type: _TargetType.master),
    _DeckChannel(title: 'Browser', type: _TargetType.exe, exeName: 'chrome.exe'),
    _DeckChannel(title: 'Game', type: _TargetType.exe, exeName: 'rocketleague.exe'),
  ];

  @override
  void initState() {
    super.initState();
    _tick();
    _t = Timer.periodic(const Duration(milliseconds: 50), (_) => _tick()); // ~20 FPS
  }

  @override
  void dispose() {
    _t?.cancel();
    super.dispose();
  }

  Future<void> _tick() async {
    final s = await _mixer.getSnapshot(includeSessions: true);
    if (!mounted) return;
    setState(() => snap = s);
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final s = snap;

    return Scaffold(
      backgroundColor: cs.surface,
      body: Padding(
        padding: const EdgeInsets.all(18),
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: channels.map((ch) {
              final vm = _resolveChannel(s, ch);
              return Padding(
                padding: const EdgeInsets.only(right: 14),
                child: _DeckCard(
                  title: ch.title,
                  subtitle: ch.type == _TargetType.master ? 'master' : (ch.exeName ?? ''),
                  peak: vm.peak,
                  volume: vm.volume,
                  muted: vm.mute,
                  onVolume: (v) => _setVolume(ch, v),
                  onToggleMute: () => _setMute(ch, !vm.mute),
                ),
              );
            }).toList(),
          ),
        ),
      ),
    );
  }

  _VM _resolveChannel(MixerSnapshot? s, _DeckChannel ch) {
    if (s == null) return _VM(peak: 0, volume: 1, mute: false);

    if (ch.type == _TargetType.master) {
      return _VM(peak: s.masterPeak, volume: s.masterVolume, mute: s.masterMute);
    }

    // exe -> ilk session eşleşmesi
    final want = (ch.exeName ?? '').toLowerCase();
    final sess = s.sessions.firstWhere(
          (x) => x.exeName.toLowerCase() == want,
      orElse: () => MixerSession(
        sessionId: '',
        pid: 0,
        exeName: want,
        exePath: '',
        displayName: '',
        volume: 1,
        mute: false,
        peak: 0,
      ),
    );
    return _VM(peak: sess.peak, volume: sess.volume, mute: sess.mute, sessionId: sess.sessionId);
  }

  Future<void> _setVolume(_DeckChannel ch, double v) async {
    if (ch.type == _TargetType.master) {
      await _mixer.setMasterVolume(v);
      return;
    }
    final sid = await _mixer.findSessionIdByExe(ch.exeName ?? '');
    if (sid == null) return;
    await _mixer.setSessionVolume(sid, v);
  }

  Future<void> _setMute(_DeckChannel ch, bool mute) async {
    if (ch.type == _TargetType.master) {
      await _mixer.setMasterMute(mute);
      return;
    }
    final sid = await _mixer.findSessionIdByExe(ch.exeName ?? '');
    if (sid == null) return;
    await _mixer.setSessionMute(sid, mute);
  }
}

class _DeckCard extends StatelessWidget {
  const _DeckCard({
    required this.title,
    required this.subtitle,
    required this.peak,
    required this.volume,
    required this.muted,
    required this.onVolume,
    required this.onToggleMute,
  });

  final String title;
  final String subtitle;
  final double peak;
  final double volume;
  final bool muted;
  final ValueChanged<double> onVolume;
  final VoidCallback onToggleMute;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Container(
      width: 220,
      height: 520,
      decoration: BoxDecoration(
        color: cs.surfaceContainerLow,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: cs.outlineVariant.withOpacity(0.35)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 18,
            offset: const Offset(0, 8),
          )
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // header
            Row(
              children: [
                Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    color: cs.primaryContainer.withOpacity(0.7),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(Icons.tune_rounded, size: 16, color: cs.onPrimaryContainer),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title, style: const TextStyle(fontWeight: FontWeight.w900)),
                      Text(subtitle, style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant)),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: onToggleMute,
                  icon: Icon(muted ? Icons.volume_off_rounded : Icons.volume_up_rounded),
                )
              ],
            ),

            const SizedBox(height: 12),

            // meter (yatay bar)
            ClipRRect(
              borderRadius: BorderRadius.circular(999),
              child: SizedBox(
                height: 10,
                child: LinearProgressIndicator(
                  value: peak.clamp(0, 1),
                  backgroundColor: cs.surfaceContainerHighest,
                ),
              ),
            ),

            const SizedBox(height: 18),

            // dikey slider alanı
            Expanded(
              child: Center(
                child: RotatedBox(
                  quarterTurns: -1,
                  child: Slider(
                    value: volume.clamp(0, 1),
                    onChanged: onVolume,
                  ),
                ),
              ),
            ),

            const SizedBox(height: 8),

            // alt bar (mute)
            Container(
              height: 44,
              decoration: BoxDecoration(
                color: cs.surface,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: cs.outlineVariant.withOpacity(0.35)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(muted ? Icons.mic_off : Icons.mic, size: 18, color: cs.onSurfaceVariant),
                  const SizedBox(width: 10),
                  Text(
                    muted ? 'Muted' : 'Active',
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

enum _TargetType { master, exe }

class _DeckChannel {
  _DeckChannel({required this.title, required this.type, this.exeName});
  final String title;
  final _TargetType type;
  final String? exeName;
}

class _VM {
  _VM({required this.peak, required this.volume, required this.mute, this.sessionId});
  final double peak;
  final double volume;
  final bool mute;
  final String? sessionId;
}
