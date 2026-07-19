import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:provider/provider.dart';
import 'package:smart_class/models/models.dart';
import 'package:smart_class/providers/ai_settings_controller.dart';
import 'package:smart_class/providers/class_controller.dart';
import 'package:smart_class/screens/todos/todos_screen.dart';
import 'package:smart_class/services/todo_voice_parser.dart';
import 'package:smart_class/theme/app_icons.dart';
import 'package:smart_class/theme/app_theme.dart';
import 'package:smart_class/widgets/apple_widgets.dart';

const _cardRadius = 16.0;

/// 首页待办卡片：快速创建 / 完成，无优先级
class HomeTodoCard extends StatelessWidget {
  const HomeTodoCard({super.key});

  @override
  Widget build(BuildContext context) {
    final ctrl = context.watch<ClassController>();
    final todos = [...ctrl.todayTodos]
      ..sort((a, b) {
        if (a.done != b.done) return a.done ? 1 : -1;
        return a.sortOrder.compareTo(b.sortOrder);
      });
    final pending = todos.where((t) => !t.done).toList();
    final done = todos.where((t) => t.done).toList();

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(_cardRadius),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          InkWell(
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const TodosScreen()),
            ),
            borderRadius: const BorderRadius.vertical(
              top: Radius.circular(_cardRadius),
            ),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(14, 12, 10, 8),
              child: Row(
                children: [
                  const Text(
                    '待办事项',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                  ),
                  const Spacer(),
                  Text(
                    pending.isEmpty ? '今日暂无' : '今天 ${pending.length}项',
                    style: TextStyle(
                      fontSize: 13,
                      color: AppTheme.tertiaryLabel,
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
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 10),
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => showTodoCreateSheet(context),
                    icon: const Icon(AppIcons.plus, size: 18),
                    label: const Text('新建待办'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppTheme.blue,
                      side: BorderSide(
                        color: AppTheme.blue.withValues(alpha: 0.35),
                      ),
                      alignment: Alignment.centerLeft,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 10,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton.outlined(
                  tooltip: '语音输入',
                  onPressed: () => showVoiceTodoSheet(context),
                  icon: const Icon(AppIcons.mic, size: 20),
                  style: IconButton.styleFrom(
                    foregroundColor: AppTheme.blue,
                    side: BorderSide(
                      color: AppTheme.blue.withValues(alpha: 0.35),
                    ),
                    minimumSize: const Size(44, 44),
                  ),
                ),
              ],
            ),
          ),
          if (pending.isEmpty && done.isEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 0, 14, 16),
              child: Text(
                '点上方快速记一条',
                style: TextStyle(color: AppTheme.tertiaryLabel, fontSize: 14),
              ),
            )
          else ...[
            if (pending.isNotEmpty) ...[
              const _SectionLabel('待处理'),
              SlidableAutoCloseBehavior(
                child: Column(
                  children: [
                    for (final t in pending.take(8))
                      _TodoRow(
                        todo: t,
                        onToggle: () => ctrl.toggleTodo(t.id),
                        onDelete: () => ctrl.deleteTodo(t.id),
                      ),
                  ],
                ),
              ),
            ],
            if (done.isNotEmpty) ...[
              const _SectionLabel('已完成'),
              SlidableAutoCloseBehavior(
                child: Column(
                  children: [
                    for (final t in done.take(4))
                      _TodoRow(
                        todo: t,
                        onToggle: () => ctrl.toggleTodo(t.id),
                        onDelete: () => ctrl.deleteTodo(t.id),
                      ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 8),
          ],
        ],
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 4, 14, 2),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: AppTheme.tertiaryLabel,
        ),
      ),
    );
  }
}

class _TodoRow extends StatelessWidget {
  const _TodoRow({
    required this.todo,
    required this.onToggle,
    required this.onDelete,
  });

  final TeacherTodo todo;
  final VoidCallback onToggle;
  final Future<void> Function() onDelete;

  @override
  Widget build(BuildContext context) {
    return AppleDeleteSlidable(
      itemKey: ValueKey(todo.id),
      onDelete: onDelete,
      child: InkWell(
        onTap: onToggle,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
          child: Row(
            children: [
              Icon(
                todo.done ? AppIcons.circleCheck : AppIcons.circle,
                size: 22,
                color: todo.done ? AppTheme.blue : AppTheme.quaternaryLabel,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  todo.title,
                  style: TextStyle(
                    fontSize: 15,
                    color: todo.done ? AppTheme.tertiaryLabel : AppTheme.label,
                    decoration: todo.done
                        ? TextDecoration.lineThrough
                        : TextDecoration.none,
                  ),
                ),
              ),
              if (!todo.isCreatedToday && !todo.done)
                Text(
                  '往日',
                  style: TextStyle(
                    fontSize: 11,
                    color: AppTheme.quaternaryLabel,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 底部文字新建面板
Future<void> showTodoCreateSheet(BuildContext context) async {
  final ctrl = context.read<ClassController>();
  final input = TextEditingController();
  final saved = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (ctx) {
      final bottom = MediaQuery.viewInsetsOf(ctx).bottom;
      return Padding(
        padding: EdgeInsets.fromLTRB(20, 0, 20, 16 + bottom),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              '新增待办',
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: input,
              autofocus: true,
              textInputAction: TextInputAction.done,
              maxLines: 3,
              minLines: 1,
              onSubmitted: (_) => Navigator.pop(ctx, true),
              decoration: const InputDecoration(
                hintText: '写一条待办…',
                isDense: true,
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                IconButton(
                  tooltip: '语音输入',
                  onPressed: () {
                    Navigator.pop(ctx, false);
                    showVoiceTodoSheet(context);
                  },
                  icon: const Icon(AppIcons.mic),
                ),
                const Spacer(),
                TextButton(
                  onPressed: () => Navigator.pop(ctx, false),
                  child: const Text('取消'),
                ),
                const SizedBox(width: 8),
                FilledButton(
                  onPressed: () => Navigator.pop(ctx, true),
                  child: const Text('保存'),
                ),
              ],
            ),
          ],
        ),
      );
    },
  );
  final text = input.text.trim();
  input.dispose();
  if (saved == true && text.isNotEmpty) {
    await ctrl.addTodo(text);
  }
}

/// 语音创建待办
Future<void> showVoiceTodoSheet(BuildContext context) async {
  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (ctx) => const _VoiceTodoSheet(),
  );
}

class _VoiceTodoSheet extends StatefulWidget {
  const _VoiceTodoSheet();

  @override
  State<_VoiceTodoSheet> createState() => _VoiceTodoSheetState();
}

class _VoiceTodoSheetState extends State<_VoiceTodoSheet> {
  static const _channel = MethodChannel('smart_class/voice_record');

  var _listening = false;
  var _busy = false;
  var _error = '';
  var _raw = '';
  var _polished = '';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _listenOnce());
  }

  Future<void> _listenOnce() async {
    if (_listening || _busy) return;
    setState(() {
      _listening = true;
      _error = '';
    });
    try {
      final text = await _channel.invokeMethod<String>('recognizeSpeech');
      if (!mounted) return;
      final raw = (text ?? '').trim();
      setState(() {
        _listening = false;
        _raw = raw;
        if (raw.isEmpty) _error = '未识别到内容，请再试一次';
      });
      if (raw.isNotEmpty) await _polish(raw);
    } on PlatformException catch (e) {
      if (!mounted) return;
      setState(() {
        _listening = false;
        _error = e.message ?? '语音识别失败';
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _listening = false;
        _error = '语音不可用：$e';
      });
    }
  }

  Future<void> _polish(String raw) async {
    setState(() => _busy = true);
    final ai = context.read<AiSettingsController>();
    final title = await TodoVoiceParser.polish(raw, aiSettings: ai);
    if (!mounted) return;
    setState(() {
      _polished = title;
      _busy = false;
    });
  }

  Future<void> _save() async {
    final title = (_polished.isNotEmpty ? _polished : _raw).trim();
    if (title.isEmpty) return;
    await context.read<ClassController>().addTodo(title);
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.viewInsetsOf(context).bottom;
    final display = _polished.isNotEmpty ? _polished : _raw;

    return Padding(
      padding: EdgeInsets.fromLTRB(20, 0, 20, 16 + bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            _listening
                ? '正在听…'
                : (_busy ? '整理中…' : '语音待办'),
            style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 20),
          GestureDetector(
            onTap: _listening || _busy ? null : _listenOnce,
            child: Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: _listening
                    ? AppTheme.blue.withValues(alpha: 0.15)
                    : AppTheme.blue.withValues(alpha: 0.08),
                shape: BoxShape.circle,
                border: Border.all(
                  color: AppTheme.blue.withValues(alpha: 0.4),
                  width: _listening ? 2.5 : 1,
                ),
              ),
              child: Icon(
                AppIcons.mic,
                size: 32,
                color: AppTheme.blue,
              ),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            _listening ? '请对着系统弹窗说话' : '点麦克风再说一次',
            style: TextStyle(fontSize: 13, color: AppTheme.tertiaryLabel),
          ),
          if (_error.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              _error,
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12, color: AppTheme.destructive),
            ),
          ],
          if (display.isNotEmpty) ...[
            const SizedBox(height: 16),
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                '识别结果',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.tertiaryLabel,
                ),
              ),
            ),
            const SizedBox(height: 6),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppTheme.bg,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppTheme.separator),
              ),
              child: Text(
                display,
                style: const TextStyle(fontSize: 16, height: 1.35),
              ),
            ),
            if (_raw.isNotEmpty &&
                _polished.isNotEmpty &&
                _raw != _polished) ...[
              const SizedBox(height: 6),
              Text(
                '原文：$_raw',
                style: TextStyle(fontSize: 12, color: AppTheme.quaternaryLabel),
              ),
            ],
          ],
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('取消'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: FilledButton(
                  onPressed: display.isEmpty || _busy ? null : _save,
                  child: const Text('创建'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

