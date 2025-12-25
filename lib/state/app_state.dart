import 'package:flutter/foundation.dart';
import 'package:file_picker/file_picker.dart';

import '../models/deej_config.dart';
import '../services/deej_config_io.dart';
import '../services/deej_folder_service.dart';
import '../services/windows_audio_service.dart';
import '../services/windows_com_service.dart';
import '../services/windows_deej_service.dart';
import '../services/windows_process_service.dart';

class AppState extends ChangeNotifier {
  final _comSvc = WindowsComService();
  final _procSvc = WindowsProcessService();
  final _audioSvc = WindowsAudioService();
  final _folderSvc = DeejFolderService();
  final _deejSvc = WindowsDeejService();

  // Deej klasör bilgileri
  String? deejFolderPath;
  String? deejExePath;
  String? configPath;

  DeejConfig cfg = DeejConfig.defaults();

  List<Map<String, String>> comPorts = [];
  List<String> runningExe = [];
  List<String> audioDevices = [];

  /// Icon için lazım:
  /// "chrome.exe" -> "C:\Program Files\Google\Chrome\Application\chrome.exe"
  Map<String, String> exePathByName = {};

  bool autoRestartAfterSave = true;

  // slider otomatik üretme
  int desiredSliderCount = 5; // default (0..4)
  String boardPreset = 'Custom'; // UNO/NANO, MEGA, Custom

  static const specialTargets = <String>[
    'master',
    'system',
    'mic',
    'deej.unmapped',
    'deej.current',
  ];

  Future<void> init() async {
    await refreshComPorts();
    await refreshRunningProcesses();
    await refreshAudioDevices();
  }

  // 1) Deej klasörü seç -> deej.exe + config.yaml aynı klasörde aranır
  Future<void> pickDeejFolderAndAutoFind() async {
    final dir = await FilePicker.platform.getDirectoryPath(
      dialogTitle: 'Deej klasörünü seç (deej.exe + config.yaml burada olmalı)',
    );
    if (dir == null) return;

    final res = await _folderSvc.scanFolder(dir);

    deejFolderPath = res.folderPath;
    deejExePath = res.deejExePath;
    configPath = res.configPath;

    // Config varsa yükle
    if (configPath != null) {
      cfg = DeejConfigIO.loadFromFile(configPath!);
      _syncDesiredCountFromConfig();
    } else {
      cfg = DeejConfig.defaults();
      _syncDesiredCountFromConfig();
    }

    notifyListeners();
  }

  // config yoksa aynı klasöre oluştur
  Future<void> createConfigInDeejFolder() async {
    if (deejFolderPath == null) return;
    final path = _folderSvc.defaultConfigPath(deejFolderPath!);
    configPath = path;
    DeejConfigIO.saveToFile(path, cfg);
    notifyListeners();
  }

  Future<void> saveConfig() async {
    // kural: config, deej.exe ile aynı klasörde olmalı
    if (deejFolderPath == null) return;

    if (configPath == null) {
      await createConfigInDeejFolder();
    } else {
      DeejConfigIO.saveToFile(configPath!, cfg);
    }

    if (autoRestartAfterSave && deejExePath != null) {
      await restartDeej();
    }
  }

  Future<void> restartDeej() async {
    if (deejExePath == null || deejFolderPath == null) return;
    await _deejSvc.restartDeej(deejExePath!, workingDir: deejFolderPath);
  }

  Future<void> stopDeej() async {
    await _deejSvc.killDeej();
  }

  Future<void> refreshComPorts() async {
    comPorts = await _comSvc.listComPorts();
    notifyListeners();
  }

  void autoSelectArduinoCom() {
    final guess = _comSvc.guessArduinoCom(comPorts);
    if (guess != null) {
      cfg.comPort = guess;
      notifyListeners();
    }
  }

  /// ✅ Artık process name + full path alıyoruz (ikon için şart)
  Future<void> refreshRunningProcesses() async {
    final rows = await _procSvc.listRunningExeWithPath();

    // isim listesi (slider editör vs. kullanıyor)
    runningExe = rows
        .map((r) => (r['name'] ?? '').trim())
        .where((n) => n.isNotEmpty)
        .toList();

    // ikon için path map
    exePathByName = {};
    for (final r in rows) {
      final name = (r['name'] ?? '').trim();
      final path = (r['path'] ?? '').trim();
      if (name.isNotEmpty && path.isNotEmpty) {
        exePathByName[name] = path;
      }
    }

    notifyListeners();
  }


  Future<void> refreshAudioDevices() async {
    audioDevices = await _audioSvc.listAudioEndpoints();
    notifyListeners();
  }

  void setComPort(String v) {
    cfg.comPort = v;
    notifyListeners();
  }

  void setBaudRate(int v) {
    cfg.baudRate = v;
    notifyListeners();
  }

  void setInvert(bool v) {
    cfg.invertSliders = v;
    notifyListeners();
  }

  void setNoiseReduction(String v) {
    cfg.noiseReduction = v;
    notifyListeners();
  }

  void setAutoRestart(bool v) {
    autoRestartAfterSave = v;
    notifyListeners();
  }

  void upsertSlider(int idx, SliderTarget target) {
    cfg.sliderMapping[idx] = target;
    notifyListeners();
  }

  void removeSlider(int idx) {
    cfg.sliderMapping.remove(idx);
    _syncDesiredCountFromConfig();
    notifyListeners();
  }

  void addNextSlider() {
    final keys = cfg.sliderMapping.keys.toList();
    final next = keys.isEmpty ? 0 : (keys.reduce((a, b) => a > b ? a : b) + 1);
    cfg.sliderMapping[next] = SliderTarget.single('');
    _syncDesiredCountFromConfig();
    notifyListeners();
  }

  // -------- Slider count otomasyonu --------

  void setBoardPreset(String preset) {
    boardPreset = preset;
    if (preset == 'UNO/NANO (6)') desiredSliderCount = 6;
    if (preset == 'MEGA (16)') desiredSliderCount = 16;
    if (preset == 'Custom') {
      _syncDesiredCountFromConfig();
    }
    ensureSliderCount(desiredSliderCount);
    notifyListeners();
  }

  void setDesiredSliderCount(int count) {
    desiredSliderCount = count.clamp(1, 64);
    ensureSliderCount(desiredSliderCount);
    notifyListeners();
  }

  void ensureSliderCount(int count) {
    // 0..count-1 garanti olsun; mevcut atamaları koru
    for (int i = 0; i < count; i++) {
      cfg.sliderMapping.putIfAbsent(i, () => SliderTarget.single(''));
    }
    // count üstünü sil
    final toRemove = cfg.sliderMapping.keys.where((k) => k >= count).toList();
    for (final k in toRemove) {
      cfg.sliderMapping.remove(k);
    }
  }

  void _syncDesiredCountFromConfig() {
    if (cfg.sliderMapping.isEmpty) {
      desiredSliderCount = 1;
      return;
    }
    final maxKey = cfg.sliderMapping.keys.reduce((a, b) => a > b ? a : b);
    desiredSliderCount = maxKey + 1;
  }
}
