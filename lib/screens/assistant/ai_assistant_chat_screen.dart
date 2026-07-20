import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:provider/provider.dart';
import 'package:smart_class/providers/ai_settings_controller.dart';
import 'package:smart_class/providers/class_controller.dart';
import 'package:smart_class/screens/assistant/ai_action_confirm_screen.dart';
import 'package:smart_class/screens/more/ai_settings_screen.dart';
import 'package:smart_class/services/ai_action_proposal.dart';
import 'package:smart_class/services/ai_chat_history_store.dart';
import 'package:smart_class/services/ai_class_context.dart';
import 'package:smart_class/services/deepseek_ai_service.dart';
import 'package:smart_class/theme/app_icons.dart';
import 'package:smart_class/theme/app_theme.dart';
import 'package:smart_class/theme/mascot_assets.dart';
import 'package:smart_class/widgets/apple_widgets.dart';

/// 班级 AI 助手：固定「Smart Class 助手」身份；可按当前班 / 多班 / 全部查数据。
class AiAssistantChatScreen extends StatefulWidget {
  const AiAssistantChatScreen({super.key});

  @override
  State<AiAssistantChatScreen> createState() => _AiAssistantChatScreenState();
}

enum _AiClassScopeMode { current, custom, all }

class _AiAssistantChatScreenState extends State<AiAssistantChatScreen> {
  static AiChatMessage _welcome() => AiChatMessage(
        role: 'assistant',
        text: MascotAssets.assistant.welcomeText(),
        at: DateTime.fromMillisecondsSinceEpoch(0),
      );

  final _input = TextEditingController();
  final _scroll = ScrollController();
  final _messages = <AiChatMessage>[];
  bool _busy = false;
  bool _loadingHistory = true;
  bool _loadingSnap = true;
  String _classId = '';

  _AiClassScopeMode _scopeMode = _AiClassScopeMode.current;
  final Set<String> _customClassIds = {};

  static const _chips = [
    '这周课表安排',
    '今天有哪些课',
    '帮我整理今天待办',
    '帮我设计一套加减分规则',
    '积分最高的学生',
    '分析最近一次考试成绩',
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
          _messages.first.at.millisecondsSinceEpoch == 0) {
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
    final text = (preset ?? _input.text).trim();
    if (text.isEmpty || _busy) return;

    await _ensureKey();
    if (!mounted) return;
    final ai = context.read<AiSettingsController>();
    if (!ai.hasApiKey) return;
    final ctrl = context.read<ClassController>();
    final scopeIds = _scopeClassIds(ctrl);

    if (preset == null) _input.clear();
    setState(() {
      _messages.add(
        AiChatMessage(role: 'user', text: text, at: DateTime.now()),
      );
      _busy = true;
    });
    await _persist();
    if (!mounted) return;
    _scrollToEnd();

    try {
      final needClass = DeepSeekAiService.looksLikeClassDataQuestion(text);
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
          question: text,
          catalog: catalog,
        );
        if (!routed.parsed) {
          routed = await router.selectClassDataPacks(
            question: text,
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

      final reply = await ai.createService().askSmart(
            question: text,
            history: trimmed,
            classDataSnapshot: snap,
            forceClassData: needClass && (snap?.isNotEmpty ?? false),
            assistantName: MascotAssets.assistantName,
            assistantPersona: MascotAssets.assistantPersona,
          );
      if (!mounted) return;
      final parsed = ParsedAiReply.parse(reply);
      final tag = StringBuffer();
      if (routeNotice != null && routeNotice.isNotEmpty) {
        tag.writeln('（$routeNotice）');
      } else if (needClass && loadedLabel.isNotEmpty) {
        tag.writeln(
          ai.deepAnalyze ? '（已查阅：$loadedLabel · 详细）' : '（已查阅：$loadedLabel）',
        );
      } else if (ai.deepAnalyze) {
        tag.writeln('（详细分析）');
      }
      setState(() {
        _messages.add(
          AiChatMessage(
            role: 'assistant',
            text: '${tag.toString()}${parsed.displayText}',
            at: DateTime.now(),
            proposal: parsed.proposal,
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
            text: '提问失败：$e',
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
    final ai = context.watch<AiSettingsController>();
    final scopeTitle = _scopeLabel(ctrl);

    return Scaffold(
      backgroundColor: const Color(0xFFF4F6F9),
      appBar: PageAppBar(
        title: const Text(MascotAssets.assistantTitle),
        actions: [
          // 深度：主操作留在顶栏；其余收进菜单，避免挤成一排图标
          Padding(
            padding: const EdgeInsets.only(right: 2),
            child: TextButton(
              onPressed: _busy ? null : () => ai.setDeepAnalyze(!ai.deepAnalyze),
              child: Text(
                ai.deepAnalyze ? '详细·开' : '详细',
                style: TextStyle(
                  fontWeight: ai.deepAnalyze ? FontWeight.w700 : FontWeight.w500,
                  color: ai.deepAnalyze ? AppTheme.blue : AppTheme.secondaryLabel,
                ),
              ),
            ),
          ),
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
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 10),
            child: Container(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.04),
                    blurRadius: 12,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      const _MascotAvatar(asset: mascot, size: 44),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '查询范围：「$scopeTitle」',
                              style: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                                height: 1.2,
                              ),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              _loadingHistory || _loadingSnap
                                  ? '正在准备…'
                                  : ai.chatStatusHint,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 12,
                                height: 1.3,
                                color: AppTheme.secondaryLabel,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 6,
                    children: [
                      ChoiceChip(
                        label: const Text('当前班', style: TextStyle(fontSize: 12)),
                        selected: _scopeMode == _AiClassScopeMode.current,
                        onSelected: _busy
                            ? null
                            : (_) => setState(
                                  () => _scopeMode = _AiClassScopeMode.current,
                                ),
                      ),
                      ChoiceChip(
                        label: Text(
                          _scopeMode == _AiClassScopeMode.custom &&
                                  _customClassIds.isNotEmpty
                              ? '多选(${_customClassIds.length})'
                              : '多选',
                          style: const TextStyle(fontSize: 12),
                        ),
                        selected: _scopeMode == _AiClassScopeMode.custom,
                        onSelected: _busy
                            ? null
                            : (_) => _pickCustomClasses(),
                      ),
                      ChoiceChip(
                        label: const Text('全部班', style: TextStyle(fontSize: 12)),
                        selected: _scopeMode == _AiClassScopeMode.all,
                        onSelected: _busy
                            ? null
                            : (_) => setState(
                                  () => _scopeMode = _AiClassScopeMode.all,
                                ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          SizedBox(
            height: 40,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              children: [
                for (final c in _chips)
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ActionChip(
                      label: Text(c, style: const TextStyle(fontSize: 12)),
                      backgroundColor: Colors.white,
                      side: BorderSide(color: AppTheme.separator),
                      onPressed: _busy ? null : () => _send(c),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 8),
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
                        proposal: m.proposal,
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
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 10),
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
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Expanded(
                    child: TextField(
                      controller: _input,
                      minLines: 1,
                      maxLines: 4,
                      textInputAction: TextInputAction.send,
                      onSubmitted: (_) => _send(),
                      decoration: InputDecoration(
                        hintText: '例如：这周课表、谁积分最高…',
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
                  const SizedBox(width: 8),
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
            ),
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
    this.proposal,
    this.onConfirmProposal,
    this.typing = false,
  });

  final bool mine;
  final String text;
  final String? mascotAsset;
  final AiActionProposal? proposal;
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
    final md = _normalizeMd(text);
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
            color: const Color(0xFF95EC69),
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(18),
              topRight: Radius.circular(18),
              bottomLeft: Radius.circular(18),
              bottomRight: Radius.circular(6),
            ),
          ),
          child: Text(
            md,
            style: const TextStyle(
              fontSize: 16,
              height: 1.45,
              color: Color(0xFF1C1C1E),
            ),
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
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: const Color(0xFFE8ECF1),
                    ),
                  ),
                  child: typing
                      ? Text(
                          md,
                          style: TextStyle(
                            fontSize: 15,
                            height: 1.45,
                            color: AppTheme.secondaryLabel,
                          ),
                        )
                      : MarkdownBody(
                          data: md,
                          selectable: true,
                          softLineBreak: true,
                          styleSheet: _mdStyle,
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
