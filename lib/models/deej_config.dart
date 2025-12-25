class SliderTarget {
  final String? single; // e.g. "master" or "chrome.exe"
  final List<String>? group; // e.g. ["WhatsApp.Root.exe", "msedgewebview2.exe"]

  const SliderTarget._({this.single, this.group});

  factory SliderTarget.single(String v) => SliderTarget._(single: v);
  factory SliderTarget.group(List<String> v) => SliderTarget._(group: List.unmodifiable(v));

  bool get isGroup => group != null;
  String summary() {
    if (group != null) return group!.join(', ');
    return single ?? '';
  }

  dynamic toYamlValue() {
    if (group != null) return group;
    return (single ?? '');
  }

  static SliderTarget fromYaml(dynamic v) {
    if (v is List) {
      return SliderTarget.group(v.map((e) => e.toString()).where((s) => s.trim().isNotEmpty).toList());
    }
    if (v == null) return SliderTarget.single('');
    return SliderTarget.single(v.toString());
  }
}

class DeejConfig {
  final Map<int, SliderTarget> sliderMapping;
  bool invertSliders;
  String comPort;
  int baudRate;
  String noiseReduction;

  DeejConfig({
    required this.sliderMapping,
    required this.invertSliders,
    required this.comPort,
    required this.baudRate,
    required this.noiseReduction,
  });

  factory DeejConfig.defaults() => DeejConfig(
    sliderMapping: {0: SliderTarget.single('master')},
    invertSliders: false,
    comPort: 'COM1',
    baudRate: 9600,
    noiseReduction: 'default',
  );
}
