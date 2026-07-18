import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:smart_class/models/models.dart';
import 'package:smart_class/providers/class_controller.dart';
import 'package:smart_class/services/file_share.dart';
import 'package:smart_class/theme/app_icons.dart';
import 'package:smart_class/theme/app_theme.dart';
import 'package:smart_class/widgets/apple_widgets.dart';
import 'package:smart_class/widgets/class_switcher_sheet.dart';
import 'package:smart_class/widgets/date_picker_sheet.dart';

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

  Future<void> _pickDate(ClassController ctrl, DateTime date) async {
    final picked = await showAppDatePicker(
      context,
      initialDate: date,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 1)),
    );
    if (picked != null) await ctrl.setSelectedDate(picked);
  }

  Future<void> _editRemark(
    BuildContext context,
    ClassController ctrl,
    Student student,
    String initial,
  ) async {
    final input = TextEditingController(text: initial);
    final saved = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (ctx) {
        return Padding(
          padding: EdgeInsets.only(
            left: 20,
            right: 20,
            top: 4,
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                '${student.name} · 考勤备注',
                style: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                '如：病假条已交、家长已请假、迟到原因等',
                style: TextStyle(fontSize: 13, color: AppTheme.secondaryLabel),
              ),
              const SizedBox(height: 14),
              TextField(
                controller: input,
                autofocus: true,
                maxLines: 3,
                minLines: 1,
                decoration: const InputDecoration(
                  hintText: '输入备注（可留空清除）',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: () => Navigator.pop(ctx, input.text.trim()),
                child: const Text('保存'),
              ),
              if (initial.trim().isNotEmpty) ...[
                const SizedBox(height: 8),
                TextButton(
                  onPressed: () => Navigator.pop(ctx, ''),
                  child: const Text('清除备注'),
                ),
              ],
            ],
          ),
        );
      },
    );
    await Future<void>.delayed(Duration.zero);
    input.dispose();
    if (saved == null || !context.mounted) return;
    await ctrl.setAttendanceRemark(student.id, saved);
  }

  @override
  Widget build(BuildContext context) {
    final ctrl = context.watch<ClassController>();
    final date = DateTime.tryParse(ctrl.selectedDate) ?? DateTime.now();
    final list = ctrl.searchStudents(_query);
    final isToday = ctrl.selectedDate == ctrl.todayKey;
    final classTitle =
        ctrl.currentClass?.displayTitle ?? ctrl.profile.displayTitle;

    return Scaffold(
      backgroundColor: AppTheme.bg,
      appBar: PageAppBar(
        title: const Text('考勤'),
        actions: [
          IconButton(
            tooltip: '导出',
            onPressed: _exporting ? null : () => _exportAndShare(context),
            icon: _exporting
                ? SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: AppTheme.blue,
                    ),
                  )
                : Icon(AppIcons.share, color: AppTheme.blue),
          ),
          TextButton(
            onPressed: () => ctrl.markAllPresent(),
            child: const Text('全勤'),
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: Row(
              children: [
                Expanded(
                  child: InkWell(
                    onTap: ctrl.classes.length > 1
                        ? () => showClassSwitcherSheet(context)
                        : null,
                    borderRadius: BorderRadius.circular(8),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Row(
                        children: [
                          Text(
                            classTitle,
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          if (ctrl.classes.length > 1) ...[
                            const SizedBox(width: 4),
                            Icon(
                              Icons.expand_more,
                              size: 18,
                              color: AppTheme.tertiaryLabel,
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ),
                if (!isToday)
                  TextButton(
                    onPressed: () => ctrl.setSelectedDate(DateTime.now()),
                    child: const Text('今天'),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          WeekDateStrip(
            selected: date,
            onChanged: (d) => ctrl.setSelectedDate(d),
            onOpenCalendar: () => _pickDate(ctrl, date),
          ),
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                isToday
                    ? '今天 · ${DateFormat('M月d日').format(date)}'
                    : DateFormat('yyyy年M月d日 EEEE', 'zh_CN').format(date),
                style: TextStyle(
                  fontSize: 13,
                  color: AppTheme.tertiaryLabel,
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          _SummaryBar(ctrl: ctrl),
          const SizedBox(height: 8),
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
                    padding: const EdgeInsets.only(bottom: 28),
                    children: [
                      GroupedSection(
                        header: '登记 · ${list.length} 人',
                        children: [
                          for (final student in list)
                            _StudentAttendanceRow(
                              student: student,
                              status: ctrl.attendanceMap[student.id] ??
                                  AttendanceStatus.present,
                              remark:
                                  ctrl.attendanceRemarkMap[student.id] ?? '',
                              onChanged: (s) =>
                                  ctrl.markAttendance(student.id, s),
                              onEditRemark: () => _editRemark(
                                context,
                                ctrl,
                                student,
                                ctrl.attendanceRemarkMap[student.id] ?? '',
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }
}

class _SummaryBar extends StatelessWidget {
  const _SummaryBar({required this.ctrl});

  final ClassController ctrl;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: AppTheme.surface,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 14),
          child: Row(
            children: [
              for (var i = 0; i < AttendanceStatus.values.length; i++) ...[
                if (i > 0)
                  SizedBox(
                    height: 28,
                    child: VerticalDivider(
                      width: 1,
                      thickness: 0.5,
                      color: AppTheme.separator,
                    ),
                  ),
                Expanded(
                  child: _SummaryCell(
                    label: AttendanceStatus.values[i].label,
                    value: '${ctrl.countStatus(AttendanceStatus.values[i])}',
                    color: _statusColor(AttendanceStatus.values[i]),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _SummaryCell extends StatelessWidget {
  const _SummaryCell({
    required this.label,
    required this.value,
    required this.color,
  });

  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w600,
            letterSpacing: -0.5,
            color: color,
            height: 1.1,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: TextStyle(fontSize: 12, color: AppTheme.tertiaryLabel),
        ),
      ],
    );
  }
}

class _StudentAttendanceRow extends StatelessWidget {
  const _StudentAttendanceRow({
    required this.student,
    required this.status,
    required this.remark,
    required this.onChanged,
    required this.onEditRemark,
  });

  final Student student;
  final AttendanceStatus status;
  final String remark;
  final ValueChanged<AttendanceStatus> onChanged;
  final VoidCallback onEditRemark;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 8, 10),
      child: Row(
        children: [
          StudentAvatar(name: student.name, size: 36),
          const SizedBox(width: 12),
          Expanded(
            child: InkWell(
              onTap: onEditRemark,
              borderRadius: BorderRadius.circular(8),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 2),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      student.name,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                        letterSpacing: -0.3,
                      ),
                    ),
                    if (remark.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        remark,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 13,
                          color: AppTheme.blue,
                        ),
                      ),
                    ] else if (student.studentNo.isNotEmpty)
                      Text(
                        student.studentNo,
                        style: TextStyle(
                          fontSize: 13,
                          color: AppTheme.tertiaryLabel,
                        ),
                      )
                    else
                      Text(
                        '点姓名可写备注',
                        style: TextStyle(
                          fontSize: 12,
                          color: AppTheme.quaternaryLabel,
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
          IconButton(
            tooltip: '备注',
            onPressed: onEditRemark,
            icon: Icon(
              remark.isNotEmpty ? AppIcons.message : AppIcons.plus,
              size: 18,
              color: remark.isNotEmpty ? AppTheme.blue : AppTheme.tertiaryLabel,
            ),
          ),
          _StatusSegment(
            value: status,
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }
}

class _StatusSegment extends StatelessWidget {
  const _StatusSegment({
    required this.value,
    required this.onChanged,
  });

  final AttendanceStatus value;
  final ValueChanged<AttendanceStatus> onChanged;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppTheme.fill,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final s in AttendanceStatus.values)
            _SegmentItem(
              label: s.shortLabel,
              selected: value == s,
              color: _statusColor(s),
              onTap: () => onChanged(s),
            ),
        ],
      ),
    );
  }
}

class _SegmentItem extends StatelessWidget {
  const _SegmentItem({
    required this.label,
    required this.selected,
    required this.color,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? color : Colors.transparent,
      borderRadius: BorderRadius.circular(7),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(7),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
              color: selected ? Colors.white : AppTheme.secondaryLabel,
            ),
          ),
        ),
      ),
    );
  }
}

extension on AttendanceStatus {
  String get shortLabel => switch (this) {
        AttendanceStatus.present => '到',
        AttendanceStatus.late => '迟',
        AttendanceStatus.leave => '假',
        AttendanceStatus.absent => '缺',
      };
}

Color _statusColor(AttendanceStatus status) => switch (status) {
      AttendanceStatus.present => const Color(0xFF34C759),
      AttendanceStatus.late => const Color(0xFFFF9500),
      AttendanceStatus.leave => AppTheme.blue,
      AttendanceStatus.absent => const Color(0xFFFF3B30),
    };
