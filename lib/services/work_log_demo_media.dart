import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// 工作留痕演示附件（照片用内置素材，音视频本地生成）。
abstract final class WorkLogDemoMedia {
  /// 可见的演示照片（复用 App 内素材）
  static Future<Uint8List> photoBytes() async {
    try {
      final data = await rootBundle.load('assets/mascots/paddi1.png');
      return data.buffer.asUint8List();
    } catch (_) {
      return base64Decode(
        'iVBORw0KGgoAAAANSUhEUgAAAAoAAAAKCAYAAACNMs+9AAAAFUlEQVR42mNk+M9Qz0AEYBxVSF+FABJADveWkH6oAAAAAElFTkSuQmCC',
      );
    }
  }

  /// 约 0.2 秒静音 WAV（可被系统播放器打开）
  static Uint8List audioBytes() {
    const sampleRate = 8000;
    const numSamples = 1600; // 0.2s
    final dataSize = numSamples * 2;
    final bytes = BytesBuilder();
    void u16(int v) {
      bytes.add([v & 0xff, (v >> 8) & 0xff]);
    }

    void u32(int v) {
      bytes.add([v & 0xff, (v >> 8) & 0xff, (v >> 16) & 0xff, (v >> 24) & 0xff]);
    }

    bytes.add(ascii.encode('RIFF'));
    u32(36 + dataSize);
    bytes.add(ascii.encode('WAVE'));
    bytes.add(ascii.encode('fmt '));
    u32(16); // PCM chunk
    u16(1); // PCM
    u16(1); // mono
    u32(sampleRate);
    u32(sampleRate * 2);
    u16(2); // block align
    u16(16); // bits
    bytes.add(ascii.encode('data'));
    u32(dataSize);
    bytes.add(Uint8List(dataSize)); // silence
    return bytes.toBytes();
  }

  static Future<File> writeTemp({
    required String fileName,
    required Uint8List bytes,
  }) async {
    final dir = await getTemporaryDirectory();
    final file = File(p.join(dir.path, 'work_log_demo', fileName));
    await file.parent.create(recursive: true);
    await file.writeAsBytes(bytes, flush: true);
    return file;
  }
}
