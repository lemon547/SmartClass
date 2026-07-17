import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:smart_class/models/models.dart';
import 'package:smart_class/providers/class_controller.dart';
import 'package:smart_class/theme/app_icons.dart';
import 'package:smart_class/theme/app_theme.dart';
import 'package:smart_class/widgets/apple_widgets.dart';

/// 加分 / 扣分：独立全屏页（iOS 分组列表）
class QuickPointsScreen extends StatefulWidget {
  const QuickPointsScreen({
    super.key,
    required this.positive,
    this.initialStudentId,
  });

  final bool positive;
  final String? initialStudentId;

  static Future<void> open(
    BuildContext context, {
    required bool positive,
    String? initialStudentId,
  }) async {
    final ctrl = context.read<ClassController>();
    if (ctrl.students.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('请先添加学生')),
      );
      return;
    }
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => QuickPointsScreen(
          positive: positive,
          initialStudentId: initialStudentId,
        ),
      ),
    );
  }

  @override
  State<QuickPointsScreen> createState() => _QuickPointsScreenState();
}

class _QuickPointsScreenState extends State<QuickPointsScreen> {
  final _search = TextEditingController();
  String _query = '';
  late String? _studentId;
  late PointReasonPreset _selected;
  late int _amount;
  bool _submitting = false;

  Color get _accent => widget.positive
      ? const Color(0xFF34C759)
      : const Color(0xFFFF3B30);

  @override
  void initState() {
    super.initState();
    final ctrl = context.read<ClassController>();
    _studentId = widget.initialStudentId ?? ctrl.students.first.id;
    _selected = _presets(ctrl).first;
    _amount = _selected.delta.abs().clamp(1, 99);
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  List<PointReasonPreset> _presets(ClassController ctrl) {
    final presets = ctrl.pointPresets
        .where((p) => widget.positive ? p.delta >= 0 : p.delta < 0)
        .toList();
    if (presets.isNotEmpty) return presets;
    return [
      widget.positive
          ? const PointReasonPreset(reason: '表扬', delta: 2)
          : const PointReasonPreset(reason: '提醒', delta: -1),
    ];
  }

  Future<void> _submit(ClassController ctrl) async {
    if (_studentId == null || _submitting) return;
    setState(() => _submitting = true);
    try {
      await ctrl.adjustPoints(
        studentId: _studentId!,
        delta: widget.positive ? _amount : -_amount,
        reason: _selected.reason,
      );
      if (mounted) Navigator.pop(context);
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final ctrl = context.watch<ClassController>();
    final presets = _presets(ctrl);
    final students = ctrl.searchStudents(_query);
    final selectedStudent = _studentId == null
        ? null
        : ctrl.studentById(_studentId!);
    final deltaLabel =
        '${widget.positive ? '+' : '-'}$_amount';

    return Scaffold(
      backgroundColor: AppTheme.bg,
      appBar: PageAppBar(
        title: Text(widget.positive ? '加分' : '扣分'),
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView(
              padding: const EdgeInsets.only(bottom: 16),
              children: [
                if (selectedStudent != null) ...[
                  const SizedBox(height: 8),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: AppTheme.surface,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Row(
                          children: [
                            StudentAvatar(
                              name: selectedStudent.name,
                              size: 48,
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    selectedStudent.name,
                                    style: const TextStyle(
                                      fontSize: 20,
                                      fontWeight: FontWeight.w600,
                                      letterSpacing: -0.3,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    '当前 ${selectedStudent.points} 分',
                                    style: TextStyle(
                                      fontSize: 14,
                                      color: AppTheme.tertiaryLabel,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Text(
                              deltaLabel,
                              style: TextStyle(
                                fontSize: 28,
                                fontWeight: FontWeight.w700,
                                color: _accent,
                                letterSpacing: -0.5,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: 12),
                SearchField(
                  controller: _search,
                  hint: '搜索学生',
                  onChanged: (v) => setState(() => _query = v),
                ),
                GroupedSection(
                  header: '选择学生',
                  children: [
                    if (students.isEmpty)
                      Padding(
                        padding: const EdgeInsets.all(18),
                        child: Text(
                          '没有匹配的学生',
                          style: TextStyle(color: AppTheme.tertiaryLabel),
                        ),
                      )
                    else
                      for (final s in students)
                        GroupedTile(
                          title: s.name,
                          subtitle: [
                            if (s.studentNo.isNotEmpty) s.studentNo,
                            if (s.groupName.isNotEmpty) s.groupName,
                          ].join(' · ').isEmpty
                              ? null
                              : [
                                  if (s.studentNo.isNotEmpty) s.studentNo,
                                  if (s.groupName.isNotEmpty) s.groupName,
                                ].join(' · '),
                          leading: StudentAvatar(name: s.name),
                          trailing: _studentId == s.id
                              ? Icon(AppIcons.circleCheck, color: _accent)
                              : null,
                          onTap: () => setState(() => _studentId = s.id),
                        ),
                  ],
                ),
                const SizedBox(height: 16),
                GroupedSection(
                  header: widget.positive ? '加分原因' : '扣分原因',
                  footer: '可在「班级 → 积分规则」中自定义',
                  children: [
                    for (final p in presets)
                      GroupedTile(
                        title: p.reason,
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              '${p.delta > 0 ? '+' : ''}${p.delta}',
                              style: TextStyle(
                                fontSize: 17,
                                fontWeight: FontWeight.w600,
                                color: _accent,
                              ),
                            ),
                            if (_selected.reason == p.reason) ...[
                              const SizedBox(width: 8),
                              Icon(AppIcons.circleCheck, color: _accent),
                            ],
                          ],
                        ),
                        onTap: () => setState(() {
                          _selected = p;
                          _amount = p.delta.abs().clamp(1, 99);
                        }),
                      ),
                  ],
                ),
                const SizedBox(height: 16),
                GroupedSection(
                  header: '分值',
                  children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          _StepButton(
                            icon: AppIcons.circleMinus,
                            enabled: _amount > 1,
                            onTap: () => setState(() {
                              if (_amount > 1) _amount--;
                            }),
                          ),
                          SizedBox(
                            width: 88,
                            child: Text(
                              '$_amount',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 36,
                                fontWeight: FontWeight.w700,
                                color: _accent,
                                letterSpacing: -1,
                              ),
                            ),
                          ),
                          _StepButton(
                            icon: AppIcons.circlePlus,
                            enabled: _amount < 99,
                            onTap: () => setState(() {
                              if (_amount < 99) _amount++;
                            }),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
              child: SizedBox(
                width: double.infinity,
                child: FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: _accent,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  onPressed: _studentId == null || _submitting
                      ? null
                      : () => _submit(ctrl),
                  child: _submitting
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : Text(
                          '确认${widget.positive ? '加分' : '扣分'} $deltaLabel',
                          style: const TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _StepButton extends StatelessWidget {
  const _StepButton({
    required this.icon,
    required this.enabled,
    required this.onTap,
  });

  final IconData icon;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppTheme.fill,
      shape: const CircleBorder(),
      child: InkWell(
        onTap: enabled ? onTap : null,
        customBorder: const CircleBorder(),
        child: SizedBox(
          width: 44,
          height: 44,
          child: Icon(
            icon,
            color: enabled ? AppTheme.blue : AppTheme.quaternaryLabel,
          ),
        ),
      ),
    );
  }
}
