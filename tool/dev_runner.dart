// SmartClass 开发助手：flutter run + 保存 lib/ 后自动热重启（Windows 可用）
//
// 用法：dart tool/dev_runner.dart
// 或通过 scripts/dev-run.ps1 启动（已配置环境变量）

import 'dart:async';
import 'dart:convert';
import 'dart:io';

Future<void> main(List<String> args) async {
  final flutter = _flutterExecutable();
  final runArgs = ['run', ...args];

  stdout.writeln('[SmartClass] flutter ${runArgs.join(' ')}');
  stdout.writeln('[SmartClass] Watching lib/ — save any .dart file to hot restart (R)');

  final process = await Process.start(
    flutter,
    runArgs,
    workingDirectory: Directory.current.path,
    mode: ProcessStartMode.normal,
  );

  process.stdout.transform(utf8.decoder).listen(stdout.write);
  process.stderr.transform(utf8.decoder).listen(stderr.write);

  Timer? debounce;
  final sub = Directory('lib').watch(recursive: true).listen((event) {
    if (event.type == FileSystemEvent.delete) return;
    if (!event.path.endsWith('.dart')) return;
    debounce?.cancel();
    debounce = Timer(const Duration(milliseconds: 900), () {
      final name = event.path.replaceAll(r'\', '/').split('/').last;
      stdout.writeln('\n[SmartClass] $name changed → sending hot restart (R)');
      try {
        process.stdin.writeln('R');
      } on Object catch (e) {
        stderr.writeln('[SmartClass] hot restart failed: $e');
      }
    });
  });

  ProcessSignal.sigint.watch().listen((_) async {
    sub.cancel();
    debounce?.cancel();
    process.stdin.close();
    process.kill();
    exit(0);
  });

  exit(await process.exitCode);
}

String _flutterExecutable() {
  final root = Platform.environment['FLUTTER_ROOT'] ?? r'E:\dev\flutter';
  if (Platform.isWindows) {
    return '$root\\bin\\flutter.bat';
  }
  return '$root/bin/flutter';
}
