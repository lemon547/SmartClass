import 'package:smart_class/theme/app_icons.dart';
import 'package:flutter/material.dart';

import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:smart_class/models/models.dart';
import 'package:smart_class/providers/class_controller.dart';
import 'package:smart_class/theme/app_theme.dart';
import 'package:smart_class/widgets/apple_widgets.dart';
import 'package:smart_class/widgets/excel_import_sheet.dart';

class AttendanceScreen extends StatefulWidget {
  const AttendanceScreen({super.key});

  @override
  State<AttendanceScreen> createState() => _AttendanceScreenState();
}

class _AttendanceScreenState extends State<AttendanceScreen> {
  final _search = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ctrl = context.watch<ClassController>();
    final date = DateTime.tryParse(ctrl.selectedDate) ?? DateTime.now();
    final list = ctrl.searchStudents(_query);

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            LargeTitle(
              '考勤',
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    tooltip: '导入导出',
                    onPressed: () => showExcelImportActions(
                      context: context,
                      title: '考勤',
                      downloadTemplate: () => context
                          .read<ClassController>()
                          .exportAttendanceTemplateFile(),
                      importBytes: (bytes, _) => context
                          .read<ClassController>()
                          .importAttendanceFromBytes(bytes),
                    ),
                    icon: Icon(AppIcons.moreVert, color: AppTheme.blue),
                  ),
                  TextButton(
                    onPressed: () => ctrl.markAllPresent(),
                    child: const Text('全勤'),
                  ),
                ],
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
                      child: Text('暂无学生',
                          style: TextStyle(color: AppTheme.tertiaryLabel)),
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
