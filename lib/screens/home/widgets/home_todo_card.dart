import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:provider/provider.dart';
import 'package:smart_class/models/models.dart';
import 'package:smart_class/providers/ai_settings_controller.dart';
import 'package:smart_class/providers/class_controller.dart';
import 'package:smart_class/screens/todos/todos_screen.dart';
import 'package:smart_class/services/todo_voice_parser.dart';
import 'package:smart_class/services/voice_stt_service.dart';
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
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
            child: Container(
              height: 36,
              decoration: BoxDecoration(
                color: AppTheme.fill.withValues(alpha: 0.55),
                borderRadius: BorderRadius.circular(22),
                border: Border.all(
                  color: AppTheme.blue.withValues(alpha: 0.28),
                ),
              ),
              clipBehavior: Clip.antiAlias,
              child: Row(
                children: [
                  Expanded(
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: () => showTodoCreateSheet(context),
                        child: Padding(
                          padding: const EdgeInsets.only(left: 12),
                          child: Row(
                            children: [
                              Icon(
                                AppIcons.plus,
                                size: 16,
                                color: AppTheme.blue,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                '新建待办',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: AppTheme.blue,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                  Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: () => showVoiceTodoSheet(context),
                      child: SizedBox(
                        width: 40,
                        height: 36,
                        child: Icon(
                          AppIcons.mic,
                          size: 18,
                          color: AppTheme.blue,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
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
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                  decoration: BoxDecoration(
                    color: AppTheme.fill,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    '昨日',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: AppTheme.secondaryLabel.withValues(alpha: 0.85),
                    ),
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

/// 语音创建待办（App 内录音 + 国内转写，不依赖谷歌语音）
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
  static const _autoStopAfter = Duration(seconds: 10);

  var _recording = false;
  var _busy = false;
  var _error = '';
  var _raw = '';
  var _polished = '';
  var _seconds = 0;
  Timer? _ticker;
  Timer? _autoStop;

  @override
  void initState() {
    super.initState();
    // 点首页麦克风打开后即可说话，无需再点一次
    WidgetsBinding.instance.addPostFrameCallback((_) => _startRecording());
  }

  @override
  void dispose() {
    _ticker?.cancel();
    _autoStop?.cancel();
    if (_recording) {
      // ignore: discarded_futures
      _channel.invokeMethod<void>('cancel');
    }
    super.dispose();
  }

  Future<bool> _ensureMic() async {
    var mic = await Permission.microphone.status;
    if (!mic.isGranted) {
      mic = await Permission.microphone.request();
    }
    if (!mic.isGranted) {
      setState(() => _error = '需要麦克风权限才能语音输入');
      return false;
    }
    return true;
  }

  Future<void> _startRecording() async {
    if (_busy || _recording) return;
    if (!await _ensureMic()) return;
    setState(() {
      _error = '';
      _raw = '';
      _polished = '';
      _seconds = 0;
    });
    try {
      await _channel.invokeMethod<String>('start');
      if (!mounted) return;
      setState(() => _recording = true);
      _ticker?.cancel();
      _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
        if (mounted) setState(() => _seconds++);
      });
      _autoStop?.cancel();
      _autoStop = Timer(_autoStopAfter, () {
        if (mounted && _recording) _stopAndTranscribe();
      });
    } on PlatformException catch (e) {
      if (!mounted) return;
      setState(() => _error = e.message ?? '无法开始录音');
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = '无法开始录音：$e');
    }
  }

  Future<void> _toggleRecord() async {
    if (_busy) return;
    if (_recording) {
      await _stopAndTranscribe();
      return;
    }
    await _startRecording();
  }

  Future<void> _stopAndTranscribe() async {
    _ticker?.cancel();
    _autoStop?.cancel();
    if (!_recording) return;
    setState(() {
      _recording = false;
      _busy = true;
      _error = '';
    });
    try {
      final path = await _channel.invokeMethod<String>('stop');
      if (!mounted) return;
      if (path == null || path.isEmpty) {
        setState(() {
          _busy = false;
          _error = '录音失败，请重试';
        });
        return;
      }
      final ai = context.read<AiSettingsController>();
      if (!ai.hasSttApiKey) {
        setState(() {
          _busy = false;
          _error =
              '请先到「我的 → AI 助手」填写「语音转写 Key」（硅基流动，国内免费，无需谷歌）';
        });
        return;
      }
      final raw = (await VoiceSttService(apiKey: ai.sttApiKey).transcribeFile(path))
          .trim();
      if (!mounted) return;
      // 静音/噪声时 SenseVoice 常吐标点或语气词，不当作有效识别
      if (!_looksLikeSpeech(raw)) {
        setState(() {
          _busy = false;
          _raw = '';
          _polished = '';
          _error = '没听清，请对着麦克风再说一次';
        });
        return;
      }
      setState(() {
        _raw = raw;
        _busy = false;
      });
      await _polish(raw);
    } on VoiceSttException catch (e) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = e.message;
      });
    } on PlatformException catch (e) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = e.message ?? '录音失败';
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = '识别失败：$e';
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

  /// 去掉标点/空白后仍需有实质内容；纯「嗯」「啊」等视为未说话
  static bool _looksLikeSpeech(String raw) {
    final t = raw.trim();
    if (t.isEmpty) return false;
    final core = t.replaceAll(
      RegExp(r'[\s.,，。、！？!?;；:：…·\-—_~～"“”‘’（）()【】\[\]<>《》]+'),
      '',
    );
    if (core.isEmpty) return false;
    const fillers = {
      '嗯',
      '啊',
      '哦',
      '呃',
      '唔',
      '欸',
      '哎',
      '嗯嗯',
      '啊啊',
      '哦哦',
    };
    return !fillers.contains(core);
  }

  String get _hint {
    if (_recording) {
      final left = (_autoStopAfter.inSeconds - _seconds).clamp(0, 99);
      return '请直接说话 · ${left}s 后自动识别（也可再点结束）';
    }
    if (_busy) return '正在转写…';
    if (_raw.isNotEmpty) return '可点麦克风重录';
    return '点麦克风开始说话';
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
            _recording
                ? '正在录音…'
                : (_busy ? '识别中…' : '语音待办'),
            style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 20),
          GestureDetector(
            onTap: _busy && !_recording ? null : _toggleRecord,
            child: Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: _recording
                    ? AppTheme.destructive.withValues(alpha: 0.12)
                    : AppTheme.blue.withValues(alpha: 0.08),
                shape: BoxShape.circle,
                border: Border.all(
                  color: _recording
                      ? AppTheme.destructive.withValues(alpha: 0.5)
                      : AppTheme.blue.withValues(alpha: 0.4),
                  width: _recording ? 2.5 : 1,
                ),
              ),
              child: Icon(
                _recording ? AppIcons.close : AppIcons.mic,
                size: 32,
                color: _recording ? AppTheme.destructive : AppTheme.blue,
              ),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            _hint,
            textAlign: TextAlign.center,
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
          ],
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => Navigator.pop(context),
                  style: OutlinedButton.styleFrom(
                    shape: const StadiumBorder(),
                  ),
                  child: const Text('取消'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: FilledButton(
                  onPressed:
                      display.isEmpty || _busy || _recording ? null : _save,
                  style: FilledButton.styleFrom(
                    shape: const StadiumBorder(),
                  ),
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


