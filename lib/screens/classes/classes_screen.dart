import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:smart_class/data/class_repository.dart';
import 'package:smart_class/models/models.dart';
import 'package:smart_class/providers/class_controller.dart';
import 'package:smart_class/screens/classes/class_features_screen.dart';
import 'package:smart_class/theme/app_theme.dart';
import 'package:smart_class/widgets/apple_widgets.dart';

/// 多班级管理：按学校归类，支持切换 / 新增 / 编辑 / 删除
class ClassesScreen extends StatelessWidget {
  const ClassesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final ctrl = context.watch<ClassController>();
    final bySchool = <String, List<ManagedClass>>{};
    for (final c in ctrl.classes) {
      bySchool.putIfAbsent(c.schoolLabel, () => []).add(c);
    }
    final schools = bySchool.keys.toList()
      ..sort((a, b) {
        if (a == '未填写学校') return 1;
        if (b == '未填写学校') return -1;
        return a.compareTo(b);
      });

    return Scaffold(
      appBar: AppBar(
        title: const Text('班级'),
        actions: [
          IconButton(
            tooltip: '添加班级',
            onPressed: () => _editClass(context),
            icon: const Icon(Icons.add),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.only(bottom: 28),
        children: [
          for (final school in schools) ...[
            GroupedSection(
              header: school,
              footer: '${bySchool[school]!.length} 个班级',
              children: [
                for (final c in bySchool[school]!)
                  GroupedTile(
                    title: c.displayTitle,
                    subtitle: [
                      c.roleLabel,
                      if (c.groupName.trim().isNotEmpty) c.groupName.trim(),
                      if (c.id == ctrl.currentClass?.id) '当前',
                    ].join(' · '),
                    trailing: c.id == ctrl.currentClass?.id
                        ? Icon(Icons.check_circle,
                            color: AppTheme.blue, size: 22)
                        : null,
                    onTap: () async {
                      if (c.id != ctrl.currentClass?.id) {
                        await ctrl.switchClass(c.id);
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('已切换到 ${c.displayTitle}'),
                            ),
                          );
                        }
                      }
                    },
                    onLongPress: () => _classActions(context, c),
                  ),
              ],
            ),
            const SizedBox(height: 12),
          ],
          if (ctrl.classes.isEmpty)
            const Padding(
              padding: EdgeInsets.all(24),
              child: Text('暂无班级，请点击右上角添加'),
            ),
        ],
      ),
    );
  }

  Future<void> _classActions(BuildContext context, ManagedClass c) async {
    final ctrl = context.read<ClassController>();
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.swap_horiz),
              title: const Text('切换到此班'),
              onTap: () async {
                Navigator.pop(ctx);
                await ctrl.switchClass(c.id);
              },
            ),
            ListTile(
              leading: const Icon(Icons.edit_outlined),
              title: const Text('编辑'),
              onTap: () {
                Navigator.pop(ctx);
                _editClass(context, existing: c);
              },
            ),
            ListTile(
              leading: const Icon(Icons.tune),
              title: const Text('本班功能'),
              onTap: () async {
                Navigator.pop(ctx);
                if (c.id != ctrl.currentClass?.id) {
                  await ctrl.switchClass(c.id);
                }
                if (!context.mounted) return;
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => const ClassFeaturesScreen(),
                  ),
                );
              },
            ),
            if (ctrl.classes.length > 1)
              ListTile(
                leading:
                    Icon(Icons.delete_outline, color: AppTheme.destructive),
                title:
                    Text('删除', style: TextStyle(color: AppTheme.destructive)),
                onTap: () async {
                  Navigator.pop(ctx);
                  final ok = await showDialog<bool>(
                    context: context,
                    builder: (d) => AlertDialog(
                      title: const Text('删除班级？'),
                      content: Text(
                        '将删除「${c.displayTitle}」及其学生、考勤、成绩等全部数据，且不可恢复。',
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(d, false),
                          child: const Text('取消'),
                        ),
                        FilledButton(
                          onPressed: () => Navigator.pop(d, true),
                          child: const Text('删除'),
                        ),
                      ],
                    ),
                  );
                  if (ok == true) await ctrl.deleteManagedClass(c.id);
                },
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _editClass(BuildContext context, {ManagedClass? existing}) async {
    final ctrl = context.read<ClassController>();
    final result = await showModalBottomSheet<_ClassEditResult>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (ctx) => _ClassEditSheet(
        existing: existing,
        defaultRows: existing?.seatRows ?? ctrl.profile.seatRows,
        defaultCols: existing?.seatCols ?? ctrl.profile.seatCols,
        knownSchools: [
          for (final c in ctrl.classes)
            if (c.school.trim().isNotEmpty) c.school.trim(),
        ]..sort(),
      ),
    );
    if (result == null || !context.mounted) return;

    if (existing == null) {
      await ctrl.createManagedClass(
        name: result.name,
        school: result.school,
        grade: result.grade,
        groupName: result.groupName,
        teacherRole: result.role,
        subject: result.subject,
        seatRows: result.seatRows,
        seatCols: result.seatCols,
      );
    } else {
      await ctrl.updateManagedClass(
        existing.copyWith(
          name: result.name,
          school: result.school,
          grade: result.grade,
          groupName: result.groupName,
          teacherRole: result.role,
          subject: result.subject,
          seatRows: result.seatRows,
          seatCols: result.seatCols,
        ),
      );
    }
  }
}

class _ClassEditResult {
  const _ClassEditResult({
    required this.school,
    required this.name,
    required this.grade,
    required this.groupName,
    required this.role,
    required this.subject,
    required this.seatRows,
    required this.seatCols,
  });

  final String school;
  final String name;
  final String grade;
  final String groupName;
  final TeacherRole role;
  final String subject;
  final int seatRows;
  final int seatCols;
}

class _ClassEditSheet extends StatefulWidget {
  const _ClassEditSheet({
    required this.existing,
    required this.defaultRows,
    required this.defaultCols,
    required this.knownSchools,
  });

  final ManagedClass? existing;
  final int defaultRows;
  final int defaultCols;
  final List<String> knownSchools;

  @override
  State<_ClassEditSheet> createState() => _ClassEditSheetState();
}

class _ClassEditSheetState extends State<_ClassEditSheet> {
  late final TextEditingController _school;
  late final TextEditingController _name;
  late final TextEditingController _grade;
  late final TextEditingController _group;
  late final TextEditingController _subject;
  late final TextEditingController _rows;
  late final TextEditingController _cols;
  late TeacherRole _role;
  late String _subjectValue;

  static const _presets = ClassRepository.defaultExamSubjects;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    _school = TextEditingController(text: e?.school ?? '');
    _name = TextEditingController(text: e?.name ?? '');
    _grade = TextEditingController(text: e?.grade ?? '');
    _group = TextEditingController(text: e?.groupName ?? '');
    _subject = TextEditingController(text: e?.subject ?? '');
    _subjectValue = e?.subject.trim() ?? '';
    _role = e?.teacherRole ?? TeacherRole.homeroom;
    _rows = TextEditingController(text: '${widget.defaultRows}');
    _cols = TextEditingController(text: '${widget.defaultCols}');
  }

  @override
  void dispose() {
    _school.dispose();
    _name.dispose();
    _grade.dispose();
    _group.dispose();
    _subject.dispose();
    _rows.dispose();
    _cols.dispose();
    super.dispose();
  }

  void _pickSubject(String s) {
    setState(() {
      _subjectValue = s;
      _subject.text = s;
    });
  }

  void _submit() {
    final name = _name.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('请填写班级名称')),
      );
      return;
    }
    final subject = _subject.text.trim().isNotEmpty
        ? _subject.text.trim()
        : _subjectValue.trim();
    if (_role == TeacherRole.subject && subject.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('科任请选择或填写任教科目')),
      );
      return;
    }
    Navigator.pop(
      context,
      _ClassEditResult(
        school: _school.text.trim(),
        name: name,
        grade: _grade.text.trim(),
        groupName: _group.text.trim(),
        role: _role,
        subject: subject,
        seatRows: (int.tryParse(_rows.text) ?? 6).clamp(1, 20),
        seatCols: (int.tryParse(_cols.text) ?? 8).clamp(1, 20),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final maxH = MediaQuery.sizeOf(context).height * 0.9;
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;
    final schools = widget.knownSchools.toSet().toList()..sort();

    return Padding(
      padding: EdgeInsets.only(bottom: bottomInset),
      child: SafeArea(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxHeight: maxH),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 4, 24, 0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.existing == null ? '添加班级' : '编辑班级',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '先选学校，再填班级与任教身份',
                      style: TextStyle(
                        fontSize: 13,
                        color: AppTheme.secondaryLabel,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(24, 12, 24, 16),
                  children: [
                    TextField(
                      controller: _school,
                      decoration: const InputDecoration(
                        labelText: '学校',
                        hintText: '如：XX 中学',
                      ),
                      textInputAction: TextInputAction.next,
                    ),
                    if (schools.isNotEmpty) ...[
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          for (final s in schools)
                            ActionChip(
                              label: Text(s),
                              onPressed: () =>
                                  setState(() => _school.text = s),
                            ),
                        ],
                      ),
                    ],
                    const SizedBox(height: 20),
                    TextField(
                      controller: _name,
                      decoration: const InputDecoration(
                        labelText: '班级名称',
                        hintText: '如：高一（1）班',
                      ),
                      textInputAction: TextInputAction.next,
                    ),
                    const SizedBox(height: 20),
                    TextField(
                      controller: _grade,
                      decoration: const InputDecoration(
                        labelText: '年级',
                        hintText: '如：高一',
                      ),
                      textInputAction: TextInputAction.next,
                    ),
                    const SizedBox(height: 20),
                    TextField(
                      controller: _group,
                      decoration: const InputDecoration(
                        labelText: '分组标签（可选）',
                        hintText: '如：高一、任教',
                      ),
                    ),
                    const SizedBox(height: 28),
                    Text(
                      '我的角色',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.label,
                      ),
                    ),
                    const SizedBox(height: 10),
                    SegmentedButton<TeacherRole>(
                      segments: const [
                        ButtonSegment(
                          value: TeacherRole.homeroom,
                          label: Text('班主任'),
                        ),
                        ButtonSegment(
                          value: TeacherRole.subject,
                          label: Text('科任老师'),
                        ),
                      ],
                      selected: {_role},
                      onSelectionChanged: (s) =>
                          setState(() => _role = s.first),
                    ),
                    const SizedBox(height: 24),
                    Text(
                      '任教科目',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.label,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _role == TeacherRole.subject
                          ? '选择后显示为「语文老师」「数学老师」等'
                          : '可选；兼教某科时填写',
                      style: TextStyle(
                        fontSize: 12,
                        color: AppTheme.tertiaryLabel,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        for (final s in _presets)
                          FilterChip(
                            label: Text(s),
                            selected: _subjectValue == s,
                            onSelected: (_) => _pickSubject(s),
                          ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _subject,
                      decoration: const InputDecoration(
                        labelText: '或自行填写科目',
                        hintText: '如：信息技术、体育',
                      ),
                      onChanged: (v) =>
                          setState(() => _subjectValue = v.trim()),
                    ),
                    if (_subjectValue.isNotEmpty) ...[
                      const SizedBox(height: 10),
                      Text(
                        '预览：${ManagedClass(
                          id: '_',
                          name: 'x',
                          teacherRole: _role,
                          subject: _subjectValue,
                          createdAt: DateTime(2000),
                        ).roleLabel}',
                        style: TextStyle(
                          fontSize: 13,
                          color: AppTheme.blue,
                        ),
                      ),
                    ],
                    const SizedBox(height: 28),
                    Text(
                      '座位表尺寸',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.label,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _rows,
                            decoration:
                                const InputDecoration(labelText: '行数'),
                            keyboardType: TextInputType.number,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: TextField(
                            controller: _cols,
                            decoration:
                                const InputDecoration(labelText: '列数'),
                            keyboardType: TextInputType.number,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 8, 24, 16),
                child: FilledButton(
                  onPressed: _submit,
                  child: Text(widget.existing == null ? '创建' : '保存'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
