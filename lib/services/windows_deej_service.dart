import 'dart:io';

class WindowsDeejService {
  Future<void> killDeej() async {
    // Çalışmıyorsa da sorun değil.
    await Process.run('taskkill', ['/IM', 'deej.exe', '/F']);
  }

  Future<void> startDeej(String deejExePath, {String? workingDir}) async {
    await Process.start(
      deejExePath,
      const [],
      workingDirectory: workingDir,
      runInShell: true,
    );
  }

  Future<void> restartDeej(String deejExePath, {String? workingDir}) async {
    await killDeej();
    await Future.delayed(const Duration(milliseconds: 250));
    await startDeej(deejExePath, workingDir: workingDir);
  }
}
