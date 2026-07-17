import 'package:share_plus/share_plus.dart';

/// 调起系统分享（可选微信、QQ、文件助手等）
abstract final class FileShare {
  static Future<void> shareXlsx({
    required String filePath,
    String? subject,
    String? text,
  }) async {
    await Share.shareXFiles(
      [XFile(filePath, mimeType: _xlsxMime)],
      subject: subject,
      text: text,
    );
  }

  static const _xlsxMime =
      'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet';
}
