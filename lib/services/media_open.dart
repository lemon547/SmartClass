import 'dart:io';

import 'package:flutter/services.dart';
import 'package:open_filex/open_filex.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:smart_class/services/file_share.dart';

/// 打开 / 分享本地附件。分享走 ACTION_SEND，可选到微信。
abstract final class MediaOpen {
  static const _channel = MethodChannel('smart_class/media_open');

  static String mimeForPath(String path) {
    return switch (p.extension(path).toLowerCase()) {
      '.jpg' || '.jpeg' => 'image/jpeg',
      '.png' => 'image/png',
      '.gif' => 'image/gif',
      '.webp' => 'image/webp',
      '.bmp' => 'image/bmp',
      '.heic' => 'image/heic',
      '.mp3' => 'audio/mpeg',
      '.m4a' || '.aac' => 'audio/mp4',
      '.wav' => 'audio/wav',
      '.ogg' => 'audio/ogg',
      '.amr' => 'audio/amr',
      '.flac' => 'audio/flac',
      '.mp4' || '.m4v' => 'video/mp4',
      '.mov' => 'video/quicktime',
      '.3gp' => 'video/3gpp',
      '.webm' => 'video/webm',
      '.mkv' => 'video/x-matroska',
      '.avi' => 'video/x-msvideo',
      '.pdf' => 'application/pdf',
      '.doc' => 'application/msword',
      '.docx' =>
        'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
      '.xls' => 'application/vnd.ms-excel',
      '.xlsx' =>
        'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
      '.ppt' => 'application/vnd.ms-powerpoint',
      '.pptx' =>
        'application/vnd.openxmlformats-officedocument.presentationml.presentation',
      '.txt' => 'text/plain',
      '.zip' => 'application/zip',
      _ => 'application/octet-stream',
    };
  }

  static Future<String> _copyForExport(String sourcePath) async {
    final src = File(sourcePath);
    if (!await src.exists()) {
      throw StateError('文件不存在');
    }
    final ext = p.extension(sourcePath);
    final dir = await getTemporaryDirectory();
    final openPath = p.join(
      dir.path,
      'share_${DateTime.now().millisecondsSinceEpoch}$ext',
    );
    await src.copy(openPath);
    return openPath;
  }

  /// 用系统播放器/阅读器打开（不一定含微信）。
  static Future<void> open(String sourcePath, {String? mime}) async {
    final openPath = await _copyForExport(sourcePath);
    final type = mime ?? mimeForPath(openPath);

    if (Platform.isAndroid) {
      try {
        await _channel.invokeMethod<bool>('openWithChooser', {
          'path': openPath,
          'mime': type,
        });
        return;
      } on PlatformException {
        // fall through
      }
    }

    final res = await OpenFilex.open(openPath, type: type);
    if (res.type != ResultType.done) {
      throw StateError(res.message.isEmpty ? '无法打开文件' : res.message);
    }
  }

  /// 系统分享面板（含微信 / QQ 等）。
  static Future<void> share(
    String sourcePath, {
    String? mime,
    String? subject,
    String? text,
  }) async {
    final sharePath = await _copyForExport(sourcePath);
    final type = mime ?? mimeForPath(sharePath);

    if (Platform.isAndroid) {
      try {
        await _channel.invokeMethod<bool>('shareWithChooser', {
          'path': sharePath,
          'mime': type,
          'title': subject ?? '分享文件',
        });
        return;
      } on PlatformException {
        // fall through to share_plus
      }
    }

    await FileShare.shareFile(
      filePath: sharePath,
      mimeType: type,
      subject: subject,
      text: text,
    );
  }
}
