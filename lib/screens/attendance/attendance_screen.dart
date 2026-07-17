import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:smart_class/models/models.dart';
import 'package:smart_class/providers/class_controller.dart';
import 'package:smart_class/services/file_share.dart';
import 'package:smart_class/theme/app_icons.dart';
import 'package:smart_class/theme/app_theme.dart';
import 'package:smart_class/widgets/apple_widgets.dart';

class AttendanceScreen extends StatefulWidget {
  const AttendanceScreen({super.key});

  @override
  State<AttendanceScreen> createState() => _AttendanceScreenState();
}

class _AttendanceScreenState extends State<AttendanceScreen> {
  final _search = TextEditingController();
  String _query = '';
  bool _exporting = false;

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _exportAndShare(BuildContext context) async {
    if (_exporting) return;
    setState(() => _exporting = true);
    final ctrl = context.read<ClassController>();
    try {
      if (ctrl.students.isEmpty) {
        if (!context.mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('当前班级暂无学生，无法导出')),
        );
        return;
      }
      final path = await ctrl.exportAttendanceFile();
      final classTitle =
          ctrl.currentClass?.displayTitle ?? ctrl.profile.displayTitle;
      final dateLabel = DateFormat('yyyy年M月d日')
          .format(DateTime.tryParse(ctrl.selectedDate) ?? DateTime.now());
      await FileShare.shareXlsx(
        filePath: path,
        subject: '$classTitle 考勤 $dateLabel',
        text: '$classTitle · $dateLabel 考勤表',
      );
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('导出失败：$e')),
        );
      }
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final ctrl = context.watch<ClassController>();
    final date = DateTime.tryParse(ctrl.selectedDate) ?? DateTime.now();
    final list = ctrl.searchStudents(_query);
    final current = ctrl.currentClass;

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            LargeTitle(
              '考勤',
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextButton.icon(
                    onPressed: _exporting ? null : () => _exportAndShare(context),
                    icon: _exporting
                        ? SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: AppTheme.blue,
                            ),
                          )
                        : Icon(AppIcons.share, color: AppTheme.blue, size: 18),
                    label: const Text('导出'),
                  ),
                  TextButton(
                    onPressed: () => ctrl.markAllPresent(),
                    child: const Text('全勤'),
                  ),
                ],
              ),
            ),
            if (ctrl.classes.length > 1)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      for (final c in ctrl.classes)
                        Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: ChoiceChip(
                            label: Text(c.displayTitle),
                            selected: c.id == current?.id,
                            onSelected: (_) {
                              if (c.id != current?.id) {
                                ctrl.switchClass(c.id);
                              }
                            },
                          ),
                        ),
                    ],
                  ),
                ),
              )
            else if (current != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    current.displayTitle,
                    style: TextStyle(
                      fontSize: 14,
                      color: AppTheme.secondaryLabel,
                    ),
                  ),
                ),
              ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: Row(
                children: [
                  Expanded(
                    child: InkWell(
                      borderRadius: BorderRadius.circular(10),
                      onTap: () async {
                        final picked = await showDatePicker(
                          context: context,
                          initialDate: date,
                          firstDate: DateTime(2020),
                          lastDate: DateTime.now().add(const Duration(days: 1)),
                        );
                        if (picked != null) await ctrl.setSelectedDate(picked);
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 12),
                        decoration: BoxDecoration(
                          color: AppTheme.surface,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Row(
                          children: [
                            Icon(AppIcons.calendar,
                                color: AppTheme.blue, size: 18),
                            const SizedBox(width: 10),
                            Text(
                              DateFormat('yyyy年M月d日').format(date),
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            const Spacer(),
                            Icon(AppIcons.chevronRight,
                                color: AppTheme.quaternaryLabel, size: 18),
                          ],
                        ),
                      ),
                    ),
                  ),
                  if (ctrl.selectedDate != ctrl.todayKey)
                    TextButton(
                      onPressed: () => ctrl.setSelectedDate(DateTime.now()),
                      child: const Text('今天'),
                    ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 10),
              child: Row(
                children: [
                  for (final s in AttendanceStatus.values) ...[
                    QuietStat(label: s.label, value: '${ctrl.countStatus(s)}'),
                  ],
                ],
              ),
            ),
            SearchField(
              controller: _search,
              hint: '搜索学生',
              onChanged: (v) => setState(() => _query = v),
            ),
            Expanded(
              child: list.isEmpty
                  ? Center(
                      child: Text(
                        ctrl.classes.isEmpty ? '请先添加班级与学生' : '暂无学生',
                        style: TextStyle(color: AppTheme.tertiaryLabel),
                      ),
                    )
                  : ListView(
                      padding: const EdgeInsets.only(bottom: 24),
                      children: [
                        GroupedSection(
                          children: [
                            for (final student in list)
                              Padding(
                                padding:
                                    const EdgeInsets.fromLTRB(16, 12, 12, 12),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      student.name,
                                      style: const TextStyle(
                                        fontSize: 17,
                                        letterSpacing: -0.41,
                                      ),
                                    ),
                                    if (student.studentNo.isNotEmpty)
                                      Padding(
                                        padding: const EdgeInsets.only(top: 2),
                                        child: Text(
                                          '学号 ${student.studentNo}',
                                          style: TextStyle(
                                            fontSize: 13,
                                            color: AppTheme.tertiaryLabel,
                                          ),
                                        ),
                                      ),
                                    const SizedBox(height: 8),
                                    Wrap(
                                      spacing: 6,
                                      children: [
                                        for (final status
                                            in AttendanceStatus.values)
                                          ChoiceChip(
                                            label: Text(status.label),
                                            selected: ctrl.attendanceMap[
                                                    student.id] ==
                                                status,
                                            onSelected: (_) =>
                                                ctrl.markAttendance(
                                              student.id,
                                              status,
                                            ),
                                          ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                          ],
                        ),
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
