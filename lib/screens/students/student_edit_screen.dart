import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:smart_class/models/models.dart';
import 'package:smart_class/providers/class_controller.dart';
import 'package:smart_class/theme/app_icons.dart';
import 'package:smart_class/theme/app_theme.dart';
import 'package:smart_class/widgets/apple_widgets.dart';

class StudentEditScreen extends StatefulWidget {
  const StudentEditScreen({super.key, this.student});

  final Student? student;

  static Future<void> push(BuildContext context, {Student? student}) {
    return Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => StudentEditScreen(student: student)),
    );
  }

  @override
  State<StudentEditScreen> createState() => _StudentEditScreenState();
}

class _StudentEditScreenState extends State<StudentEditScreen> {
  late final TextEditingController _name;
  late final TextEditingController _no;
  late final TextEditingController _phone;
  late final TextEditingController _note;
  late final TextEditingController _group;
  late final TextEditingController _birthday;
  late final TextEditingController _address;
  late String _gender;
  late Set<String> _selectedRoles;
  late List<String> _roleOptions;

  @override
  void initState() {
    super.initState();
    final s = widget.student;
    final ctrl = context.read<ClassController>();
    _name = TextEditingController(text: s?.name ?? '');
    _no = TextEditingController(text: s?.studentNo ?? '');
    _phone = TextEditingController(text: s?.phone ?? '');
    _note = TextEditingController(text: s?.note ?? '');
    _group = TextEditingController(text: s?.groupName ?? '');
    _birthday = TextEditingController(text: s?.birthday ?? '');
    _address = TextEditingController(text: s?.address ?? '');
    _gender = (s?.gender == '男' || s?.gender == '女') ? s!.gender : '';
    _selectedRoles = Student.splitRoles(s?.role ?? '').toSet();
    _roleOptions = List<String>.from(ctrl.rolePresets);
    for (final r in _selectedRoles) {
      if (!_roleOptions.contains(r)) _roleOptions.add(r);
    }
  }

  @override
  void dispose() {
    _name.dispose();
    _no.dispose();
    _phone.dispose();
    _note.dispose();
    _group.dispose();
    _birthday.dispose();
    _address.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_name.text.trim().isEmpty) return;
    await context.read<ClassController>().saveStudent(
          id: widget.student?.id,
          name: _name.text,
          studentNo: _no.text,
          phone: _phone.text,
          note: _note.text,
          gender: _gender,
          groupName: _group.text,
          role: Student.joinRoles(_selectedRoles),
          birthday: _birthday.text,
          address: _address.text,
        );
    if (mounted) Navigator.pop(context);
  }

  Future<String?> _promptCustomRole() async {
    final text = TextEditingController();
    final ok = await showCupertinoDialog<bool>(
      context: context,
      builder: (ctx) => CupertinoAlertDialog(
        title: const Text('添加班委'),
        content: Padding(
          padding: const EdgeInsets.only(top: 12),
          child: CupertinoTextField(
            controller: text,
            placeholder: '如：宣传委员',
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
            child: const Text('添加'),
          ),
        ],
      ),
    );
    final value = text.text.trim();
    text.dispose();
    if (ok != true || value.isEmpty) return null;
    return value;
  }

  @override
  Widget build(BuildContext context) {
    final ctrl = context.read<ClassController>();
    return Scaffold(
      appBar: PageAppBar(
        title: Text(widget.student == null ? '添加学生' : '编辑学生'),
        actions: [TextButton(onPressed: _save, child: const Text('保存'))],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
        children: [
          TextField(
            controller: _name,
            decoration: const InputDecoration(labelText: '姓名'),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _no,
            decoration: const InputDecoration(labelText: '学号'),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _group,
            decoration: const InputDecoration(labelText: '小组'),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _birthday,
            decoration: const InputDecoration(
              labelText: '生日（月-日）',
              hintText: '如 03-15',
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _phone,
            decoration: const InputDecoration(labelText: '家长电话'),
            keyboardType: TextInputType.phone,
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _address,
            decoration: const InputDecoration(labelText: '家庭住址'),
            minLines: 1,
            maxLines: 2,
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _note,
            decoration: const InputDecoration(labelText: '备注'),
          ),
          const SizedBox(height: 16),
          Text('班委（可多选）',
              style: TextStyle(fontSize: 13, color: AppTheme.tertiaryLabel)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              FilterChip(
                label: const Text('无'),
                selected: _selectedRoles.isEmpty,
                showCheckmark: false,
                onSelected: (_) => setState(() => _selectedRoles.clear()),
              ),
              for (final r in _roleOptions)
                FilterChip(
                  label: Text(r),
                  selected: _selectedRoles.contains(r),
                  showCheckmark: false,
                  onSelected: (on) => setState(() {
                    if (on) {
                      _selectedRoles.add(r);
                    } else {
                      _selectedRoles.remove(r);
                    }
                  }),
                ),
              ActionChip(
                avatar: Icon(AppIcons.plus, size: 16, color: AppTheme.blue),
                label: const Text('添加班委'),
                onPressed: () async {
                  final added = await _promptCustomRole();
                  if (added == null) return;
                  await ctrl.addRolePreset(added);
                  setState(() {
                    if (!_roleOptions.contains(added)) {
                      _roleOptions = [..._roleOptions, added];
                    }
                    _selectedRoles.add(added);
                  });
                },
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text('性别',
              style: TextStyle(fontSize: 13, color: AppTheme.tertiaryLabel)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            children: [
              for (final g in ['男', '女'])
                ChoiceChip(
                  label: Text(g),
                  selected: _gender == g,
                  showCheckmark: false,
                  onSelected: (_) => setState(() => _gender = g),
                ),
            ],
          ),
          const SizedBox(height: 24),
          FilledButton(onPressed: _save, child: const Text('保存')),
        ],
      ),
    );
  }
}
