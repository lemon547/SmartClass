import 'package:flutter/material.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:smart_class/models/models.dart';
import 'package:smart_class/providers/class_controller.dart';
import 'package:smart_class/theme/app_icons.dart';
import 'package:smart_class/theme/app_theme.dart';
import 'package:smart_class/widgets/apple_widgets.dart';

/// 待办完整页：今天 + 历史，按日期分组
class TodosScreen extends StatefulWidget {
  const TodosScreen({super.key});

  @override
  State<TodosScreen> createState() => _TodosScreenState();
}

class _TodosScreenState extends State<TodosScreen> {
  final _input = TextEditingController();
  /// 0 全部 · 1 未完成 · 2 已完成
  int _filter = 0;

  @override
  void dispose() {
    _input.dispose();
    super.dispose();
  }

  Future<void> _submit(ClassController ctrl) async {
    final text = _input.text.trim();
    if (text.isEmpty) return;
    _input.clear();
    await ctrl.addTodo(text);
  }

  List<TeacherTodo> _filtered(List<TeacherTodo> all) {
    return switch (_filter) {
      1 => [for (final t in all) if (!t.done) t],
      2 => [for (final t in all) if (t.done) t],
      _ => all,
    };
  }

  List<(String, List<TeacherTodo>)> _grouped(List<TeacherTodo> items) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));

    final buckets = <String, List<TeacherTodo>>{};
    final order = <String>[];

    String labelFor(DateTime d) {
      final day = DateTime(d.year, d.month, d.day);
      if (day == today) return '今天';
      if (day == yesterday) return '昨天';
      if (now.difference(day).inDays < 7) {
        const week = ['一', '二', '三', '四', '五', '六', '日'];
        return '周${week[day.weekday - 1]} · ${DateFormat('M月d日').format(day)}';
      }
      if (day.year == now.year) return DateFormat('M月d日').format(day);
      return DateFormat('y年M月d日').format(day);
    }

    final sorted = [...items]
      ..sort((a, b) {
        final byDone = a.done == b.done ? 0 : (a.done ? 1 : -1);
        if (byDone != 0) return byDone;
        return b.createdAt.compareTo(a.createdAt);
      });

    for (final t in sorted) {
      final label = labelFor(t.createdAt);
      buckets.putIfAbsent(label, () {
        order.add(label);
        return <TeacherTodo>[];
      }).add(t);
    }
    return [for (final k in order) (k, buckets[k]!)];
  }

  @override
  Widget build(BuildContext context) {
    final ctrl = context.watch<ClassController>();
    final items = _filtered(ctrl.todos);
    final groups = _grouped(items);
    final pending = ctrl.todos.where((t) => !t.done).length;

    return Scaffold(
      backgroundColor: AppTheme.bg,
      appBar: PageAppBar(
        title: const Text('待办'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: Center(
              child: Text(
                pending == 0 ? '已全部完成' : '$pending 项未完成',
                style: TextStyle(
                  fontSize: 13,
                  color: AppTheme.secondaryLabel,
                ),
              ),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            child: TextField(
              controller: _input,
              textInputAction: TextInputAction.done,
              onSubmitted: (_) => _submit(ctrl),
              decoration: InputDecoration(
                hintText: '记一条待办，回车保存',
                prefixIcon: Icon(AppIcons.circlePlus, color: AppTheme.blue),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: _FilterTabs(
              index: _filter,
              onChanged: (i) => setState(() => _filter = i),
            ),
          ),
          Expanded(
            child: items.isEmpty
                ? Center(
                    child: Text(
                      _filter == 2
                          ? '还没有已完成的待办'
                          : _filter == 1
                              ? '没有未完成待办'
                              : '还没有待办，上面输入一条试试',
                      style: TextStyle(
                        color: AppTheme.tertiaryLabel,
                        fontSize: 15,
                      ),
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
                    itemCount: groups.length,
                    itemBuilder: (context, gi) {
                      final (label, list) = groups[gi];
                      return Padding(
                        padding: EdgeInsets.only(top: gi == 0 ? 0 : 14),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Padding(
                              padding: const EdgeInsets.only(
                                left: 4,
                                bottom: 8,
                              ),
                              child: Text(
                                label,
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: AppTheme.tertiaryLabel,
                                ),
                              ),
                            ),
                            Container(
                              decoration: BoxDecoration(
                                color: AppTheme.surface,
                                borderRadius: BorderRadius.circular(14),
                              ),
                              clipBehavior: Clip.antiAlias,
                              child: SlidableAutoCloseBehavior(
                                child: Column(
                                  children: [
                                    for (var i = 0; i < list.length; i++) ...[
                                      if (i > 0)
                                        Divider(
                                          height: 1,
                                          indent: 50,
                                          color: AppTheme.separator
                                              .withValues(alpha: 0.5),
                                        ),
                                      _TodoTile(
                                        todo: list[i],
                                        onToggle: () =>
                                            ctrl.toggleTodo(list[i].id),
                                        onDelete: () =>
                                            ctrl.deleteTodo(list[i].id),
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

class _FilterTabs extends StatelessWidget {
  const _FilterTabs({required this.index, required this.onChanged});
  final int index;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    const labels = ['全部', '未完成', '已完成'];
    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: AppTheme.fill,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          for (var i = 0; i < labels.length; i++)
            Expanded(
              child: Material(
                color: index == i ? AppTheme.surface : Colors.transparent,
                borderRadius: BorderRadius.circular(8),
                elevation: index == i ? 0.4 : 0,
                shadowColor: Colors.black26,
                child: InkWell(
                  onTap: () => onChanged(i),
                  borderRadius: BorderRadius.circular(8),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Text(
                      labels[i],
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight:
                            index == i ? FontWeight.w700 : FontWeight.w500,
                        color: index == i
                            ? AppTheme.blue
                            : AppTheme.secondaryLabel,
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _TodoTile extends StatelessWidget {
  const _TodoTile({
    required this.todo,
    required this.onToggle,
    required this.onDelete,
  });

  final TeacherTodo todo;
  final VoidCallback onToggle;
  final Future<void> Function() onDelete;

  @override
  Widget build(BuildContext context) {
    final time = DateFormat('HH:mm').format(todo.createdAt);
    return AppleDeleteSlidable(
      itemKey: ValueKey(todo.id),
      onDelete: onDelete,
      child: InkWell(
        onTap: onToggle,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(
            children: [
              Icon(
                todo.done ? AppIcons.circleCheck : AppIcons.circle,
                size: 22,
                color: todo.done ? AppTheme.blue : AppTheme.quaternaryLabel,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      todo.title,
                      style: TextStyle(
                        fontSize: 16,
                        color: todo.done
                            ? AppTheme.tertiaryLabel
                            : AppTheme.label,
                        decoration: todo.done
                            ? TextDecoration.lineThrough
                            : TextDecoration.none,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      time,
                      style: TextStyle(
                        fontSize: 12,
                        color: AppTheme.quaternaryLabel,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
