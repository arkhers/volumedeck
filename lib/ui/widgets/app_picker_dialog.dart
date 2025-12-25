import 'package:flutter/material.dart';

class AppPickerDialog extends StatefulWidget {
  final List<String> runningApps;          // ör: AppState.runningExe
  final Set<String> initialSelected;       // slider’da daha önce seçilmişler
  final bool multiSelect;                  // group ise true

  const AppPickerDialog({
    super.key,
    required this.runningApps,
    required this.initialSelected,
    required this.multiSelect,
  });

  @override
  State<AppPickerDialog> createState() => _AppPickerDialogState();
}

class _AppPickerDialogState extends State<AppPickerDialog> {
  late Set<String> selected;
  String q = '';

  @override
  void initState() {
    super.initState();
    // ✅ daha önce seçilmişleri aynen getir
    selected = {...widget.initialSelected};
  }

  @override
  Widget build(BuildContext context) {
    final query = q.trim().toLowerCase();

    // ✅ seçili olanlar çalışmıyor olsa bile listede görünsün:
    final merged = <String>{
      ...selected,
      ...widget.runningApps,
    }.toList()
      ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));

    final filtered = query.isEmpty
        ? merged
        : merged.where((e) => e.toLowerCase().contains(query)).toList();

    return Dialog(
      child: SizedBox(
        width: 520,
        height: 620,
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Uygulamaları seç', style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 12),

              TextField(
                onChanged: (v) => setState(() => q = v),
                decoration: const InputDecoration(
                  prefixIcon: Icon(Icons.search),
                  hintText: 'Ara (chrome, discord...)',
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
              ),
              const SizedBox(height: 12),

              // ✅ seçili olanları üstte küçük bilgi olarak da gösterebilirsin
              if (selected.isNotEmpty) ...[
                Text(
                  'Seçili: ${selected.join(", ")}',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const SizedBox(height: 8),
              ],

              Expanded(
                child: ListView.builder(
                  itemCount: filtered.length,
                  itemBuilder: (_, i) {
                    final name = filtered[i];
                    final checked = selected.contains(name);

                    return CheckboxListTile(
                      dense: true,
                      value: checked,
                      title: Text(name),
                      controlAffinity: ListTileControlAffinity.leading,
                      onChanged: (v) {
                        setState(() {
                          if (widget.multiSelect) {
                            if (v == true) {
                              selected.add(name);
                            } else {
                              selected.remove(name);
                            }
                          } else {
                            // tek seçim modunda: sadece 1 tane kalsın
                            selected = v == true ? {name} : <String>{};
                          }
                        });
                      },
                    );
                  },
                ),
              ),

              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('İptal'),
                  ),
                  const SizedBox(width: 8),
                  FilledButton(
                    onPressed: () {
                      // ✅ seçili listeyi geri döndür
                      Navigator.pop<Set<String>>(context, selected);
                    },
                    child: const Text('Seç'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
