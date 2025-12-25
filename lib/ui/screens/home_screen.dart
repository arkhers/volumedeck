import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../state/app_state.dart';
import '../widgets/exe_icon.dart';
import '../widgets/slider_editor_dialog.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  String trDeviceLabel(String raw) {
    var s = raw;

    s = s.replaceAll(RegExp(r'\bspeakers\b', caseSensitive: false), 'Hoparlör');
    s = s.replaceAll(RegExp(r'\bmicrophone\b', caseSensitive: false), 'Mikrofon');
    s = s.replaceAll(RegExp(r'\bheadphones\b', caseSensitive: false), 'Kulaklık');
    s = s.replaceAll(RegExp(r'\bdefault\b', caseSensitive: false), 'Varsayılan');

    return s;
  }

  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppState>();
    final read = context.read<AppState>();
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return Scaffold(
      backgroundColor: cs.surface,
      appBar: AppBar(
        elevation: 0,
        scrolledUnderElevation: 0,
        backgroundColor: Colors.transparent,
        title: Align(
          alignment: Alignment.centerLeft,
          child: Image.asset('assets/brand/decklogo.png', height: 26),
        ),
        actions: [
          _ActionButton(
            tooltip: 'Deej Yeniden Başlat',
            onPressed: s.deejExePath == null ? null : () => read.restartDeej(),
            icon: Icons.restart_alt_rounded,
          ),
          _ActionButton(
            tooltip: 'Süreçleri Yenile',
            onPressed: () => read.refreshRunningProcesses(),
            icon: Icons.refresh_rounded,
          ),
          _ActionButton(
            tooltip: 'Ses Cihazlarını Yenile',
            onPressed: () => read.refreshAudioDevices(),
            icon: Icons.speaker_group_outlined,
          ),
          const SizedBox(width: 16),
        ],
      ),
      body: Row(
        children: [
          // Sol Panel
          Container(
            width: 400,
            decoration: BoxDecoration(
              border: Border(
                right: BorderSide(
                  color: cs.outlineVariant.withOpacity(0.5),
                  width: 1,
                ),
              ),
            ),
            child: const _LeftPanel(),
          ),

          // Sağ Panel (ARTIK SADECE MAPPING)
          Expanded(
            child: Container(
              color: cs.surfaceContainerLowest.withOpacity(0.3),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
                child: const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _RightPanelHeader(),
                    SizedBox(height: 16),
                    Expanded(child: _SliderListModern()),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
      bottomNavigationBar: _BottomBar(
        text: s.configPath == null
            ? (s.deejFolderPath == null ? 'Deej klasörü seçilmedi' : 'config.yaml bulunamadı')
            : 'Dosya: ${s.configPath}',
        canSave: s.deejFolderPath != null,
        showDeejMissingChip: s.deejExePath == null,
        onSave: () async {
          await read.saveConfig();
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                behavior: SnackBarBehavior.floating,
                width: 320,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                content: const Row(
                  children: [
                    Icon(Icons.check_circle_outline, color: Colors.white, size: 20),
                    SizedBox(width: 12),
                    Text('Ayarlar başarıyla kaydedildi'),
                  ],
                ),
              ),
            );
          }
        },
      ),
    );
  }
}

/* ---------------------------- RIGHT PANEL ---------------------------- */

class _RightPanelHeader extends StatelessWidget {
  const _RightPanelHeader();

  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppState>();
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    final keys = s.cfg.sliderMapping.keys.toList()..sort();
    final total = keys.length;
    int filled = 0;
    for (final k in keys) {
      final sum = s.cfg.sliderMapping[k]!.summary().trim();
      if (sum.isNotEmpty) filled++;
    }
    final empty = total - filled;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Kanal Atamaları',
                    style: theme.textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.8,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Deej config.yaml düzenleyici',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: cs.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            FilledButton.icon(
              onPressed: () => context.read<AppState>().addNextSlider(),
              icon: const Icon(Icons.add_rounded, size: 20),
              label: const Text('Yeni Kanal Ekle'),
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            _MiniStat(label: 'Toplam', value: '$total'),
            _MiniStat(label: 'Dolu', value: '$filled'),
            _MiniStat(label: 'Boş', value: '$empty'),
          ],
        ),
      ],
    );
  }
}

class _MiniStat extends StatelessWidget {
  final String label;
  final String value;
  const _MiniStat({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: cs.outlineVariant.withOpacity(0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              color: cs.onSurfaceVariant,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.2,
            ),
          ),
          const SizedBox(height: 2),
          Text(value, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900)),
        ],
      ),
    );
  }
}

/* ---------------------------- LEFT PANEL ---------------------------- */

class _LeftPanel extends StatelessWidget {
  const _LeftPanel();

  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppState>();
    final read = context.read<AppState>();

    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        _ModernSection(
          title: 'Genel Ayarlar',
          icon: Icons.settings_suggest_outlined,
          child: Column(
            children: [
              _ActionTile(
                title: 'Deej Klasörü',
                subtitle: s.deejFolderPath ?? 'Seçilmedi',
                icon: Icons.folder_open_rounded,
                onTap: () => read.pickDeejFolderAndAutoFind(),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(child: _StatusIndicator(label: 'deej.exe', isActive: s.deejExePath != null)),
                  const SizedBox(width: 12),
                  Expanded(child: _StatusIndicator(label: 'config.yaml', isActive: s.configPath != null)),
                ],
              ),
              if (s.deejFolderPath != null && s.configPath == null) ...[
                const SizedBox(height: 14),
                _InlineWarning(
                  text: 'Bu klasörde config.yaml yok. Oluşturup devam edebilirsin.',
                  actionText: 'Oluştur',
                  onAction: () => read.createConfigInDeejFolder(),
                ),
              ],
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: s.deejExePath == null ? null : () => read.restartDeej(),
                      icon: const Icon(Icons.restart_alt_rounded, size: 18),
                      label: const Text('Yeniden Başlat'),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton.filledTonal(
                    onPressed: () => read.stopDeej(),
                    icon: const Icon(Icons.stop_rounded),
                    style: IconButton.styleFrom(
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              SwitchListTile(
                value: s.autoRestartAfterSave,
                onChanged: (v) => read.setAutoRestart(v),
                title: const Text(
                  'Kaydedince otomatik restart',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                ),
                contentPadding: EdgeInsets.zero,
                dense: true,
              ),
            ],
          ),
        ),

        const SizedBox(height: 24),

        _ModernSection(
          title: 'Donanım Bağlantısı',
          icon: Icons.usb_rounded,
          child: Column(
            children: [
              Row(
                children: [
                  Expanded(child: _ComDropdown()),
                  const SizedBox(width: 8),
                  IconButton.filledTonal(
                    onPressed: () => read.refreshComPorts(),
                    icon: const Icon(Icons.refresh_rounded, size: 20),
                    tooltip: 'COM yenile',
                    style: IconButton.styleFrom(
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton.filledTonal(
                    onPressed: () => read.autoSelectArduinoCom(),
                    icon: const Icon(Icons.auto_fix_high_rounded, size: 20),
                    tooltip: 'Otomatik bul',
                    style: IconButton.styleFrom(
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: DropdownButtonFormField<int>(
                      value: s.cfg.baudRate,
                      items: const [9600, 115200]
                          .map((v) => DropdownMenuItem(value: v, child: Text('$v Baud')))
                          .toList(),
                      onChanged: (v) => v != null ? read.setBaudRate(v) : null,
                      decoration: InputDecoration(
                        labelText: 'Baud',
                        isDense: true,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      value: s.cfg.noiseReduction,
                      items: const ['low', 'default', 'high']
                          .map((v) => DropdownMenuItem(value: v, child: Text(v)))
                          .toList(),
                      onChanged: (v) => v != null ? read.setNoiseReduction(v) : null,
                      decoration: InputDecoration(
                        labelText: 'Parazit azaltma',
                        isDense: true,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              SwitchListTile(
                value: s.cfg.invertSliders,
                onChanged: (v) => read.setInvert(v),
                title: const Text(
                  'Kanal yönünü ters çevir',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                ),
                contentPadding: EdgeInsets.zero,
                dense: true,
              ),
            ],
          ),
        ),

        const SizedBox(height: 24),

        _ModernSection(
          title: 'Slider Sayısı',
          icon: Icons.tune_rounded,
          child: Column(
            children: [
              DropdownButtonFormField<String>(
                isExpanded: true,
                value: s.boardPreset,
                items: const ['Özel', 'UNO/NANO (6)', 'MEGA (16)']
                    .map((v) => DropdownMenuItem(value: v, child: Text(v)))
                    .toList(),
                onChanged: (v) => v != null ? read.setBoardPreset(v) : null,
                decoration: InputDecoration(
                  labelText: 'Kart şablonu',
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      initialValue: s.desiredSliderCount.toString(),
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        labelText: 'Kanal sayısı (1..N)',
                        isDense: true,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      onFieldSubmitted: (v) {
                        final n = int.tryParse(v) ?? s.desiredSliderCount;
                        read.setDesiredSliderCount(n);
                      },
                    ),
                  ),
                  const SizedBox(width: 10),
                  FilledButton.tonal(
                    onPressed: () => read.ensureSliderCount(s.desiredSliderCount),
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    child: const Text('Uygula'),
                  ),
                ],
              ),
            ],
          ),
        ),

        const SizedBox(height: 24),

        _ModernSection(
          title: 'Ses Cihazları',
          icon: Icons.speaker_group_outlined,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      '${s.audioDevices.length} cihaz bulundu',
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
                    ),
                  ),
                  OutlinedButton.icon(
                    onPressed: () => read.refreshAudioDevices(),
                    icon: const Icon(Icons.refresh_rounded, size: 18),
                    label: const Text('Yenile'),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              if (s.audioDevices.isEmpty)
                Text(
                  'Cihaz bulunamadı.',
                  style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.onSurfaceVariant),
                )
              else
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: s.audioDevices.take(10).map((d) {
                    return Chip(
                      label: SizedBox(
                        width: 220,
                        child: Text(d, overflow: TextOverflow.ellipsis),
                      ),
                    );
                  }).toList(),
                ),
              if (s.audioDevices.length > 10) ...[
                const SizedBox(height: 8),
                Text(
                  '… ve ${s.audioDevices.length - 10} tane daha (slider editörden seçebilirsin)',
                  style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.onSurfaceVariant),
                ),
              ],
            ],
          ),
        ),

        const SizedBox(height: 24),

        const _RunningAppsSection(),
        const SizedBox(height: 24),
      ],
    );
  }
}

/* ---------------------------- RUNNING APPS (ICONLU) ---------------------------- */

class _RunningAppsSection extends StatefulWidget {
  const _RunningAppsSection();

  @override
  State<_RunningAppsSection> createState() => _RunningAppsSectionState();
}

class _RunningAppsSectionState extends State<_RunningAppsSection> {
  String q = '';

  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppState>();
    final read = context.read<AppState>();
    final cs = Theme.of(context).colorScheme;

    final list = s.runningExe;
    final query = q.trim().toLowerCase();
    final filtered = query.isEmpty ? list : list.where((e) => e.toLowerCase().contains(query)).toList();
    final capped = filtered.length > 200 ? filtered.sublist(0, 200) : filtered;

    final byLower = <String, String>{};
    s.exePathByName.forEach((k, v) {
      if (k.trim().isNotEmpty && v.trim().isNotEmpty) {
        byLower[k.toLowerCase()] = v;
      }
    });

    String? resolvePath(String name) {
      final direct = s.exePathByName[name];
      if (direct != null && direct.trim().isNotEmpty) return direct;
      return byLower[name.toLowerCase()];
    }

    final withPathCount = capped.where((n) {
      final p = resolvePath(n);
      return p != null && p.trim().isNotEmpty;
    }).length;

    return _ModernSection(
      title: 'Çalışan Uygulamalar',
      icon: Icons.apps_outlined,
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${list.length} process bulundu',
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'İkon için path olan: $withPathCount / ${capped.length}',
                      style: TextStyle(fontSize: 11, color: cs.onSurfaceVariant),
                    ),
                  ],
                ),
              ),
              OutlinedButton.icon(
                onPressed: () => read.refreshRunningProcesses(),
                icon: const Icon(Icons.refresh_rounded, size: 18),
                label: const Text('Yenile'),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          TextField(
            onChanged: (v) => setState(() => q = v),
            decoration: InputDecoration(
              hintText: 'Ara (ör: chrome, discord...)',
              prefixIcon: const Icon(Icons.search_rounded),
              isDense: true,
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 260,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: Container(
                decoration: BoxDecoration(
                  color: cs.surface,
                  border: Border.all(color: cs.outlineVariant.withOpacity(0.4)),
                ),
                child: Material(
                  color: cs.surface,
                  child: capped.isEmpty
                      ? Center(
                    child: Text(
                      'Sonuç yok',
                      style: TextStyle(color: cs.onSurfaceVariant),
                    ),
                  )
                      : ListView.separated(
                    itemCount: capped.length,
                    separatorBuilder: (_, __) => Divider(
                      height: 1,
                      color: cs.outlineVariant.withOpacity(0.6),
                    ),
                    itemBuilder: (_, i) {
                      final name = capped[i];
                      final path = resolvePath(name);

                      return ListTile(
                        dense: true,
                        leading: ExeIcon(
                          exePath: path,
                          size: 20,
                          fallback: Icon(Icons.apps_outlined, color: cs.onSurfaceVariant),
                        ),
                        title: Text(name, overflow: TextOverflow.ellipsis),
                        subtitle: (path == null || path.isEmpty)
                            ? null
                            : Text(
                          path,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(fontSize: 11, color: cs.onSurfaceVariant),
                        ),
                      );
                    },
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/* ---------------------------- SLIDER LIST ---------------------------- */

class _SliderListModern extends StatelessWidget {
  const _SliderListModern();

  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppState>();
    final keys = s.cfg.sliderMapping.keys.toList()..sort();

    if (keys.isEmpty) {
      final cs = Theme.of(context).colorScheme;
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.tune_rounded, size: 52, color: cs.outlineVariant),
            const SizedBox(height: 16),
            const Text('Henüz bir slider tanımlanmadı', style: TextStyle(fontWeight: FontWeight.w700)),
            const SizedBox(height: 6),
            Text(
              'Başlamak için "Yeni Kanal Ekle" butonuna tıklayın',
              style: TextStyle(fontSize: 13, color: cs.onSurfaceVariant),
            ),
          ],
        ),
      );
    }

    return ListView.separated(
      itemCount: keys.length,
      padding: const EdgeInsets.only(bottom: 24),
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (_, i) {
        final idx = keys[i];
        final target = s.cfg.sliderMapping[idx]!;
        final cs = Theme.of(context).colorScheme;

        final sum = target.summary().trim();
        final badge = _badgeFromSummary(sum);

        return Container(
          decoration: BoxDecoration(
            color: cs.surface,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.03),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
            border: Border.all(color: cs.outlineVariant.withOpacity(0.4)),
          ),
          child: ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
            leading: Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: cs.primaryContainer.withOpacity(0.45),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Center(
                child: Text(
                  '${idx + 1}',
                  style: TextStyle(
                    fontWeight: FontWeight.w900,
                    color: cs.primary,
                    fontSize: 16,
                  ),
                ),
              ),
            ),
            title: Row(
              children: [
                Expanded(
                  child: Text(
            '${idx + 1}. Kanal',
            style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 15),
                  ),
                ),
                _Badge(text: badge),
              ],
            ),
            subtitle: Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(
                sum.isEmpty ? 'Atama yapılmadı' : sum,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(color: cs.onSurfaceVariant, fontSize: 13),
              ),
            ),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                FilledButton.tonal(
                  onPressed: () async {
                    await showDialog(
                      context: context,
                      builder: (_) => SliderEditorDialog(sliderIndex: idx),
                    );
                  },
                  style: FilledButton.styleFrom(
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  child: const Text('Düzenle'),
                ),
                const SizedBox(width: 8),
                IconButton(
                  onPressed: () => context.read<AppState>().removeSlider(idx),
                  icon: const Icon(Icons.delete_outline_rounded),
                  color: cs.error,
                  style: IconButton.styleFrom(
                    hoverColor: cs.errorContainer.withOpacity(0.5),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  static String _badgeFromSummary(String summary) {
    final s = summary.trim();
    if (s.isEmpty) return 'Boş';

    final lower = s.toLowerCase();
    if (lower.contains('\n') || lower.contains(',') || lower.contains(' - ')) return 'Group';
    if (const {'master', 'system', 'mic', 'deej.unmapped', 'deej.current'}.contains(lower)) return 'Special';
    if (lower.contains('speakers') || lower.contains('microphone')) return 'Device';
    if (lower.endsWith('.exe')) return 'App';
    return 'Custom';
  }
}

/* ---------------------------- SMALL WIDGETS ---------------------------- */

class _Badge extends StatelessWidget {
  final String text;
  const _Badge({required this.text});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    Color bg = cs.surfaceContainerHigh;
    Color fg = cs.onSurfaceVariant;

    switch (text) {
      case 'App':
        bg = cs.primaryContainer.withOpacity(0.6);
        fg = cs.onPrimaryContainer;
        break;
      case 'Device':
        bg = cs.tertiaryContainer.withOpacity(0.6);
        fg = cs.onTertiaryContainer;
        break;
      case 'Group':
        bg = cs.secondaryContainer.withOpacity(0.6);
        fg = cs.onSecondaryContainer;
        break;
      case 'Special':
        bg = cs.surfaceContainerHighest;
        fg = cs.onSurface;
        break;
      case 'Boş':
      default:
        bg = cs.surfaceContainer;
        fg = cs.onSurfaceVariant;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: cs.outlineVariant.withOpacity(0.35)),
      ),
      child: Text(
        text,
        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w900, color: fg),
      ),
    );
  }
}

class _InlineWarning extends StatelessWidget {
  final String text;
  final String actionText;
  final VoidCallback onAction;

  const _InlineWarning({
    required this.text,
    required this.actionText,
    required this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: cs.errorContainer.withOpacity(0.35),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: cs.error.withOpacity(0.25)),
      ),
      child: Row(
        children: [
          Icon(Icons.warning_amber_rounded, size: 18, color: cs.onErrorContainer),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: cs.onErrorContainer),
            ),
          ),
          TextButton(onPressed: onAction, child: Text(actionText)),
        ],
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  final String tooltip;
  final VoidCallback? onPressed;
  final IconData icon;

  const _ActionButton({
    required this.tooltip,
    required this.onPressed,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Tooltip(
        message: tooltip,
        child: IconButton(
          onPressed: onPressed,
          icon: Icon(icon, size: 22),
          style: IconButton.styleFrom(
            backgroundColor: Theme.of(context).colorScheme.surfaceContainer,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        ),
      ),
    );
  }
}

class _BottomBar extends StatelessWidget {
  final String text;
  final bool canSave;
  final bool showDeejMissingChip;
  final Future<void> Function() onSave;

  const _BottomBar({
    required this.text,
    required this.canSave,
    required this.onSave,
    required this.showDeejMissingChip,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Container(
      height: 74,
      padding: const EdgeInsets.symmetric(horizontal: 24),
      decoration: BoxDecoration(
        color: cs.surface,
        border: Border(top: BorderSide(color: cs.outlineVariant.withOpacity(0.5))),
      ),
      child: Row(
        children: [
          Icon(Icons.description_outlined, size: 18, color: cs.primary),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                fontSize: 13,
                color: cs.onSurfaceVariant,
                fontWeight: FontWeight.w600,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (showDeejMissingChip) ...[
            const SizedBox(width: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: cs.errorContainer.withOpacity(0.35),
                borderRadius: BorderRadius.circular(999),
                border: Border.all(color: cs.error.withOpacity(0.25)),
              ),
              child: Text(
                'deej.exe yok → restart yapılamaz',
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: cs.onErrorContainer),
              ),
            ),
          ],
          const SizedBox(width: 18),
          FilledButton.icon(
            onPressed: canSave ? () => onSave() : null,
            icon: const Icon(Icons.save_rounded, size: 18),
            label: const Text('Değişiklikleri Uygula'),
            style: FilledButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
        ],
      ),
    );
  }
}

class _ModernSection extends StatelessWidget {
  final String title;
  final IconData icon;
  final Widget child;

  const _ModernSection({required this.title, required this.icon, required this.child});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 18, color: cs.primary),
            const SizedBox(width: 8),
            Text(
              title.toUpperCase(),
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w800,
                letterSpacing: 1.2,
                color: cs.onSurfaceVariant,
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: cs.surfaceContainerLow,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: cs.outlineVariant.withOpacity(0.3)),
          ),
          child: child,
        ),
      ],
    );
  }
}

class _ActionTile extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final VoidCallback onTap;

  const _ActionTile({required this.title, required this.subtitle, required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: cs.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: cs.outlineVariant.withOpacity(0.5)),
        ),
        child: Row(
          children: [
            Icon(icon, size: 20, color: cs.primary),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800)),
                  Text(
                    subtitle,
                    style: TextStyle(fontSize: 11, color: cs.onSurfaceVariant),
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right_rounded, size: 16, color: cs.onSurfaceVariant),
          ],
        ),
      ),
    );
  }
}

class _StatusIndicator extends StatelessWidget {
  final String label;
  final bool isActive;

  const _StatusIndicator({required this.label, required this.isActive});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final color = isActive ? Colors.green : cs.error;

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.10),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(width: 6, height: 6, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
          const SizedBox(width: 8),
          Text(
            label,
            style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: color),
          ),
        ],
      ),
    );
  }
}

/* ---------------------------- COM DROPDOWN ---------------------------- */

class _ComDropdown extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppState>();
    final ports = (s.comPorts.isNotEmpty)
        ? s.comPorts
        : [
      {'deviceId': s.cfg.comPort, 'name': ''}
    ];

    return DropdownButtonFormField<String>(
      isExpanded: true,
      value: s.cfg.comPort,
      items: ports.map((p) {
        final id = (p['deviceId'] ?? '').toString().trim();
        final name = (p['name'] ?? '').toString().trim();
        final label = name.isEmpty ? id : '$id  $name';

        return DropdownMenuItem<String>(
          value: id,
          child: Tooltip(
            message: label,
            child: Text(
              label,
              overflow: TextOverflow.ellipsis,
              softWrap: false,
              style: const TextStyle(fontSize: 13),
            ),
          ),
        );
      }).toList(),
      onChanged: (v) {
        if (v != null) context.read<AppState>().setComPort(v);
      },
      decoration: InputDecoration(
        labelText: 'COM Port',
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }
}
