import 'dart:typed_data';
import 'package:flutter/material.dart';

import '../../services/windows_icon_service.dart';

class ExeIcon extends StatelessWidget {
  const ExeIcon({
    super.key,
    required this.exePath,
    this.size = 20,
    this.fallback,
  });

  final String? exePath;
  final double size;
  final Widget? fallback;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    final fb = fallback ??
        Icon(
          Icons.apps_outlined,
          size: size,
          color: cs.onSurfaceVariant,
        );

    final p = (exePath ?? '').trim();
    if (p.isEmpty) return fb;

    // key veriyoruz ki exePath/size değişince FutureBuilder temiz başlasın
    return FutureBuilder<Uint8List?>(
      key: ValueKey('${p.toLowerCase()}|${size.round()}'),
      future: WindowsIconService.I.getExeIconPng(p, size: size.round()),
      builder: (context, snap) {
        final bytes = snap.data;
        if (bytes == null || bytes.isEmpty) return fb;

        return ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: Image.memory(
            bytes,
            width: size,
            height: size,
            fit: BoxFit.cover,
            filterQuality: FilterQuality.high,
            gaplessPlayback: true,
          ),
        );
      },
    );
  }
}
