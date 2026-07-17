import 'package:flutter/material.dart';
import 'package:smart_class/data/class_repository.dart';
import 'package:smart_class/models/models.dart';
import 'package:smart_class/theme/app_theme.dart';
import 'package:smart_class/widgets/apple_widgets.dart';

class ClassEditResult {
  const ClassEditResult({
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

/// 添加 / 编辑班级（全屏页）
class ClassEditScreen extends StatefulWidget {
  const ClassEditScreen({
    super.key,
    this.existing,
    required this.defaultRows,
    required this.defaultCols,
    required this.knownSchools,
  });

  final ManagedClass? existing;
  final int defaultRows;
  final int defaultCols;
  final List<String> knownSchools;

  @override
  State<ClassEditScreen> createState() => _ClassEditScreenState();
}

class _ClassEditScreenState extends State<ClassEditScreen> {
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
  static const _fieldGap = 20.0;

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
    if (_role == TeacherRole.homeroom && subject.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('班主任也请填写任教科目')),
      );
      return;
    }
    Navigator.pop(
      context,
      ClassEditResult(
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
    final schools = widget.knownSchools.toSet().toList()..sort();
    final isNew = widget.existing == null;

    return Scaffold(
      appBar: PageAppBar(
        title: Text(isNew ? '添加班级' : '编辑班级'),
      ),
      body: ListView(
        padding: EdgeInsets.only(
          left: 20,
          right: 20,
          top: 8,
          bottom: MediaQuery.viewInsetsOf(context).bottom + 24,
        ),
        children: [
          Text(
            '先选学校，再填班级与任教身份',
            style: TextStyle(
              fontSize: 13,
              color: AppTheme.secondaryLabel,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 20),
          TextField(
            controller: _school,
            decoration: const InputDecoration(
              labelText: '学校',
              hintText: '如：XX 中学',
              border: OutlineInputBorder(),
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
                    onPressed: () => setState(() => _school.text = s),
                  ),
              ],
            ),
          ],
          const SizedBox(height: _fieldGap),
          TextField(
            controller: _name,
            decoration: const InputDecoration(
              labelText: '班级名称',
              hintText: '如：高一（1）班',
              border: OutlineInputBorder(),
            ),
            textInputAction: TextInputAction.next,
          ),
          const SizedBox(height: _fieldGap),
          TextField(
            controller: _grade,
            decoration: const InputDecoration(
              labelText: '年级',
              hintText: '如：高一',
              border: OutlineInputBorder(),
            ),
            textInputAction: TextInputAction.next,
          ),
          const SizedBox(height: _fieldGap),
          TextField(
            controller: _group,
            decoration: const InputDecoration(
              labelText: '分组标签（可选）',
              hintText: '如：高一、任教',
              border: OutlineInputBorder(),
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
            onSelectionChanged: (s) => setState(() => _role = s.first),
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
                : '班主任也担任授课，请填写任教科目',
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
              border: OutlineInputBorder(),
            ),
            onChanged: (v) => setState(() => _subjectValue = v.trim()),
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
                  decoration: const InputDecoration(
                    labelText: '行数',
                    border: OutlineInputBorder(),
                  ),
                  keyboardType: TextInputType.number,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: TextField(
                  controller: _cols,
                  decoration: const InputDecoration(
                    labelText: '列数',
                    border: OutlineInputBorder(),
                  ),
                  keyboardType: TextInputType.number,
                ),
              ),
            ],
          ),
          const SizedBox(height: 28),
          FilledButton(
            onPressed: _submit,
            child: Text(isNew ? '创建' : '保存'),
          ),
        ],
      ),
    );
  }
}
