import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:smart_class/models/models.dart';
import 'package:smart_class/providers/class_controller.dart';
import 'package:smart_class/theme/app_theme.dart';
import 'package:smart_class/widgets/apple_widgets.dart';

class StudentDetailScreen extends StatefulWidget {
  const StudentDetailScreen({super.key, required this.studentId});

  final String studentId;

  @override
  State<StudentDetailScreen> createState() => _StudentDetailScreenState();
}

class _StudentDetailScreenState extends State<StudentDetailScreen> {
  List<AttendanceRecord> _att = [];
  List<PointRecord> _pts = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final ctrl = context.read<ClassController>();
    final att = await ctrl.attendanceOf(widget.studentId);
    final pts = await ctrl.pointsOf(widget.studentId);
    if (!mounted) return;
    setState(() {
      _att = att;
      _pts = pts;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final ctrl = context.watch<ClassController>();
    final s = ctrl.studentById(widget.studentId);
    if (s == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('学生')),
        body: const Center(child: Text('学生不存在')),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(s.name),
        actions: [
          TextButton(
            onPressed: () => _edit(context, s),
            child: const Text('编辑'),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator.adaptive())
          : ListView(
              padding: const EdgeInsets.only(bottom: 28),
              children: [
                const SizedBox(height: 8),
                GroupedSection(
                  header: '资料',
                  children: [
                    GroupedTile(title: '学号', trailing: Text(s.studentNo.isEmpty ? '—' : s.studentNo)),
                    GroupedTile(title: '小组', trailing: Text(s.groupName.isEmpty ? '—' : s.groupName)),
                    GroupedTile(
                      title: '班委',
                      trailing: Text(s.role.isEmpty ? '—' : s.role),
                    ),
                    GroupedTile(
                      title: '生日',
                      trailing: Text(s.birthday.isEmpty ? '—' : s.birthday),
                    ),
                    GroupedTile(title: '性别', trailing: Text(s.gender)),
                    GroupedTile(title: '电话', trailing: Text(s.phone.isEmpty ? '—' : s.phone)),
                    GroupedTile(
                      title: '积分',
                      subtitle: rankTitle(s.points),
                      trailing: Text('${s.points}'),
                    ),
                    if (s.note.isNotEmpty)
                      GroupedTile(title: '备注', subtitle: s.note),
                  ],
                ),
                const SizedBox(height: 18),
                GroupedSection(
                  header: '积分记录',
                  children: [
                    if (_pts.isEmpty)
                      Padding(
                        padding: EdgeInsets.all(18),
                        child: Text('暂无', style: TextStyle(color: AppTheme.tertiaryLabel)),
                      )
                    else
                      for (final r in _pts.take(20))
                        GroupedTile(
                          title: r.reason,
                          subtitle: DateFormat('M/d HH:mm').format(r.createdAt),
                          trailing: Text(
                            '${r.delta > 0 ? '+' : ''}${r.delta}',
                            style: const TextStyle(fontSize: 17),
                          ),
                        ),
                  ],
                ),
                const SizedBox(height: 18),
                GroupedSection(
                  header: '考勤记录',
                  children: [
                    if (_att.isEmpty)
                      Padding(
                        padding: EdgeInsets.all(18),
                        child: Text('暂无', style: TextStyle(color: AppTheme.tertiaryLabel)),
                      )
                    else
                      for (final r in _att.take(20))
                        GroupedTile(
                          title: r.date,
                          trailing: Text(r.status.label),
                        ),
                  ],
                ),
              ],
            ),
    );
  }

  Future<void> _edit(BuildContext context, Student s) async {
    final ctrl = context.read<ClassController>();
    final name = TextEditingController(text: s.name);
    final no = TextEditingController(text: s.studentNo);
    final phone = TextEditingController(text: s.phone);
    final note = TextEditingController(text: s.note);
    final group = TextEditingController(text: s.groupName);
    var gender = s.gender;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setState) {
            return Padding(
              padding: EdgeInsets.only(
                left: 20,
                right: 20,
                top: 16,
                bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
              ),
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text('编辑', style: Theme.of(ctx).textTheme.titleLarge),
                    const SizedBox(height: 12),
                    TextField(controller: name, decoration: const InputDecoration(labelText: '姓名')),
                    const SizedBox(height: 8),
                    TextField(controller: no, decoration: const InputDecoration(labelText: '学号')),
                    const SizedBox(height: 8),
                    TextField(controller: group, decoration: const InputDecoration(labelText: '小组')),
                    const SizedBox(height: 8),
                    TextField(controller: phone, decoration: const InputDecoration(labelText: '电话')),
                    const SizedBox(height: 8),
                    TextField(controller: note, decoration: const InputDecoration(labelText: '备注')),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 8,
                      children: [
                        for (final g in ['男', '女', '未知'])
                          ChoiceChip(
                            label: Text(g),
                            selected: gender == g,
                            onSelected: (_) => setState(() => gender = g),
                          ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    FilledButton(
                      onPressed: () async {
                        await ctrl.saveStudent(
                          id: s.id,
                          name: name.text,
                          studentNo: no.text,
                          phone: phone.text,
                          note: note.text,
                          gender: gender,
                          groupName: group.text,
                        );
                        if (ctx.mounted) Navigator.pop(ctx);
                        await _load();
                      },
                      child: const Text('保存'),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}
