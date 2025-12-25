// lib/ui/widgets/slider_editor_dialog.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/deej_config.dart';
import '../../state/app_state.dart';
import 'process_multi_picker.dart';

class SliderEditorDialog extends StatefulWidget {
  final int sliderIndex;
  const SliderEditorDialog({super.key, required this.sliderIndex});

  @override
  State<SliderEditorDialog> createState() => _SliderEditorDialogState();
}

class _SliderEditorDialogState extends State<SliderEditorDialog> {
  bool isGroup = false;
  String singleValue = '';
  List<String> groupValues = [];

  @override
  void initState() {
    super.initState();
    // ✅ Dialog açılınca mevcut config’ten doldur (senin zaten doğru yapmışsın)
    final s = context.read<AppState>();
    final cur = s.cfg.sliderMapping[widget.sliderIndex] ?? SliderTarget.single('');
    isGroup = cur.isGroup;
    singleValue = cur.single ?? '';
    groupValues = [...(cur.group ?? const <String>[])];
  }

  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppState>();
    final theme = Theme.of(context);

    final allSingleOptions = <String>[
      ...AppState.specialTargets,
      ...s.audioDevices,
      ...s.runningExe,
    ];

    return AlertDialog(
      title: Text('${widget.sliderIndex + 1}. Kanal hedefi'),
      content: SizedBox(
        width: 520,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SegmentedButton<bool>(
              segments: const [
                ButtonSegment(value: false, label: Text('Tek hedef')),
                ButtonSegment(value: true, label: Text('Grup')),
              ],
              selected: {isGroup},
              onSelectionChanged: (v) => setState(() => isGroup = v.first),
            ),
            const SizedBox(height: 12),

            if (!isGroup) ...[
              DropdownButtonFormField<String>(
                value: singleValue.isEmpty ? null : singleValue,
                items: allSingleOptions
                    .map((v) => DropdownMenuItem(value: v, child: Text(v)))
                    .toList(),
                onChanged: (v) => setState(() => singleValue = v ?? ''),
                decoration: const InputDecoration(
                  labelText: 'Hedef',
                  border: OutlineInputBorder(),
                  hintText: 'master / system / mic / chrome.exe ...',
                ),
              ),
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  onPressed: () async {
                    final picked = await showDialog<List<String>>(
                      context: context,
                      builder: (_) => ProcessMultiPickerDialog(
                        singlePick: false,
                        initialSelected: groupValues,
                      ),
                    );
                    if (picked != null && picked.isNotEmpty) {
                      setState(() => singleValue = picked.first);
                    }
                  },
                  icon: const Icon(Icons.search),
                  label: const Text('Çalışanlardan seç'),
                ),
              ),
            ] else ...[
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () async {
                        final picked = await showDialog<List<String>>(
                          context: context,
                          builder: (_) => ProcessMultiPickerDialog(
                            singlePick: false,
                            // ✅ önceki seçimi gönder (kritik!)
                            initialSelected: groupValues,
                          ),
                        );

                        if (picked != null) {
                          setState(() {
                            // ✅ seçilenleri aynen koru; boş dönerse de boş olur (kullanıcı temizlemiş olabilir)
                            groupValues = _uniqueKeepOrder(picked);
                          });
                        }
                      },
                      icon: const Icon(Icons.list),
                      label: const Text('Uygulamaları seç'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  OutlinedButton(
                    onPressed: () => setState(() => groupValues = []),
                    child: const Text('Temizle'),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  border: Border.all(color: theme.dividerColor),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  groupValues.isEmpty ? '(boş grup)' : groupValues.join('\n'),
                ),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('İptal'),
        ),
        ElevatedButton(
          onPressed: () {
            final target = isGroup
                ? SliderTarget.group(_uniqueKeepOrder(groupValues))
                : SliderTarget.single(singleValue);

            context.read<AppState>().upsertSlider(widget.sliderIndex, target);
            Navigator.pop(context, true);
          },
          child: const Text('Uygula'),
        ),
      ],
    );
  }

  // ✅ aynı exe iki kere seçilirse tekilleştir, sıralamayı bozma
  static List<String> _uniqueKeepOrder(List<String> input) {
    final seen = <String>{};
    final out = <String>[];
    for (final x in input) {
      final v = x.trim();
      if (v.isEmpty) continue;
      if (seen.add(v)) out.add(v);
    }
    return out;
  }
}
