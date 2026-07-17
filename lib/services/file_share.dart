import 'package:path/path.dart' as p;
import 'package:share_plus/share_plus.dart';

/// 调起系统分享面板（微信、QQ、文件助手、保存到其他 App 等）
abstract final class FileShare {
  static Future<void> shareFile({
    required String filePath,
    String? mimeType,
    String? subject,
    String? text,
  }) async {
    await Share.shareXFiles(
      [XFile(filePath, mimeType: mimeType ?? mimeForPath(filePath))],
      subject: subject,
      text: text,
    );
  }

  static Future<void> shareXlsx({
    required String filePath,
    String? subject,
    String? text,
  }) async {
    await shareFile(
      filePath: filePath,
      mimeType: _xlsxMime,
      subject: subject,
      text: text,
    );
  }

  static String mimeForPath(String path) {
    return switch (p.extension(path).toLowerCase()) {
      '.xlsx' => _xlsxMime,
      '.xls' => 'application/vnd.ms-excel',
      '.csv' => 'text/csv',
      '.json' => 'application/json',
      _ => 'application/octet-stream',
    };
  }

  static const _xlsxMime =
      'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet';
}
