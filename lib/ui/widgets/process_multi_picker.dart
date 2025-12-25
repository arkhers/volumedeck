import 'dart:collection';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../state/app_state.dart';

class ProcessMultiPickerDialog extends StatefulWidget {
  final bool singlePick;
  final List<String> initialSelected;

  const ProcessMultiPickerDialog({
    super.key,
    required this.singlePick,
    this.initialSelected = const <String>[],
  });

  @override
  State<ProcessMultiPickerDialog> createState() => _ProcessMultiPickerDialogState();
}

class _ProcessMultiPickerDialogState extends State<ProcessMultiPickerDialog> {
  final _q = TextEditingController();
  final Set<String> selected = <String>{};

  @override
  void initState() {
    super.initState();

    final init = widget.initialSelected
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();

    if (widget.singlePick) {
      if (init.isNotEmpty) selected.add(init.first);
    } else {
      selected.addAll(init);
    }
  }

  @override
  void dispose() {
    _q.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppState>();
    final query = _q.text.trim().toLowerCase();

    final merged = LinkedHashSet<String>();
    for (final v in widget.initialSelected) {
      final t = v.trim();
      if (t.isNotEmpty) merged.add(t);
    }
    for (final v in s.runningExe) {
      final t = v.trim();
      if (t.isNotEmpty) merged.add(t);
    }

    final allItems = merged.toList();
    final items = allItems.where((e) {
      if (query.isEmpty) return true;
      return e.toLowerCase().contains(query);
    }).toList();

    return AlertDialog(
      title: Text(widget.singlePick ? 'Uygulama seç' : 'Uygulamaları seç'),
      content: SizedBox(
        width: 520,
        height: 520,
        child: Column(
          children: [
            TextField(
              controller: _q,
              decoration: const InputDecoration(
                prefixIcon: Icon(Icons.search),
                hintText: 'Ara (chrome, discord...)',
                border: OutlineInputBorder(),
              ),
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: ListView.builder(
                itemCount: items.length,
                itemBuilder: (_, i) {
                  final name = items[i];
                  final checked = selected.contains(name);

                  return CheckboxListTile(
                    value: checked,
                    title: Text(name),
                    controlAffinity: ListTileControlAffinity.leading,
                    onChanged: (v) {
                      setState(() {
                        if (widget.singlePick) {
                          selected
                            ..clear()
                            ..add(name);
                        } else {
                          if (v == true) {
                            selected.add(name);
                          } else {
                            selected.remove(name);
                          }
                        }
                      });
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, null),
          child: const Text('İptal'),
        ),
        ElevatedButton(
          onPressed: () {
            final out = selected.toList()..sort();
            if (widget.singlePick && out.isNotEmpty) {
              Navigator.pop(context, <String>[out.first]);
              return;
            }
            Navigator.pop(context, out);
          },
          child: const Text('Seç'),
        ),
      ],
    );
  }
}
