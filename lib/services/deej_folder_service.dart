import 'dart:io';
import 'package:path/path.dart' as p;

class DeejFolderResult {
  final String folderPath;
  final String? deejExePath;
  final String? configPath;

  const DeejFolderResult({
    required this.folderPath,
    required this.deejExePath,
    required this.configPath,
  });

  bool get hasExe => deejExePath != null;
  bool get hasConfig => configPath != null;
  bool get ready => hasExe && hasConfig;
}

class DeejFolderService {
  Future<DeejFolderResult> scanFolder(String folderPath) async {
    final dir = Directory(folderPath);
    if (!await dir.exists()) {
      return DeejFolderResult(folderPath: folderPath, deejExePath: null, configPath: null);
    }

    String? exe;
    String? cfg;

    await for (final ent in dir.list(recursive: false, followLinks: false)) {
      if (ent is! File) continue;
      final name = p.basename(ent.path).toLowerCase();

      if (name == 'deej.exe') exe = ent.path;
      if (name == 'config.yaml' || name == 'config.yml') cfg = ent.path;
    }

    return DeejFolderResult(folderPath: folderPath, deejExePath: exe, configPath: cfg);
  }

  String defaultConfigPath(String folderPath) => p.join(folderPath, 'config.yaml');
}
