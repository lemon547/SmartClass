import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:smart_class/services/share_inbox.dart';
import 'package:smart_class/theme/app_icons.dart';
import 'package:smart_class/theme/app_theme.dart';

/// AI 导入选中的文件（本机或微信分享）。
class AiImportFile {
  const AiImportFile({required this.bytes, required this.fileName});

  final Uint8List bytes;
  final String fileName;
}

/// 本机任意文件 + 微信「用其他应用打开」导入（与留痕一致）。
mixin AiImportFileSourceMixin<T extends StatefulWidget> on State<T> {
  StreamSubscription<SharedFileItem>? _aiShareSub;
  bool _awaitingWeChatShare = false;

  bool get awaitingWeChatShare => _awaitingWeChatShare;

  /// 子类实现：拿到文件后解析。
  Future<void> onAiImportFile(AiImportFile file);

  @protected
  void initAiImportFileSource() {
    unawaited(ShareInbox.ensureStarted());
    _aiShareSub = ShareInbox.subscribe(_onSharedForAiImport);
  }

  @protected
  void disposeAiImportFileSource() {
    _aiShareSub?.cancel();
    _aiShareSub = null;
  }

  void _onSharedForAiImport(SharedFileItem item) {
    if (!_awaitingWeChatShare || !mounted) return;
    setState(() => _awaitingWeChatShare = false);
    unawaited(_loadSharedPath(item));
  }

  Future<void> _loadSharedPath(SharedFileItem item) async {
    try {
      final bytes = await File(item.path).readAsBytes();
      if (!mounted) return;
      await onAiImportFile(
        AiImportFile(
          bytes: Uint8List.fromList(bytes),
          fileName: item.name,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('读取微信文件失败：$e')),
      );
    }
  }

  Future<void> pickAiImportLocalFile() async {
    final picked = await FilePicker.pickFiles(
      type: FileType.any,
      withData: true,
    );
    if (picked == null || picked.files.isEmpty || !mounted) return;

    final file = picked.files.single;
    var bytes = file.bytes;
    if (bytes == null && file.path != null) {
      bytes = await File(file.path!).readAsBytes();
    }
    if (!mounted) return;
    if (bytes == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('无法读取文件')),
      );
      return;
    }
    await onAiImportFile(
      AiImportFile(
        bytes: Uint8List.fromList(bytes),
        fileName: file.name,
      ),
    );
  }

  Future<void> importAiFileFromWeChat({
    required String fileKindLabel,
  }) async {
    await ShareInbox.ensureStarted();
    if (!mounted) return;

    final go = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('从微信导入'),
        content: Text(
          '请按以下步骤完成导入：\n\n'
          '1. 在微信中打开需要导入的$fileKindLabel\n'
          '2. 轻点右上角「···」，选择「用其他应用打开」或「分享」\n'
          '3. 在应用列表中选择「班主任助手」\n\n'
          '导入成功后将自动开始 AI 识别。',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('前往微信'),
          ),
        ],
      ),
    );
    if (go != true || !mounted) return;

    setState(() => _awaitingWeChatShare = true);
    final opened = await ShareInbox.openWeChat();
    if (!mounted) return;
    if (!opened) {
      setState(() => _awaitingWeChatShare = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('未安装微信，请安装后重试')),
      );
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('请在微信中选择用「班主任助手」打开$fileKindLabel'),
        duration: const Duration(seconds: 4),
      ),
    );
  }

  void cancelAwaitingWeChatShare() {
    if (!_awaitingWeChatShare) return;
    setState(() => _awaitingWeChatShare = false);
  }
}

/// AI 导入页：本机选文件 / 从微信导入。
class AiImportSourcePanel extends StatelessWidget {
  const AiImportSourcePanel({
    super.key,
    required this.busy,
    required this.awaitingWeChat,
    required this.onPickLocal,
    required this.onImportWeChat,
    required this.onCancelWeChat,
    this.hint =
        '微信/本机均可：表格、Word、TXT，或照片/截图（本地免费 OCR 抽字后再给 AI）。',
    this.localLabel = '本机选文件',
    this.wechatLabel = '从微信导入',
  });

  final bool busy;
  final bool awaitingWeChat;
  final VoidCallback onPickLocal;
  final VoidCallback onImportWeChat;
  final VoidCallback onCancelWeChat;
  final String hint;
  final String localLabel;
  final String wechatLabel;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          hint,
          style: TextStyle(
            fontSize: 14,
            height: 1.4,
            color: AppTheme.secondaryLabel,
          ),
        ),
        if (awaitingWeChat) ...[
          const SizedBox(height: 12),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: AppTheme.blue.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              children: [
                Icon(AppIcons.message, size: 18, color: AppTheme.blue),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '正在等待从微信导入。请在微信中选择用「班主任助手」打开。',
                    style: TextStyle(fontSize: 13, color: AppTheme.label),
                  ),
                ),
                TextButton(
                  onPressed: busy ? null : onCancelWeChat,
                  child: const Text('取消'),
                ),
              ],
            ),
          ),
        ],
        const SizedBox(height: 16),
        if (busy)
          FilledButton.icon(
            onPressed: null,
            icon: const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: Colors.white,
              ),
            ),
            label: const Text('AI 识别中…'),
          )
        else
          Row(
            children: [
              Expanded(
                child: _SourceCard(
                  icon: AppIcons.folder,
                  label: localLabel,
                  subtitle: '含照片截图',
                  onTap: onPickLocal,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _SourceCard(
                  icon: AppIcons.message,
                  label: wechatLabel,
                  subtitle: '文件或图片',
                  onTap: onImportWeChat,
                ),
              ),
            ],
          ),
      ],
    );
  }
}

class _SourceCard extends StatelessWidget {
  const _SourceCard({
    required this.icon,
    required this.label,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppTheme.surface,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, size: 22, color: AppTheme.blue),
              const SizedBox(height: 10),
              Text(
                label,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: TextStyle(
                  fontSize: 12,
                  color: AppTheme.tertiaryLabel,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
