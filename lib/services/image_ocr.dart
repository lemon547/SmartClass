import 'dart:io';
import 'dart:typed_data';

import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:path_provider/path_provider.dart';

/// 端侧免费 OCR（Google ML Kit 中文），把照片里的文字抽成表格 TSV 再交给 AI。
abstract final class ImageOcr {
  /// 返回按位置聚类后的 TSV（行按 Y、列按 X），便于成绩表/名单照片。
  static Future<String> extractTableTsv(
    Uint8List bytes, {
    String? fileName,
  }) async {
    if (!Platform.isAndroid && !Platform.isIOS) {
      throw const FormatException('图片文字识别仅支持 Android / iOS 手机端');
    }
    if (bytes.isEmpty) {
      throw const FormatException('图片文件为空');
    }

    final dir = await getTemporaryDirectory();
    final ext = _guessExt(bytes, fileName);
    final file = File(
      '${dir.path}/ai_ocr_${DateTime.now().microsecondsSinceEpoch}$ext',
    );
    await file.writeAsBytes(bytes, flush: true);

    final recognizer = TextRecognizer(script: TextRecognitionScript.chinese);
    try {
      final input = InputImage.fromFilePath(file.path);
      final recognized = await recognizer.processImage(input);
      final tsv = _layoutToTsv(recognized);
      if (tsv.trim().isEmpty) {
        throw const FormatException(
          '未能从图片中识别到文字。请换更清晰、文字更大的照片后重试。',
        );
      }
      return tsv;
    } finally {
      await recognizer.close();
      try {
        await file.delete();
      } catch (_) {}
    }
  }

  static String _layoutToTsv(RecognizedText recognized) {
    final lines = <_OcrLine>[];
    for (final block in recognized.blocks) {
      for (final line in block.lines) {
        final text = line.text.trim();
        if (text.isEmpty) continue;
        final box = line.boundingBox;
        lines.add(
          _OcrLine(
            text: text,
            top: box.top.toDouble(),
            left: box.left.toDouble(),
            height: box.height.toDouble().clamp(8, 200),
          ),
        );
      }
    }
    if (lines.isEmpty) {
      // 兜底：整段文本按换行
      return recognized.text.trim();
    }

    lines.sort((a, b) {
      final dy = a.top.compareTo(b.top);
      return dy != 0 ? dy : a.left.compareTo(b.left);
    });

    final heights = [...lines.map((e) => e.height)]..sort();
    final medianH = heights[heights.length ~/ 2];
    final rowThreshold = (medianH * 0.65).clamp(10.0, 48.0);

    final rows = <List<_OcrLine>>[];
    for (final line in lines) {
      if (rows.isEmpty) {
        rows.add([line]);
        continue;
      }
      final current = rows.last;
      final refTop =
          current.map((e) => e.top).reduce((a, b) => a + b) / current.length;
      if ((line.top - refTop).abs() <= rowThreshold) {
        current.add(line);
      } else {
        rows.add([line]);
      }
    }

    final buf = StringBuffer();
    for (final row in rows) {
      row.sort((a, b) => a.left.compareTo(b.left));
      buf.writeln(row.map((e) => e.text.replaceAll('\t', ' ')).join('\t'));
    }
    return buf.toString().trim();
  }

  static String _guessExt(Uint8List bytes, String? fileName) {
    final lower = (fileName ?? '').toLowerCase();
    for (final e in ['.jpg', '.jpeg', '.png', '.webp', '.bmp', '.gif', '.heic']) {
      if (lower.endsWith(e)) return e == '.jpeg' ? '.jpg' : e;
    }
    if (bytes.length >= 3 &&
        bytes[0] == 0xFF &&
        bytes[1] == 0xD8 &&
        bytes[2] == 0xFF) {
      return '.jpg';
    }
    if (bytes.length >= 8 &&
        bytes[0] == 0x89 &&
        bytes[1] == 0x50 &&
        bytes[2] == 0x4E &&
        bytes[3] == 0x47) {
      return '.png';
    }
    if (bytes.length >= 12 &&
        bytes[0] == 0x52 &&
        bytes[1] == 0x49 &&
        bytes[2] == 0x46 &&
        bytes[3] == 0x46) {
      return '.webp';
    }
    if (bytes.length >= 2 && bytes[0] == 0x42 && bytes[1] == 0x4D) {
      return '.bmp';
    }
    if (bytes.length >= 4 &&
        bytes[0] == 0x47 &&
        bytes[1] == 0x49 &&
        bytes[2] == 0x46) {
      return '.gif';
    }
    return '.jpg';
  }
}

class _OcrLine {
  const _OcrLine({
    required this.text,
    required this.top,
    required this.left,
    required this.height,
  });

  final String text;
  final double top;
  final double left;
  final double height;
}
