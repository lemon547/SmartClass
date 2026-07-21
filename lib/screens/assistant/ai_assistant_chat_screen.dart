import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:smart_class/providers/ai_settings_controller.dart';
import 'package:smart_class/providers/class_controller.dart';
import 'package:smart_class/screens/assistant/ai_action_confirm_screen.dart';
import 'package:smart_class/screens/more/ai_settings_screen.dart';
import 'package:smart_class/services/ai_action_proposal.dart';
import 'package:smart_class/services/ai_chat_history_store.dart';
import 'package:smart_class/services/ai_class_context.dart';
import 'package:smart_class/services/deepseek_ai_service.dart';
import 'package:smart_class/services/image_ocr.dart';
import 'package:smart_class/theme/app_icons.dart';
import 'package:smart_class/theme/app_theme.dart';
import 'package:smart_class/theme/mascot_assets.dart';
import 'package:smart_class/widgets/app_toast.dart';
import 'package:smart_class/widgets/apple_widgets.dart';

/// 班级 AI 助手：固定「Smart Class 助手」身份；可按当前班 / 多班 / 全部查数据。
class AiAssistantChatScreen extends StatefulWidget {
  const AiAssistantChatScreen({super.key});

  @override
  State<AiAssistantChatScreen> createState() => _AiAssistantChatScreenState();
}

enum _AiClassScopeMode { current, custom, all }

class _PendingAttach {
  const _PendingAttach({
    required this.name,
    required this.bytes,
    required this.isImage,
    this.previewPath,
  });

  final String name;
  final Uint8List bytes;
  final bool isImage;
  final String? previewPath;
}

class _AiAssistantChatScreenState extends State<AiAssistantChatScreen> {
  static const _maxAttach = 6;
  static const _maxTextChars = 24000;

  static AiChatMessage _welcome() => AiChatMessage(
        role: 'assistant',
        text: MascotAssets.assistant.welcomeText(),
        at: DateTime.fromMillisecondsSinceEpoch(0),
      );

  final _input = TextEditingController();
  final _scroll = ScrollController();
  final _messages = <AiChatMessage>[];
  final _pending = <_PendingAttach>[];
  bool _busy = false;
  bool _loadingHistory = true;
  bool _loadingSnap = true;
  String _classId = '';

  _AiClassScopeMode _scopeMode = _AiClassScopeMode.current;
  final Set<String> _customClassIds = {};

  static const _chips = [
    '这周课表',
    '今天有哪些课',
    '整理今天待办',
    '设计加减分规则',
    '积分最高的学生',
    '分析最近考试',
  ];

  List<String>? _scopeClassIds(ClassController ctrl) {
    switch (_scopeMode) {
      case _AiClassScopeMode.current:
        final id = ctrl.currentClass?.id;
        return id == null || id.isEmpty ? null : [id];
      case _AiClassScopeMode.all:
        return [for (final c in ctrl.classes) c.id];
      case _AiClassScopeMode.custom:
        if (_customClassIds.isEmpty) {
          final id = ctrl.currentClass?.id;
          return id == null || id.isEmpty ? null : [id];
        }
        return _customClassIds.toList();
    }
  }

  String _scopeLabel(ClassController ctrl) {
    switch (_scopeMode) {
      case _AiClassScopeMode.current:
        return ctrl.currentClass?.displayTitle ?? '未选班级';
      case _AiClassScopeMode.all:
        return '全部 ${ctrl.classes.length} 个班';
      case _AiClassScopeMode.custom:
        final n = _customClassIds.isEmpty ? 1 : _customClassIds.length;
        return '已选 $n 个班';
    }
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await _loadHistory();
      await _prepareSnapshot();
    });
  }

  @override
  void dispose() {
    _input.dispose();
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _loadHistory() async {
    final ctrl = context.read<ClassController>();
    _classId = ctrl.currentClass?.id ?? '';
    setState(() => _loadingHistory = true);
    final saved = await AiChatHistoryStore.load(_classId);
    if (!mounted) return;
    setState(() {
      _messages
        ..clear()
        ..addAll(saved.isEmpty ? [_welcome()] : saved);
      if (_messages.isNotEmpty &&
          _messages.first.role == 'assistant' &&
          (_messages.first.at.millisecondsSinceEpoch == 0 ||
              (_messages.length == 1 &&
                  _messages.first.text.startsWith('你好，我是')))) {
        _messages[0] = _welcome();
      }
      _loadingHistory = false;
    });
    _scrollToEnd(jump: true);
  }

  Future<void> _persist() async {
    if (_classId.isEmpty) return;
    // 不把纯欢迎语单独占满；有真实对话则全量保存（含欢迎语也可）
    await AiChatHistoryStore.save(_classId, _messages);
  }

  Future<void> _clearHistory() async {
    final ok = await showCupertinoDialog<bool>(
      context: context,
      builder: (ctx) => CupertinoAlertDialog(
        title: const Text('清空聊天记录？'),
        content: const Text('仅清除本班与助手的对话，不影响学生成绩等数据。'),
        actions: [
          CupertinoDialogAction(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('取消'),
          ),
          CupertinoDialogAction(
            isDestructiveAction: true,
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('清空'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    await AiChatHistoryStore.clear(_classId);
    if (!mounted) return;
    setState(() {
      _messages
        ..clear()
        ..add(_welcome());
    });
  }

  Future<void> _pickCustomClasses() async {
    final ctrl = context.read<ClassController>();
    final draft = Set<String>.from(_customClassIds);
    if (draft.isEmpty) {
      final cur = ctrl.currentClass?.id;
      if (cur != null) draft.add(cur);
    }
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setLocal) {
            return AlertDialog(
              title: const Text('选择要查询的班级'),
              content: SizedBox(
                width: double.maxFinite,
                child: ListView(
                  shrinkWrap: true,
                  children: [
                    for (final c in ctrl.classes)
                      CheckboxListTile(
                        dense: true,
                        value: draft.contains(c.id),
                        title: Text(c.displayTitle),
                        onChanged: (v) {
                          setLocal(() {
                            if (v == true) {
                              draft.add(c.id);
                            } else {
                              draft.remove(c.id);
                            }
                          });
                        },
                      ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx, false),
                  child: const Text('取消'),
                ),
                TextButton(
                  onPressed:
                      draft.isEmpty ? null : () => Navigator.pop(ctx, true),
                  child: const Text('确定'),
                ),
              ],
            );
          },
        );
      },
    );
    if (ok != true || !mounted) return;
    setState(() {
      _scopeMode = _AiClassScopeMode.custom;
      _customClassIds
        ..clear()
        ..addAll(draft);
    });
  }

  Future<void> _prepareSnapshot({bool notify = false}) async {
    setState(() => _loadingSnap = true);
    try {
      final ctrl = context.read<ClassController>();
      await ctrl.ensureAllExamScores();
      if (!mounted) return;
      setState(() => _loadingSnap = false);
      if (notify) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('班级数据已刷新，可继续提问')),
        );
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _loadingSnap = false);
      if (notify) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('刷新失败：$e')),
        );
      }
    }
  }

  Future<void> _ensureKey() async {
    final ai = context.read<AiSettingsController>();
    if (ai.hasApiKey) return;
    final go = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('尚未配置 AI'),
        content: const Text('提问需要 DeepSeek API Key。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('去配置'),
          ),
        ],
      ),
    );
    if (go == true && mounted) {
      await Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const AiSettingsScreen()),
      );
    }
  }

  Future<void> _send([String? preset]) async {
    final typed = (preset ?? _input.text).trim();
    final attaches = List<_PendingAttach>.from(_pending);
    if ((typed.isEmpty && attaches.isEmpty) || _busy) return;

    await _ensureKey();
    if (!mounted) return;
    final ai = context.read<AiSettingsController>();
    if (!ai.hasApiKey) return;
    final ctrl = context.read<ClassController>();
    final scopeIds = _scopeClassIds(ctrl);

    // 快捷 chip 不带附件；手动发送才消费 pending
    final useAttach = preset == null ? attaches : const <_PendingAttach>[];

    setState(() {
      if (preset == null) {
        _input.clear();
        _pending.clear();
      }
      _busy = true;
    });

    final displayText = typed.isEmpty
        ? useAttach.map((e) => '📎 ${e.name}').join('\n')
        : useAttach.isEmpty
            ? typed
            : '$typed\n${useAttach.map((e) => '📎 ${e.name}').join('\n')}';

    var question = typed;
    if (useAttach.isNotEmpty) {
      final buf = StringBuffer();
      if (typed.isNotEmpty) buf.writeln(typed);
      for (final a in useAttach) {
        final extracted = await _extractAttach(a);
        buf.writeln();
        buf.writeln('===== 附件：${a.name} =====');
        buf.writeln(
          extracted.isEmpty
              ? '（未能提取文字内容，请结合文件名理解用户意图）'
              : extracted,
        );
      }
      question = buf.toString().trim();
      if (question.length > _maxTextChars) {
        question = '${question.substring(0, _maxTextChars)}\n…（附件内容过长已截断）';
      }
    }

    if (!mounted) return;
    setState(() {
      _messages.add(
        AiChatMessage(
          role: 'user',
          text: displayText,
          at: DateTime.now(),
          attachmentLabels: [for (final a in useAttach) a.name],
        ),
      );
    });
    await _persist();
    if (!mounted) return;
    _scrollToEnd();

    try {
      final needClass = DeepSeekAiService.looksLikeClassDataQuestion(question);
      String? snap;
      var loadedLabel = '';
      String? routeNotice;
      if (needClass) {
        // Skill 式：目录 → 选型；解析失败重试一次；仍失败则降级（不瞎塞关键词包）
        final catalog = await AiClassContext.buildCatalog(
          ctrl,
          scopeClassIds: scopeIds,
        );
        final router = ai.createService(maxTokens: 120);
        var routed = await router.selectClassDataPacks(
          question: question,
          catalog: catalog,
        );
        if (!routed.parsed) {
          routed = await router.selectClassDataPacks(
            question: question,
            catalog: catalog,
          );
        }
        if (!routed.parsed) {
          routeNotice = '数据包选型未能解析，未加载班级表';
        } else if (routed.selection.isEmpty) {
          // 合法空包：Agent 认为不需要本班表，信任结果
          routeNotice = null;
        } else {
          final selection = AiClassContext.resolveExamIdStrict(
            ctrl,
            routed.selection,
          );
          snap = await AiClassContext.loadPacks(
            ctrl,
            selection,
            scopeClassIds: scopeIds,
          );
          loadedLabel = selection.shortLabels;
          if (routed.selection.packs.contains(AiDataPackId.examBrief) &&
              !selection.packs.contains(AiDataPackId.examBrief)) {
            routeNotice = '未能定位指定考试，已改用成绩摘要';
          }
        }
      }
      final history = <Map<String, String>>[];
      for (var i = 0; i < _messages.length - 1; i++) {
        final m = _messages[i];
        // 跳过占位欢迎语
        if (i == 0 &&
            m.role == 'assistant' &&
            m.at.millisecondsSinceEpoch == 0) {
          continue;
        }
        var content = m.text;
        // 多轮改草稿：把上一轮未确认提案塞进上下文（仍未写入）
        final draft = m.proposal;
        if (draft != null) {
          content =
              '$content\n（系统：上一轮待确认草稿 ${draft.toJson()}，尚未写入；用户可要求修改草稿）';
        }
        history.add({'role': m.role, 'content': content});
      }
      // 少带历史，省钱又够连贯
      final trimmed = history.length > 8
          ? history.sublist(history.length - 8)
          : history;

      // 路由选型始终轻量；正式回答按问题难度自动决定是否深度
      final deep = DeepSeekAiService.looksLikeDeepQuestion(question) ||
          useAttach.isNotEmpty;
      final result = await ai.createService(forceThinking: deep).askSmartDetailed(
        question: question,
        history: trimmed,
        classDataSnapshot: snap,
        forceClassData: needClass && (snap?.isNotEmpty ?? false),
        assistantName: MascotAssets.assistantName,
        assistantPersona: MascotAssets.assistantPersona,
      );
      if (!mounted) return;
      final parsed = ParsedAiReply.parse(result.content);
      // 参考数据：实际加载了哪些本机数据包（+ 路由降级提示）
      final refs = <String>[];
      if (routeNotice != null && routeNotice.isNotEmpty) {
        refs.add(routeNotice);
      }
      if (loadedLabel.isNotEmpty) {
        refs.addAll(
          loadedLabel
              .split('、')
              .map((s) => s.trim())
              .where((s) => s.isNotEmpty),
        );
      }
      setState(() {
        _messages.add(
          AiChatMessage(
            role: 'assistant',
            text: parsed.displayText,
            at: DateTime.now(),
            proposal: parsed.proposal,
            thinking: result.reasoning,
            references: refs,
          ),
        );
      });
      await _persist();
    } on DeepSeekAiException catch (e) {
      if (!mounted) return;
      setState(() {
        _messages.add(
          AiChatMessage(
            role: 'assistant',
            text: '出错了：$e',
            at: DateTime.now(),
          ),
        );
      });
      await _persist();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _messages.add(
          AiChatMessage(
            role: 'assistant',
            text: '出错了：$e',
            at: DateTime.now(),
          ),
        );
      });
      await _persist();
    } finally {
      if (mounted) setState(() => _busy = false);
      _scrollToEnd();
    }
  }

  Future<String> _extractAttach(_PendingAttach a) async {
    if (a.isImage) {
      final ocr = await ImageOcr.extractPlainText(
        a.bytes,
        fileName: a.name,
      );
      return ocr.isEmpty ? '（图片未能识别出文字）' : ocr;
    }
    final lower = a.name.toLowerCase();
    if (_isTextLike(lower)) {
      var text = utf8.decode(a.bytes, allowMalformed: true).trim();
      if (text.length > _maxTextChars) {
        text = '${text.substring(0, _maxTextChars)}\n…（已截断）';
      }
      return text.isEmpty ? '（文件为空）' : text;
    }
    return '（暂不支持直接解析此格式，请改用截图、文本，或口头说明内容）';
  }

  static bool _isTextLike(String lower) {
    const exts = [
      '.txt',
      '.md',
      '.csv',
      '.tsv',
      '.json',
      '.log',
      '.html',
      '.htm',
      '.xml',
    ];
    for (final e in exts) {
      if (lower.endsWith(e)) return true;
    }
    return false;
  }

  static bool _isImageName(String name) {
    final lower = name.toLowerCase();
    for (final e in ['.jpg', '.jpeg', '.png', '.webp', '.gif', '.heic', '.bmp']) {
      if (lower.endsWith(e)) return true;
    }
    return false;
  }

  Future<void> _showAttachSheet() async {
    if (_busy) return;
    if (_pending.length >= _maxAttach) {
      AppToast.error(context, '最多附 $_maxAttach 个文件');
      return;
    }
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(8, 0, 8, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ListTile(
                  leading: Icon(AppIcons.camera, color: AppTheme.blue),
                  title: const Text('拍照'),
                  onTap: () {
                    Navigator.pop(ctx);
                    _pickImage(ImageSource.camera);
                  },
                ),
                ListTile(
                  leading: Icon(AppIcons.photo, color: AppTheme.blue),
                  title: const Text('相册'),
                  onTap: () {
                    Navigator.pop(ctx);
                    _pickImage(ImageSource.gallery);
                  },
                ),
                ListTile(
                  leading: Icon(AppIcons.file, color: AppTheme.blue),
                  title: const Text('文件'),
                  onTap: () {
                    Navigator.pop(ctx);
                    _pickFiles();
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _pickImage(ImageSource source) async {
    try {
      final x = await ImagePicker().pickImage(
        source: source,
        imageQuality: 85,
        maxWidth: 2048,
      );
      if (x == null || !mounted) return;
      final bytes = await x.readAsBytes();
      final path = x.path;
      _addPending(
        _PendingAttach(
          name: x.name.isNotEmpty ? x.name : '图片.jpg',
          bytes: Uint8List.fromList(bytes),
          isImage: true,
          previewPath: path,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      AppToast.error(context, '选图失败：$e');
    }
  }

  Future<void> _pickFiles() async {
    try {
      final result = await FilePicker.pickFiles(
        type: FileType.any,
        allowMultiple: true,
        withData: true,
      );
      if (result == null || result.files.isEmpty || !mounted) return;
      for (final f in result.files) {
        if (_pending.length >= _maxAttach) {
          if (mounted) AppToast.error(context, '最多附 $_maxAttach 个文件');
          break;
        }
        var bytes = f.bytes;
        if (bytes == null && f.path != null) {
          bytes = await File(f.path!).readAsBytes();
        }
        if (!mounted) return;
        if (bytes == null) continue;
        final name = f.name;
        final isImage = _isImageName(name);
        _addPending(
          _PendingAttach(
            name: name,
            bytes: Uint8List.fromList(bytes),
            isImage: isImage,
            previewPath: isImage ? f.path : null,
          ),
          notify: false,
        );
      }
      if (mounted) setState(() {});
    } catch (e) {
      if (!mounted) return;
      AppToast.error(context, '选文件失败：$e');
    }
  }

  void _addPending(_PendingAttach item, {bool notify = true}) {
    if (_pending.length >= _maxAttach) {
      AppToast.error(context, '最多附 $_maxAttach 个文件');
      return;
    }
    if (notify) {
      setState(() => _pending.add(item));
    } else {
      _pending.add(item);
    }
  }

  void _removePending(int index) {
    setState(() => _pending.removeAt(index));
  }

  Future<void> _openProposal(int messageIndex) async {
    if (messageIndex < 0 || messageIndex >= _messages.length) return;
    final m = _messages[messageIndex];
    final proposal = m.proposal;
    if (proposal == null) return;

    final result = await AiActionConfirmScreen.push(context, proposal);
    if (!mounted || result == null) return;

    setState(() {
      _messages[messageIndex] = m.copyWith(clearProposal: true);
      _messages.add(
        AiChatMessage(
          role: 'assistant',
          text: result,
          at: DateTime.now(),
        ),
      );
    });
    await _persist();
    _scrollToEnd();
  }

  void _scrollToEnd({bool jump = false}) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scroll.hasClients) return;
      final target = _scroll.position.maxScrollExtent + 80;
      if (jump) {
        _scroll.jumpTo(target.clamp(0, _scroll.position.maxScrollExtent));
      } else {
        _scroll.animateTo(
          target,
          duration: const Duration(milliseconds: 240),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final ctrl = context.watch<ClassController>();
    const mascot = MascotAssets.fab;
    final scopeTitle = _scopeLabel(ctrl);

    return Scaffold(
      backgroundColor: const Color(0xFFF4F6F9),
      appBar: PageAppBar(
        title: const Text(MascotAssets.assistantTitle),
        actions: [
          PopupMenuButton<String>(
            tooltip: '更多',
            enabled: !_busy,
            onSelected: (v) async {
              switch (v) {
                case 'refresh':
                  await _prepareSnapshot(notify: true);
                case 'clear':
                  await _clearHistory();
                case 'settings':
                  if (!mounted) return;
                  await Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const AiSettingsScreen()),
                  );
              }
            },
            itemBuilder: (_) => [
              const PopupMenuItem(value: 'refresh', child: Text('刷新班级数据')),
              const PopupMenuItem(value: 'clear', child: Text('清空聊天')),
              const PopupMenuItem(value: 'settings', child: Text('AI 设置')),
            ],
          ),
        ],
      ),
      body: Column(
        children: [
          SizedBox(
            height: 40,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
              itemCount: _chips.length,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (context, i) {
                final c = _chips[i];
                return ActionChip(
                  visualDensity: VisualDensity.compact,
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  label: Text(c, style: const TextStyle(fontSize: 12)),
                  backgroundColor: Colors.white,
                  side: BorderSide(color: AppTheme.separator),
                  onPressed: _busy ? null : () => _send(c),
                );
              },
            ),
          ),
          Expanded(
            child: _loadingHistory
                ? const Center(child: CircularProgressIndicator.adaptive())
                : ListView.builder(
                    controller: _scroll,
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
                    itemCount: _messages.length + (_busy ? 1 : 0),
                    itemBuilder: (context, i) {
                      if (_busy && i == _messages.length) {
                        return const _Bubble(
                          mine: false,
                          text: '正在查找…',
                          mascotAsset: mascot,
                          typing: true,
                        );
                      }
                      final m = _messages[i];
                      return _Bubble(
                        mine: m.role == 'user',
                        text: m.text,
                        mascotAsset: mascot,
                        attachmentLabels: m.attachmentLabels,
                        proposal: m.proposal,
                        thinking: m.thinking,
                        references: m.references,
                        onConfirmProposal: m.proposal == null
                            ? null
                            : () => _openProposal(i),
                      );
                    },
                  ),
          ),
          SafeArea(
            top: false,
            child: Container(
              padding: const EdgeInsets.fromLTRB(8, 6, 8, 10),
              decoration: BoxDecoration(
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 10,
                    offset: const Offset(0, -2),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (_pending.isNotEmpty)
                    SizedBox(
                      height: 72,
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        padding: const EdgeInsets.fromLTRB(4, 0, 4, 8),
                        itemCount: _pending.length,
                        separatorBuilder: (_, __) => const SizedBox(width: 8),
                        itemBuilder: (context, i) {
                          final a = _pending[i];
                          return _PendingChip(
                            attach: a,
                            onRemove: _busy ? null : () => _removePending(i),
                          );
                        },
                      ),
                    ),
                  // 豆包式：范围选择贴在输入框上方
                  Padding(
                    padding: const EdgeInsets.fromLTRB(8, 0, 8, 6),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: Material(
                        color: const Color(0xFFF4F6F9),
                        borderRadius: BorderRadius.circular(16),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(16),
                          onTap: _busy ? null : _showScopeSheet,
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(10, 6, 8, 6),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  AppIcons.users,
                                  size: 14,
                                  color: AppTheme.blue,
                                ),
                                const SizedBox(width: 6),
                                ConstrainedBox(
                                  constraints: BoxConstraints(
                                    maxWidth:
                                        MediaQuery.sizeOf(context).width * 0.62,
                                  ),
                                  child: Text(
                                    _loadingSnap ? '准备中…' : scopeTitle,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                      color: _loadingSnap
                                          ? AppTheme.tertiaryLabel
                                          : null,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 2),
                                Icon(
                                  Icons.keyboard_arrow_down_rounded,
                                  size: 18,
                                  color: AppTheme.tertiaryLabel,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      IconButton(
                        tooltip: '添加图片或文件',
                        onPressed: _busy ? null : _showAttachSheet,
                        style: IconButton.styleFrom(
                          foregroundColor: AppTheme.blue,
                          disabledForegroundColor:
                              AppTheme.blue.withValues(alpha: 0.35),
                        ),
                        icon: const Icon(Icons.add_circle_outline_rounded),
                      ),
                      Expanded(
                        child: TextField(
                          controller: _input,
                          minLines: 1,
                          maxLines: 4,
                          textInputAction: TextInputAction.send,
                          onSubmitted: (_) => _send(),
                          decoration: InputDecoration(
                            hintText: '发消息或上传图片、文件…',
                            filled: true,
                            fillColor: const Color(0xFFF4F6F9),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(22),
                              borderSide: BorderSide.none,
                            ),
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 12,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 4),
                      IconButton.filled(
                        onPressed: _busy ? null : () => _send(),
                        style: IconButton.styleFrom(
                          backgroundColor: AppTheme.blue,
                          foregroundColor: Colors.white,
                          disabledBackgroundColor:
                              AppTheme.blue.withValues(alpha: 0.35),
                        ),
                        icon: const Icon(Icons.send_rounded),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _showScopeSheet() async {
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(8, 0, 8, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
                  child: Text(
                    '查询范围',
                    style: Theme.of(ctx).textTheme.titleMedium,
                  ),
                ),
                ListTile(
                  leading: Icon(AppIcons.users, color: AppTheme.blue),
                  title: const Text('当前班'),
                  subtitle: Text(
                    context.read<ClassController>().currentClass?.displayTitle ??
                        '未选班级',
                  ),
                  trailing: _scopeMode == _AiClassScopeMode.current
                      ? Icon(Icons.check, color: AppTheme.blue)
                      : null,
                  onTap: () {
                    setState(() => _scopeMode = _AiClassScopeMode.current);
                    Navigator.pop(ctx);
                  },
                ),
                ListTile(
                  leading: Icon(AppIcons.grid, color: AppTheme.blue),
                  title: Text(
                    _customClassIds.isEmpty
                        ? '多选班级'
                        : '多选班级（已选 ${_customClassIds.length}）',
                  ),
                  subtitle: const Text('指定若干班级一起查'),
                  trailing: _scopeMode == _AiClassScopeMode.custom
                      ? Icon(Icons.check, color: AppTheme.blue)
                      : null,
                  onTap: () async {
                    Navigator.pop(ctx);
                    await _pickCustomClasses();
                  },
                ),
                ListTile(
                  leading: Icon(AppIcons.classes, color: AppTheme.blue),
                  title: const Text('全部班'),
                  subtitle: Text(
                    '共 ${context.read<ClassController>().classes.length} 个班',
                  ),
                  trailing: _scopeMode == _AiClassScopeMode.all
                      ? Icon(Icons.check, color: AppTheme.blue)
                      : null,
                  onTap: () {
                    setState(() => _scopeMode = _AiClassScopeMode.all);
                    Navigator.pop(ctx);
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _PendingChip extends StatelessWidget {
  const _PendingChip({required this.attach, this.onRemove});

  final _PendingAttach attach;
  final VoidCallback? onRemove;

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Container(
          width: 64,
          height: 64,
          decoration: BoxDecoration(
            color: const Color(0xFFF4F6F9),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppTheme.separator),
          ),
          clipBehavior: Clip.antiAlias,
          child: attach.isImage && attach.previewPath != null
              ? Image.file(
                  File(attach.previewPath!),
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => _fileFallback(),
                )
              : attach.isImage
                  ? Image.memory(
                      attach.bytes,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => _fileFallback(),
                    )
                  : _fileFallback(),
        ),
        if (onRemove != null)
          Positioned(
            top: -6,
            right: -6,
            child: Material(
              color: const Color(0xFF3A3A3C),
              shape: const CircleBorder(),
              child: InkWell(
                customBorder: const CircleBorder(),
                onTap: onRemove,
                child: const Padding(
                  padding: EdgeInsets.all(3),
                  child: Icon(Icons.close, size: 12, color: Colors.white),
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _fileFallback() {
    return Padding(
      padding: const EdgeInsets.all(6),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(AppIcons.file, size: 20, color: AppTheme.blue),
          const SizedBox(height: 4),
          Text(
            attach.name,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 9, color: AppTheme.secondaryLabel),
          ),
        ],
      ),
    );
  }
}

class _MascotAvatar extends StatelessWidget {
  const _MascotAvatar({required this.asset, this.size = 36});

  final String asset;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: const Color(0xFFFFF4DC),
        border: Border.all(color: Colors.white, width: 2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Image.asset(
        asset,
        fit: BoxFit.cover,
        gaplessPlayback: true,
        errorBuilder: (_, __, ___) => Center(
          child: Text('🐑', style: TextStyle(fontSize: size * 0.55)),
        ),
      ),
    );
  }
}

class _Bubble extends StatelessWidget {
  const _Bubble({
    required this.mine,
    required this.text,
    this.mascotAsset,
    this.attachmentLabels = const [],
    this.proposal,
    this.thinking,
    this.references = const [],
    this.onConfirmProposal,
    this.typing = false,
  });

  final bool mine;
  final String text;
  final String? mascotAsset;
  final List<String> attachmentLabels;
  final AiActionProposal? proposal;
  final String? thinking;
  final List<String> references;
  final VoidCallback? onConfirmProposal;
  final bool typing;

  /// 去掉整段被 ```markdown 包裹的情况（模型偶尔会这样）
  static String _normalizeMd(String raw) {
    var t = raw.trim();
    // 整篇包在一个 fence 里
    final whole = RegExp(
      r'^```(?:markdown|md)?\s*\n([\s\S]*?)\n```\s*$',
    );
    final m = whole.firstMatch(t);
    if (m != null) t = m.group(1)!.trim();
    // 去掉开头残留的 ```markdown
    t = t.replaceFirst(RegExp(r'^```(?:markdown|md)?\s*\n'), '');
    if (t.endsWith('```')) {
      t = t.substring(0, t.length - 3).trimRight();
    }
    return t;
  }

  MarkdownStyleSheet get _mdStyle => MarkdownStyleSheet(
        p: const TextStyle(
          fontSize: 16,
          height: 1.55,
          color: Color(0xFF1C1C1E),
          letterSpacing: -0.1,
        ),
        pPadding: const EdgeInsets.only(bottom: 8),
        h1: const TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.w700,
          height: 1.35,
          color: Color(0xFF1C1C1E),
        ),
        h1Padding: const EdgeInsets.only(top: 6, bottom: 8),
        h2: const TextStyle(
          fontSize: 17,
          fontWeight: FontWeight.w700,
          height: 1.35,
          color: Color(0xFF1C1C1E),
        ),
        h2Padding: const EdgeInsets.only(top: 4, bottom: 6),
        h3: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w600,
          height: 1.35,
        ),
        h3Padding: const EdgeInsets.only(top: 2, bottom: 4),
        strong: const TextStyle(fontWeight: FontWeight.w700),
        em: const TextStyle(fontStyle: FontStyle.italic),
        listBullet: TextStyle(
          fontSize: 16,
          color: AppTheme.blue,
          height: 1.55,
        ),
        listIndent: 22,
        blockSpacing: 8,
        code: TextStyle(
          fontSize: 13.5,
          fontFamily: 'monospace',
          backgroundColor: const Color(0xFFEEF1F5),
          color: const Color(0xFF1C1C1E),
        ),
        codeblockPadding: const EdgeInsets.all(12),
        codeblockDecoration: BoxDecoration(
          color: const Color(0xFFEEF1F5),
          borderRadius: BorderRadius.circular(10),
        ),
        blockquote: TextStyle(
          fontSize: 15,
          height: 1.5,
          color: AppTheme.secondaryLabel,
        ),
        blockquoteDecoration: BoxDecoration(
          border: Border(
            left: BorderSide(
              color: AppTheme.blue.withValues(alpha: 0.45),
              width: 3,
            ),
          ),
        ),
        blockquotePadding: const EdgeInsets.fromLTRB(12, 2, 0, 2),
        horizontalRuleDecoration: BoxDecoration(
          border: Border(
            top: BorderSide(color: AppTheme.separator, width: 1),
          ),
        ),
        a: TextStyle(
          color: AppTheme.blue,
          decoration: TextDecoration.underline,
        ),
      );

  @override
  Widget build(BuildContext context) {
    final bodyText = attachmentLabels.isEmpty
        ? text
        : text
            .split('\n')
            .where((l) => !l.trimLeft().startsWith('📎 '))
            .join('\n')
            .trim();
    final md = _normalizeMd(bodyText);
    final maxW = MediaQuery.sizeOf(context).width;

    // 用户气泡：右侧彩色胶囊（微信/豆包习惯）
    if (mine) {
      return Align(
        alignment: Alignment.centerRight,
        child: Container(
          margin: const EdgeInsets.only(bottom: 14, left: 48),
          constraints: BoxConstraints(maxWidth: maxW * 0.78),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: AppTheme.blue,
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(18),
              topRight: Radius.circular(18),
              bottomLeft: Radius.circular(18),
              bottomRight: Radius.circular(6),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (attachmentLabels.isNotEmpty) ...[
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    for (final name in attachmentLabels)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.18),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(AppIcons.file, size: 14, color: Colors.white),
                            const SizedBox(width: 4),
                            ConstrainedBox(
                              constraints: BoxConstraints(maxWidth: maxW * 0.5),
                              child: Text(
                                name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
                if (md.isNotEmpty) const SizedBox(height: 8),
              ],
              if (md.isNotEmpty)
                Text(
                  md,
                  style: const TextStyle(
                    fontSize: 16,
                    height: 1.45,
                    color: Colors.white,
                  ),
                ),
            ],
          ),
        ),
      );
    }

    // 助手：豆包/ChatGPT 风格——左侧头像 + 近全宽正文，Markdown 真渲染
    return Padding(
      padding: const EdgeInsets.only(bottom: 18),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (mascotAsset != null) ...[
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: _MascotAvatar(asset: mascotAsset!, size: 34),
            ),
            const SizedBox(width: 10),
          ],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF1F3F7),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (references.isNotEmpty)
                        _ReferencesChips(references: references),
                      if (thinking != null && thinking!.isNotEmpty) ...[
                        const SizedBox(height: 6),
                        _ThinkingPanel(thinking: thinking!),
                        const SizedBox(height: 8),
                      ] else if (references.isNotEmpty)
                        const SizedBox(height: 8),
                      if (typing)
                        Text(
                          md,
                          style: TextStyle(
                            fontSize: 15,
                            height: 1.45,
                            color: AppTheme.secondaryLabel,
                          ),
                        )
                      else
                        MarkdownBody(
                          data: md,
                          selectable: true,
                          softLineBreak: true,
                          styleSheet: _mdStyle,
                        ),
                    ],
                  ),
                ),
                if (proposal != null && onConfirmProposal != null) ...[
                  const SizedBox(height: 8),
                  Material(
                    color: AppTheme.blue.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(12),
                    child: InkWell(
                      onTap: onConfirmProposal,
                      borderRadius: BorderRadius.circular(12),
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
                        child: Row(
                          children: [
                            Icon(AppIcons.clipboardList,
                                size: 18, color: AppTheme.blue),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    proposal!.previewSummary,
                                    style: const TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  Text(
                                    '点击查看，确认后才会保存',
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: AppTheme.tertiaryLabel,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Icon(
                              AppIcons.chevronRight,
                              size: 18,
                              color: AppTheme.tertiaryLabel,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// 助手回答顶部：「参考数据」chip 行——展示本次回答查阅了哪些本机数据包。
class _ReferencesChips extends StatelessWidget {
  const _ReferencesChips({required this.references});
  final List<String> references;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 2),
      child: Wrap(
        spacing: 6,
        runSpacing: 4,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          Padding(
            padding: const EdgeInsets.only(right: 2),
            child: Icon(
              AppIcons.book,
              size: 13,
              color: AppTheme.tertiaryLabel,
            ),
          ),
          for (final r in references)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: AppTheme.blue.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                r,
                style: TextStyle(
                  fontSize: 11,
                  color: AppTheme.blue,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// 助手回答：可折叠的「思考过程」面板（展示模型 reasoning_content）。
class _ThinkingPanel extends StatefulWidget {
  const _ThinkingPanel({required this.thinking});
  final String thinking;

  @override
  State<_ThinkingPanel> createState() => _ThinkingPanelState();
}

class _ThinkingPanelState extends State<_ThinkingPanel> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: const Color(0xFFF6F7F9),
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: () => setState(() => _expanded = !_expanded),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(AppIcons.sparkles, size: 14, color: AppTheme.tertiaryLabel),
                  const SizedBox(width: 6),
                  Text(
                    _expanded ? '思考过程' : '查看思考过程',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.tertiaryLabel,
                    ),
                  ),
                  const Spacer(),
                  Transform.rotate(
                    angle: _expanded ? 1.5707963 : 0,
                    child: Icon(
                      AppIcons.chevronRight,
                      size: 14,
                      color: AppTheme.tertiaryLabel,
                    ),
                  ),
                ],
              ),
              if (_expanded) ...[
                const SizedBox(height: 6),
                Text(
                  widget.thinking,
                  style: TextStyle(
                    fontSize: 13,
                    height: 1.5,
                    color: AppTheme.secondaryLabel,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
