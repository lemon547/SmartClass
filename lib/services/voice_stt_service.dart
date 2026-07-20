import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

/// 国内语音转写（硅基流动 SenseVoice，OpenAI 兼容；不依赖谷歌服务）
class VoiceSttService {
  VoiceSttService({
    required this.apiKey,
    http.Client? client,
  }) : _client = client ?? http.Client();

  static const baseUrl = 'https://api.siliconflow.cn/v1';
  static const model = 'FunAudioLLM/SenseVoiceSmall';

  final String apiKey;
  final http.Client _client;

  bool get hasKey => apiKey.trim().isNotEmpty;

  /// 将本地音频文件转成文字（支持 m4a / wav / mp3 等）
  Future<String> transcribeFile(String path) async {
    if (!hasKey) {
      throw const VoiceSttException(
        '未配置语音转写 Key。请到「我的 → AI 助手」填写硅基流动 API Key（国内免费额度，无需谷歌）。',
      );
    }
    final file = File(path);
    if (!await file.exists()) {
      throw const VoiceSttException('录音文件不存在');
    }
    final len = await file.length();
    if (len < 256) {
      throw const VoiceSttException('录音太短，请再说一会儿');
    }

    final uri = Uri.parse('$baseUrl/audio/transcriptions');
    final req = http.MultipartRequest('POST', uri)
      ..headers['Authorization'] = 'Bearer ${apiKey.trim()}'
      ..fields['model'] = model
      ..files.add(
        await http.MultipartFile.fromPath(
          'file',
          path,
          filename: file.uri.pathSegments.last,
        ),
      );

    final streamed = await _client.send(req).timeout(const Duration(seconds: 60));
    final body = await streamed.stream.bytesToString();
    if (streamed.statusCode < 200 || streamed.statusCode >= 300) {
      throw VoiceSttException(_friendlyError(streamed.statusCode, body));
    }

    final data = jsonDecode(body);
    if (data is! Map) {
      throw const VoiceSttException('转写返回格式异常');
    }
    final text = (data['text'] ?? '').toString().trim();
    if (text.isEmpty) {
      throw const VoiceSttException('未识别到内容，请再说一次');
    }
    return text;
  }

  static String _friendlyError(int code, String body) {
    final lower = body.toLowerCase();
    if (code == 401 || lower.contains('unauthorized') || lower.contains('invalid')) {
      return '语音 Key 无效。请到硅基流动开放平台创建 Key（国内可用），填到「AI 助手 → 语音转写 Key」。';
    }
    if (code == 429) {
      return '语音转写次数过多，请稍后再试';
    }
    if (code >= 500) {
      return '语音服务暂时不可用，请稍后再试';
    }
    return '语音转写失败（$code）';
  }
}

class VoiceSttException implements Exception {
  const VoiceSttException(this.message);
  final String message;

  @override
  String toString() => message;
}
