import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:smart_class/models/models.dart';
import 'package:smart_class/providers/class_controller.dart';
import 'package:smart_class/screens/grades/exam_detail_screen.dart';
import 'package:smart_class/screens/grades/exam_hub_screen.dart';
import 'package:smart_class/screens/students/honor_editor.dart';
import 'package:smart_class/screens/students/student_edit_screen.dart';
import 'package:smart_class/services/file_share.dart';
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
  List<StudentHonor> _honors = [];
  bool _loading = true;
  bool _sharing = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final ctrl = context.read<ClassController>();
    final att = await ctrl.attendanceOf(widget.studentId);
    final pts = await ctrl.pointsOf(widget.studentId);
    final honors = await ctrl.honorsOf(widget.studentId);
    await ctrl.ensureAllExamScores();
    if (!mounted) return;
    setState(() {
      _att = att;
      _pts = pts;
      _honors = honors;
      _loading = false;
    });
  }

  Future<void> _reloadHonors() async {
    final honors =
        await context.read<ClassController>().honorsOf(widget.studentId);
    if (!mounted) return;
    setState(() => _honors = honors);
  }

  @override
  Widget build(BuildContext context) {
    final ctrl = context.watch<ClassController>();
    final s = ctrl.studentById(widget.studentId);
    if (s == null) {
      return Scaffold(
        appBar: PageAppBar(title: const Text('学生')),
        body: const Center(child: Text('学生不存在')),
      );
    }

    return Scaffold(
      appBar: PageAppBar(
        title: Text(s.name),
        actions: [
          IconButton(
            tooltip: '分享学期汇总',
            onPressed: _sharing ? null : () => _shareReport(context, s),
            icon: _sharing
                ? SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: AppTheme.blue,
                    ),
                  )
                : const Icon(AppIcons.share),
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
                    GroupedTile(
                      title: '学号',
                      trailing: Text(s.studentNo.isEmpty ? '—' : s.studentNo),
                    ),
                    GroupedTile(
                      title: '小组',
                      trailing: Text(s.groupName.isEmpty ? '—' : s.groupName),
                    ),
                    GroupedTile(
                      title: '班级职务',
                      subtitle: s.role.isEmpty ? null : s.role,
                      trailing: s.role.isEmpty
                          ? const Text('普通学生')
                          : Icon(AppIcons.trophy, size: 18, color: AppTheme.blue),
                    ),
                    GroupedTile(
                      title: '生日',
                      trailing: Text(s.birthday.isEmpty ? '—' : s.birthday),
                    ),
                    GroupedTile(
                      title: '性别',
                      trailing: Text(
                        s.gender == '男' || s.gender == '女' ? s.gender : '—',
                      ),
                    ),
                    GroupedTile(
                      title: '电话',
                      trailing: Text(s.phone.isEmpty ? '—' : s.phone),
                    ),
                    GroupedTile(
                      title: '家庭住址',
                      subtitle: s.address.isEmpty ? null : s.address,
                      trailing: s.address.isEmpty ? const Text('—') : null,
                    ),
                    GroupedTile(
                      title: '积分',
                      trailing: Text('${s.points}'),
                    ),
                    if (s.note.isNotEmpty)
                      GroupedTile(title: '备注', subtitle: s.note),
                  ],
                ),
                const SizedBox(height: 18),
                GroupedSection(
                  header: '荣誉记录 · ${_honors.length}',
                  footer: '点按编辑，长按删除',
                  children: [
                    GroupedTile(
                      title: '添加荣誉',
                      leading: Icon(AppIcons.plus, color: AppTheme.blue),
                      onTap: () async {
                        await showHonorEditor(
                          context,
                          studentId: widget.studentId,
                        );
                        await _reloadHonors();
                      },
                    ),
                    if (_honors.isEmpty)
                      Padding(
                        padding: const EdgeInsets.all(18),
                        child: Text(
                          '暂无荣誉记录',
                          style: TextStyle(color: AppTheme.tertiaryLabel),
                        ),
                      )
                    else
                      for (final h in _honors)
                        GroupedTile(
                          title: h.title,
                          subtitle: [
                            if (h.date.isNotEmpty) h.date,
                            if (h.level.isNotEmpty) h.level,
                            if (h.note.isNotEmpty) h.note,
                          ].join(' · '),
                          onTap: () async {
                            await showHonorEditor(
                              context,
                              studentId: widget.studentId,
                              existing: h,
                            );
                            await _reloadHonors();
                          },
                          onLongPress: () async {
                            final ok = await showDialog<bool>(
                              context: context,
                              builder: (ctx) => AlertDialog(
                                title: const Text('删除荣誉？'),
                                content: Text(h.title),
                                actions: [
                                  TextButton(
                                    onPressed: () => Navigator.pop(ctx, false),
                                    child: const Text('取消'),
                                  ),
                                  TextButton(
                                    onPressed: () => Navigator.pop(ctx, true),
                                    child: const Text('删除'),
                                  ),
                                ],
                              ),
                            );
                            if (ok == true && context.mounted) {
                              await context
                                  .read<ClassController>()
                                  .deleteStudentHonor(h.id);
                              await _reloadHonors();
                            }
                          },
                        ),
                  ],
                ),
                const SizedBox(height: 18),
                Builder(
                  builder: (context) {
                    final grades = ctrl.examScoresOfStudent(widget.studentId);
                    return GroupedSection(
                      header: '成绩 · ${grades.length}',
                      footer: grades.isEmpty
                          ? '该生尚未录入考试成绩'
                          : '点进查看本场考试功能',
                      children: [
                        if (grades.isEmpty)
                          Padding(
                            padding: const EdgeInsets.all(18),
                            child: Text(
                              '暂无',
                              style: TextStyle(color: AppTheme.tertiaryLabel),
                            ),
                          )
                        else
                          for (final (exam, score) in grades.take(20))
                            GroupedTile(
                              title: exam.title,
                              subtitle: '${exam.category} · ${exam.examDate}',
                              trailing: Text(
                                ExamDetailScreen.fmt(score.total),
                                style: const TextStyle(
                                  fontSize: 17,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              onTap: () => ExamHubScreen.push(
                                context,
                                examId: exam.id,
                              ),
                            ),
                      ],
                    );
                  },
                ),
                const SizedBox(height: 18),
                GroupedSection(
                  header: '积分记录',
                  children: [
                    if (_pts.isEmpty)
                      Padding(
                        padding: const EdgeInsets.all(18),
                        child: Text(
                          '暂无',
                          style: TextStyle(color: AppTheme.tertiaryLabel),
                        ),
                      )
                    else
                      for (final r in _pts.take(20))
                        GroupedTile(
                          title: r.reason,
                          subtitle:
                              DateFormat('M/d HH:mm').format(r.createdAt),
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
                        padding: const EdgeInsets.all(18),
                        child: Text(
                          '暂无',
                          style: TextStyle(color: AppTheme.tertiaryLabel),
                        ),
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

  Future<void> _shareReport(BuildContext context, Student s) async {
    setState(() => _sharing = true);
    try {
      final ctrl = context.read<ClassController>();
      final path = await ctrl.exportStudentSemesterReportFile(s.id);
      final classTitle =
          ctrl.currentClass?.displayTitle ?? ctrl.profile.displayTitle;
      await FileShare.shareXlsx(
        filePath: path,
        subject: '$classTitle · ${s.name} 学期汇总',
        text: '${s.name} 本学期个人汇总',
      );
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('分享失败：$e')),
        );
      }
    } finally {
      if (mounted) setState(() => _sharing = false);
    }
  }

  Future<void> _edit(BuildContext context, Student s) async {
    await StudentEditScreen.push(context, student: s);
    if (context.mounted) await _load();
  }
}
