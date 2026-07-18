import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
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

/// 懒羊羊机器人：可调取本班数据回答问题；聊天记录按班级保存在本机。
class AiAssistantChatScreen extends StatefulWidget {
  const AiAssistantChatScreen({super.key});

  @override
  State<AiAssistantChatScreen> createState() => _AiAssistantChatScreenState();
}

class _AiAssistantChatScreenState extends State<AiAssistantChatScreen> {
  static AiChatMessage get _welcomeMsg => AiChatMessage(
        role: 'assistant',
        text: '咩～我是懒羊羊。问课表、成绩、积分、考勤我会自动查本班；'
            '也可以说「帮我整理今天待办」「设计一套加减分规则」——'
            '我会先给草稿，你确认后才写入。\n'
            '难一点的分析可点右上「深度」。',
        at: DateTime.fromMillisecondsSinceEpoch(0),
      );

  final _input = TextEditingController();
  final _scroll = ScrollController();
  final _messages = <AiChatMessage>[];
  bool _busy = false;
  bool _loadingHistory = true;
  bool _loadingSnap = true;
  String _classId = '';

  static const _chips = [
    '这周课表安排',
    '今天有哪些课',
    '帮我整理今天待办',
    '帮我设计一套加减分规则',
    '积分最高的学生',
    '分析最近一次考试成绩',
    '根据最近考试写一节班会提纲',
    '帮我生成月考家长会内容',
    '今日考勤情况',
  ];

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
        ..addAll(saved.isEmpty ? [_welcomeMsg] : saved);
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
        content: const Text('仅清除本班与懒羊羊的对话，不影响学生成绩等数据。'),
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
        ..add(_welcomeMsg);
    });
  }

  Future<void> _prepareSnapshot() async {
    setState(() => _loadingSnap = true);
    try {
      final ctrl = context.read<ClassController>();
      // 预热成绩缓存；真正提问时再按问题生成精简快照
      await ctrl.ensureAllExamScores();
      if (!mounted) return;
      setState(() => _loadingSnap = false);
    } catch (_) {
      if (!mounted) return;
      setState(() => _loadingSnap = false);
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
        final catalog = await AiClassContext.buildCatalog(ctrl);
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
          snap = await AiClassContext.loadPacks(ctrl, selection);
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
          );
      if (!mounted) return;
      final parsed = ParsedAiReply.parse(reply);
      final tag = StringBuffer();
      if (routeNotice != null && routeNotice.isNotEmpty) {
        tag.writeln('（$routeNotice）');
      } else if (needClass && loadedLabel.isNotEmpty) {
        tag.writeln(
          ai.deepAnalyze ? '（已查：$loadedLabel · 深度）' : '（已查：$loadedLabel）',
        );
      } else if (ai.deepAnalyze) {
        tag.writeln('（深度）');
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
    final classTitle =
        context.watch<ClassController>().currentClass?.displayTitle ?? '未选班级';

    return Scaffold(
      backgroundColor: AppTheme.bg,
      appBar: PageAppBar(
        title: const Text('懒羊羊助手'),
        actions: [
          Consumer<AiSettingsController>(
            builder: (context, ai, _) {
              final on = ai.deepAnalyze;
              return TextButton(
                onPressed: _busy
                    ? null
                    : () => ai.setDeepAnalyze(!on),
                child: Text(
                  on ? '深度·开' : '深度',
                  style: TextStyle(
                    fontWeight: on ? FontWeight.w700 : FontWeight.w500,
                    color: on ? AppTheme.blue : AppTheme.secondaryLabel,
                  ),
                ),
              );
            },
          ),
          IconButton(
            tooltip: '清空记录',
            onPressed: _busy || _loadingHistory ? null : _clearHistory,
            icon: Icon(AppIcons.trash, color: AppTheme.tertiaryLabel),
          ),
          IconButton(
            tooltip: '刷新班级数据',
            onPressed: _busy ? null : _prepareSnapshot,
            icon: const Icon(AppIcons.refresh),
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: Row(
              children: [
                ClipOval(
                  child: Image.asset(
                    MascotAssets.wave,
                    width: 36,
                    height: 36,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) =>
                        const Text('🐑', style: TextStyle(fontSize: 28)),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    _loadingHistory || _loadingSnap
                        ? '正在准备「$classTitle」…'
                        : '「$classTitle」· ${context.watch<AiSettingsController>().runtimeHint}',
                    style: TextStyle(
                      fontSize: 13,
                      color: AppTheme.secondaryLabel,
                    ),
                  ),
                ),
              ],
            ),
          ),
          SizedBox(
            height: 36,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              children: [
                for (final c in _chips)
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ActionChip(
                      label: Text(c, style: const TextStyle(fontSize: 12)),
                      onPressed: _busy ? null : () => _send(c),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 6),
          Expanded(
            child: _loadingHistory
                ? const Center(child: CircularProgressIndicator.adaptive())
                : ListView.builder(
                    controller: _scroll,
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                    itemCount: _messages.length + (_busy ? 1 : 0),
                    itemBuilder: (context, i) {
                      if (_busy && i == _messages.length) {
                        return const _Bubble(
                          mine: false,
                          text: '懒羊羊翻数据中…',
                        );
                      }
                      final m = _messages[i];
                      return _Bubble(
                        mine: m.role == 'user',
                        text: m.text,
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
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 10),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _input,
                      minLines: 1,
                      maxLines: 4,
                      textInputAction: TextInputAction.send,
                      onSubmitted: (_) => _send(),
                      decoration: const InputDecoration(
                        hintText: '问问本班数据，或整理待办/积分规则…',
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton.filled(
                    onPressed: _busy ? null : () => _send(),
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

class _Bubble extends StatelessWidget {
  const _Bubble({
    required this.mine,
    required this.text,
    this.proposal,
    this.onConfirmProposal,
  });

  final bool mine;
  final String text;
  final AiActionProposal? proposal;
  final VoidCallback? onConfirmProposal;

  @override
  Widget build(BuildContext context) {
    final bg = mine ? const Color(0xFF95EC69) : AppTheme.surface;
    final align = mine ? Alignment.centerRight : Alignment.centerLeft;
    return Align(
      alignment: align,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.sizeOf(context).width * 0.78,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(14),
            topRight: const Radius.circular(14),
            bottomLeft: Radius.circular(mine ? 14 : 4),
            bottomRight: Radius.circular(mine ? 4 : 14),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              text,
              style: TextStyle(
                fontSize: 15,
                height: 1.35,
                color: AppTheme.label,
              ),
            ),
            if (!mine && proposal != null && onConfirmProposal != null) ...[
              const SizedBox(height: 10),
              Material(
                color: AppTheme.blue.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(10),
                child: InkWell(
                  onTap: onConfirmProposal,
                  borderRadius: BorderRadius.circular(10),
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
                                '点此审阅，确认后才会写入',
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
    );
  }
}
