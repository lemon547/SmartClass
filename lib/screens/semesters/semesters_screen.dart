import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:smart_class/models/models.dart';
import 'package:smart_class/providers/class_controller.dart';
import 'package:smart_class/screens/semesters/semester_detail_screen.dart';
import 'package:smart_class/theme/app_icons.dart';
import 'package:smart_class/theme/app_theme.dart';
import 'package:smart_class/widgets/apple_widgets.dart';

/// 学期管理：当前学期日常使用，结束后存档并可查阅
class SemestersScreen extends StatelessWidget {
  const SemestersScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final ctrl = context.watch<ClassController>();
    final active = ctrl.activeSemester;
    final archived =
        ctrl.semesters.where((s) => s.isArchived).toList(growable: false);

    return Scaffold(
      appBar: AppBar(title: const Text('学期')),
      body: ListView(
        padding: const EdgeInsets.only(bottom: 28),
        children: [
          const SizedBox(height: 8),
          GroupedSection(
            header: '当前学期',
            footer: '日常数据计入本学期。结束时可整学期存档，并开启新学期。',
            children: [
              GroupedTile(
                title: active?.title ?? '本学期',
                subtitle: _activeSubtitle(active),
                onTap: () {
                  if (active == null) return;
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) =>
                          SemesterDetailScreen(semesterId: active.id),
                    ),
                  );
                },
              ),
              GroupedTile(
                title: '重命名当前学期',
                onTap: () => _renameActive(context),
              ),
              GroupedTile(
                title: '结束本学期并开启新学期',
                subtitle: '存档后保留花名册，积分 / 考勤 / 成绩等清零',
                titleColor: AppTheme.blue,
                onTap: () => _archive(context),
              ),
            ],
          ),
          const SizedBox(height: 18),
          GroupedSection(
            header: '历史学期',
            footer: archived.isEmpty ? '还没有存档学期' : '点进查看该学期排行、考试、留痕等概况',
            children: [
              if (archived.isEmpty)
                Padding(
                  padding: const EdgeInsets.all(18),
                  child: Text(
                    '暂无存档',
                    style: TextStyle(color: AppTheme.tertiaryLabel),
                  ),
                )
              else
                for (final s in archived)
                  GroupedTile(
                    title: s.title,
                    subtitle: _archivedSubtitle(s),
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) =>
                            SemesterDetailScreen(semesterId: s.id),
                      ),
                    ),
                  ),
            ],
          ),
        ],
      ),
    );
  }

  String _activeSubtitle(Semester? s) {
    if (s == null) return '进行中';
    final parts = <String>['进行中'];
    if (s.startDate.isNotEmpty) parts.add('起 ${s.startDate}');
    return parts.join(' · ');
  }

  String _archivedSubtitle(Semester s) {
    final parts = <String>[];
    if (s.startDate.isNotEmpty || s.endDate.isNotEmpty) {
      parts.add('${s.startDate.isEmpty ? '—' : s.startDate} ~ ${s.endDate.isEmpty ? '—' : s.endDate}');
    }
    if (s.archivedAt != null) {
      parts.add('存档 ${DateFormat('yyyy/M/d').format(s.archivedAt!)}');
    }
    final stats = s.snapshotMap?['stats'] as Map?;
    if (stats != null) {
      final n = stats['studentCount'];
      final exams = stats['examCount'];
      if (n != null) parts.add('$n 人');
      if (exams != null) parts.add('$exams 次考试');
    }
    return parts.isEmpty ? '已存档' : parts.join(' · ');
  }

  Future<void> _renameActive(BuildContext context) async {
    final ctrl = context.read<ClassController>();
    final text = TextEditingController(text: ctrl.activeSemester?.title ?? '');
    final ok = await showCupertinoDialog<bool>(
      context: context,
      builder: (ctx) => CupertinoAlertDialog(
        title: const Text('重命名学期'),
        content: Padding(
          padding: const EdgeInsets.only(top: 12),
          child: CupertinoTextField(
            controller: text,
            placeholder: '如：2025–2026 学年 · 上学期',
            autofocus: true,
          ),
        ),
        actions: [
          CupertinoDialogAction(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('取消'),
          ),
          CupertinoDialogAction(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('保存'),
          ),
        ],
      ),
    );
    final title = text.text.trim();
    text.dispose();
    if (ok != true || title.isEmpty) return;
    await ctrl.renameActiveSemester(title);
  }

  Future<void> _archive(BuildContext context) async {
    final ctrl = context.read<ClassController>();
    final archiveTitle =
        TextEditingController(text: ctrl.activeSemester?.title ?? '');
    final newTitle = TextEditingController(text: Semester.defaultLabel().title);
    final note = TextEditingController();

    final ok = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      isDismissible: true,
      enableDrag: true,
      showDragHandle: true,
      useSafeArea: true,
      builder: (ctx) {
        return Padding(
          padding: EdgeInsets.only(
            left: 20,
            right: 20,
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text('结束本学期',
                        style: Theme.of(ctx).textTheme.titleLarge),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(ctx, false),
                    icon: Icon(AppIcons.close, color: AppTheme.blue),
                  ),
                ],
              ),
              Text(
                '将把本学期积分、考勤、成绩、留痕等存档；花名册与座位、课程表保留，并开启新学期。',
                style: TextStyle(fontSize: 13, color: AppTheme.tertiaryLabel),
              ),
              const SizedBox(height: 14),
              TextField(
                controller: archiveTitle,
                decoration: const InputDecoration(labelText: '存档学期名称'),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: newTitle,
                decoration: const InputDecoration(labelText: '新学期名称'),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: note,
                decoration: const InputDecoration(labelText: '备注（选填）'),
              ),
              const SizedBox(height: 18),
              FilledButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('确认存档并开启'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('取消'),
              ),
            ],
          ),
        );
      },
    );

    final aTitle = archiveTitle.text.trim();
    final nTitle = newTitle.text.trim();
    final n = note.text.trim();
    archiveTitle.dispose();
    newTitle.dispose();
    note.dispose();
    if (ok != true) return;

    await ctrl.archiveSemesterAndStartNew(
      archiveTitle: aTitle,
      newTitle: nTitle,
      note: n,
    );
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('已存档，新学期：${ctrl.activeSemester?.title ?? nTitle}'),
      ),
    );
  }
}
