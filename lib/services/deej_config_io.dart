import 'dart:io';
import 'package:yaml/yaml.dart';
import '../models/deej_config.dart';

const _headerComment = r'''
# process names are case-insensitive
# you can use 'master' to indicate the master channel, or a list of process names to create a group
# you can use 'mic' to control your mic input level (uses the default recording device)
# you can use 'deej.unmapped' to control all apps that aren't bound to any slider (this ignores master, system, mic and device-targeting sessions) (experimental)
# windows only - you can use 'deej.current' to control the currently active app (whether full-screen or not) (experimental)
# windows only - you can use a device's full name, i.e. "Speakers (Realtek High Definition Audio)", to bind it. this works for both output and input devices
# windows only - you can use 'system' to control the "system sounds" volume
# important: slider indexes start at 0, regardless of which analog pins you're using!
''';

class DeejConfigIO {
  static DeejConfig loadFromFile(String path) {
    final text = File(path).readAsStringSync();
    final doc = loadYaml(text);

    dynamic toJson(dynamic v) {
      if (v is YamlMap) return v.map((k, val) => MapEntry(k.toString(), toJson(val)));
      if (v is YamlList) return v.map((e) => toJson(e)).toList();
      return v;
    }

    final root = toJson(doc) as Map<String, dynamic>;

    final mappingRaw = (root['slider_mapping'] as Map?) ?? {};
    final mapping = <int, SliderTarget>{};
    mappingRaw.forEach((k, v) {
      final idx = int.tryParse(k.toString());
      if (idx != null) mapping[idx] = SliderTarget.fromYaml(v);
    });

    return DeejConfig(
      sliderMapping: mapping.isNotEmpty ? mapping : {0: SliderTarget.single('master')},
      invertSliders: (root['invert_sliders'] == true),
      comPort: (root['com_port'] ?? 'COM1').toString(),
      baudRate: int.tryParse((root['baud_rate'] ?? '9600').toString()) ?? 9600,
      noiseReduction: (root['noise_reduction'] ?? 'default').toString(),
    );
  }

  static void saveToFile(String path, DeejConfig cfg) {
    final yaml = buildYaml(cfg);
    File(path).writeAsStringSync(yaml);
  }

  static String buildYaml(DeejConfig cfg) {
    final b = StringBuffer();
    b.writeln(_headerComment.trimRight());
    b.writeln();

    b.writeln('slider_mapping:');
    final keys = cfg.sliderMapping.keys.toList()..sort();
    for (final k in keys) {
      final target = cfg.sliderMapping[k]!;
      if (!target.isGroup) {
        // single
        final v = target.single ?? '';
        if (v.isEmpty) {
          b.writeln('  $k:');
        } else {
          b.writeln('  $k: $v');
        }
      } else {
        b.writeln('  $k:');
        for (final item in target.group!) {
          b.writeln('    - $item');
        }
      }
    }

    b.writeln();
    b.writeln('invert_sliders: ${cfg.invertSliders ? 'true' : 'false'}');
    b.writeln();
    b.writeln('com_port: ${cfg.comPort}');
    b.writeln('baud_rate: ${cfg.baudRate}');
    b.writeln();
    b.writeln('noise_reduction: ${cfg.noiseReduction}');
    b.writeln();

    return b.toString();
  }
}
