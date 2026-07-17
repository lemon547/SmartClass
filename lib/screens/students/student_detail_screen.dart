import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:smart_class/models/models.dart';
import 'package:smart_class/providers/class_controller.dart';
import 'package:smart_class/theme/app_icons.dart';
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
          IconButton(
            tooltip: '导出学期汇总',
            onPressed: () async {
              try {
                final path = await context
                    .read<ClassController>()
                    .exportStudentSemesterReportFile(s.id);
                await Clipboard.setData(ClipboardData(text: path));
                if (!context.mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('已导出（路径已复制）：\n$path')),
                );
              } catch (e) {
                if (!context.mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('导出失败：$e')),
                );
              }
            },
            icon: const Icon(AppIcons.share),
          ),
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
                    GroupedTile(title: '性别', trailing: Text(
                      s.gender == '男' || s.gender == '女' ? s.gender : '—',
                    )),
                    GroupedTile(title: '电话', trailing: Text(s.phone.isEmpty ? '—' : s.phone)),
                    GroupedTile(
                      title: '家庭住址',
                      subtitle: s.address.isEmpty ? null : s.address,
                      trailing: s.address.isEmpty ? const Text('—') : null,
                    ),
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
    final birthday = TextEditingController(text: s.birthday);
    final address = TextEditingController(text: s.address);
    var gender = (s.gender == '男' || s.gender == '女') ? s.gender : '';
    final selectedRoles = Student.splitRoles(s.role).toSet();
    var roleOptions = List<String>.from(ctrl.rolePresets);
    for (final r in selectedRoles) {
      if (!roleOptions.contains(r)) roleOptions.add(r);
    }

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      isDismissible: true,
      enableDrag: true,
      showDragHandle: true,
      useSafeArea: true,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setState) {
            return Padding(
              padding: EdgeInsets.only(
                left: 20,
                right: 20,
                bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
              ),
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.sizeOf(ctx).height * 0.88,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text('编辑',
                              style: Theme.of(ctx).textTheme.titleLarge),
                        ),
                        IconButton(
                          tooltip: '关闭',
                          onPressed: () => Navigator.pop(ctx),
                          icon: Icon(AppIcons.close, color: AppTheme.blue),
                        ),
                      ],
                    ),
                    Expanded(
                      child: SingleChildScrollView(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            TextField(
                                controller: name,
                                decoration:
                                    const InputDecoration(labelText: '姓名')),
                            const SizedBox(height: 8),
                            TextField(
                                controller: no,
                                decoration:
                                    const InputDecoration(labelText: '学号')),
                            const SizedBox(height: 8),
                            TextField(
                                controller: group,
                                decoration:
                                    const InputDecoration(labelText: '小组')),
                            const SizedBox(height: 8),
                            TextField(
                                controller: birthday,
                                decoration: const InputDecoration(
                                  labelText: '生日（月-日）',
                                  hintText: '如 03-15',
                                )),
                            const SizedBox(height: 8),
                            TextField(
                                controller: phone,
                                decoration:
                                    const InputDecoration(labelText: '电话')),
                            const SizedBox(height: 8),
                            TextField(
                                controller: address,
                                decoration:
                                    const InputDecoration(labelText: '家庭住址'),
                                minLines: 1,
                                maxLines: 2),
                            const SizedBox(height: 8),
                            TextField(
                                controller: note,
                                decoration:
                                    const InputDecoration(labelText: '备注')),
                            const SizedBox(height: 12),
                            Text('班委（可多选）',
                                style: TextStyle(
                                    fontSize: 13,
                                    color: AppTheme.tertiaryLabel)),
                            const SizedBox(height: 6),
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: [
                                FilterChip(
                                  label: const Text('无'),
                                  selected: selectedRoles.isEmpty,
                                  onSelected: (_) => setState(
                                      () => selectedRoles.clear()),
                                ),
                                for (final r in roleOptions)
                                  FilterChip(
                                    label: Text(r),
                                    selected: selectedRoles.contains(r),
                                    onSelected: (on) => setState(() {
                                      if (on) {
                                        selectedRoles.add(r);
                                      } else {
                                        selectedRoles.remove(r);
                                      }
                                    }),
                                  ),
                                ActionChip(
                                  avatar: Icon(AppIcons.plus,
                                      size: 16, color: AppTheme.blue),
                                  label: const Text('添加班委'),
                                  onPressed: () async {
                                    final added =
                                        await _promptCustomRole(ctx);
                                    if (added == null || added.isEmpty) {
                                      return;
                                    }
                                    await ctrl.addRolePreset(added);
                                    setState(() {
                                      if (!roleOptions.contains(added)) {
                                        roleOptions = [
                                          ...roleOptions,
                                          added
                                        ];
                                      }
                                      selectedRoles.add(added);
                                    });
                                  },
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            Text('性别',
                                style: TextStyle(
                                    fontSize: 13,
                                    color: AppTheme.tertiaryLabel)),
                            const SizedBox(height: 6),
                            Wrap(
                              spacing: 8,
                              children: [
                                for (final g in ['男', '女'])
                                  ChoiceChip(
                                    label: Text(g),
                                    selected: gender == g,
                                    onSelected: (_) =>
                                        setState(() => gender = g),
                                  ),
                              ],
                            ),
                            const SizedBox(height: 16),
                          ],
                        ),
                      ),
                    ),
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
                          role: Student.joinRoles(selectedRoles),
                          birthday: birthday.text,
                          address: address.text,
                        );
                        if (ctx.mounted) Navigator.pop(ctx);
                        await _load();
                      },
                      child: const Text('保存'),
                    ),
                    TextButton(
                      onPressed: () => Navigator.pop(ctx),
                      child: const Text('取消'),
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

  Future<String?> _promptCustomRole(BuildContext context) async {
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
}
