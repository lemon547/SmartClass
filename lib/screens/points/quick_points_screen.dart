import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:smart_class/models/models.dart';
import 'package:smart_class/providers/class_controller.dart';
import 'package:smart_class/theme/app_icons.dart';
import 'package:smart_class/theme/app_theme.dart';
import 'package:smart_class/widgets/apple_widgets.dart';

/// 加分 / 扣分：选人 → 选原因 → 调分值 → 确认
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

  String get _deltaLabel => '${widget.positive ? '+' : '-'}$_amount';

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
    final selectedStudent =
        _studentId == null ? null : ctrl.studentById(_studentId!);
    final verb = widget.positive ? '加分' : '扣分';

    return Scaffold(
      backgroundColor: AppTheme.bg,
      appBar: PageAppBar(title: Text(verb)),
      body: Column(
        children: [
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 20),
              children: [
                // 分值主视觉
                Container(
                  padding: const EdgeInsets.fromLTRB(16, 18, 16, 16),
                  decoration: BoxDecoration(
                    color: AppTheme.surface,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.04),
                        blurRadius: 10,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      Text(
                        selectedStudent == null
                            ? '请先选择学生'
                            : '${selectedStudent.name} · 当前 ${selectedStudent.points} 分',
                        style: TextStyle(
                          fontSize: 14,
                          color: AppTheme.secondaryLabel,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          _RoundIconBtn(
                            icon: AppIcons.circleMinus,
                            enabled: _amount > 1,
                            onTap: () => setState(() {
                              if (_amount > 1) _amount--;
                            }),
                          ),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 20),
                            child: Text(
                              _deltaLabel,
                              style: TextStyle(
                                fontSize: 44,
                                fontWeight: FontWeight.w700,
                                color: _accent,
                                letterSpacing: -1.5,
                                height: 1,
                              ),
                            ),
                          ),
                          _RoundIconBtn(
                            icon: AppIcons.circlePlus,
                            enabled: _amount < 99,
                            onTap: () => setState(() {
                              if (_amount < 99) _amount++;
                            }),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        _selected.reason,
                        style: TextStyle(
                          fontSize: 13,
                          color: AppTheme.tertiaryLabel,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 18),

                Text(
                  '原因',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.tertiaryLabel,
                  ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final p in presets)
                      _ReasonChip(
                        label: p.reason,
                        delta: p.delta,
                        accent: _accent,
                        selected: _selected.reason == p.reason,
                        onTap: () => setState(() {
                          _selected = p;
                          _amount = p.delta.abs().clamp(1, 99);
                        }),
                      ),
                  ],
                ),
                const SizedBox(height: 18),

                Text(
                  '选择学生',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.tertiaryLabel,
                  ),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _search,
                  onChanged: (v) => setState(() => _query = v),
                  style: const TextStyle(fontSize: 15),
                  decoration: InputDecoration(
                    hintText: '搜索姓名 / 学号',
                    hintStyle: TextStyle(
                      color: AppTheme.tertiaryLabel,
                      fontSize: 14,
                    ),
                    prefixIcon: Icon(
                      AppIcons.search,
                      size: 18,
                      color: AppTheme.tertiaryLabel,
                    ),
                    filled: true,
                    fillColor: AppTheme.surface,
                    contentPadding: const EdgeInsets.symmetric(vertical: 0),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                Container(
                  decoration: BoxDecoration(
                    color: AppTheme.surface,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: students.isEmpty
                      ? Padding(
                          padding: const EdgeInsets.all(24),
                          child: Center(
                            child: Text(
                              '没有匹配的学生',
                              style: TextStyle(color: AppTheme.tertiaryLabel),
                            ),
                          ),
                        )
                      : Column(
                          children: [
                            for (var i = 0; i < students.length; i++) ...[
                              if (i > 0)
                                Divider(
                                  height: 1,
                                  indent: 56,
                                  color: AppTheme.separator
                                      .withValues(alpha: 0.5),
                                ),
                              _StudentPickRow(
                                student: students[i],
                                selected: _studentId == students[i].id,
                                accent: _accent,
                                onTap: () => setState(
                                  () => _studentId = students[i].id,
                                ),
                              ),
                            ],
                          ],
                        ),
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
                height: 50,
                child: FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: _accent,
                    shape: const StadiumBorder(),
                    textStyle: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
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
                          selectedStudent == null
                              ? '确认$verb $_deltaLabel'
                              : '给${selectedStudent.name}$verb $_deltaLabel',
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

class _RoundIconBtn extends StatelessWidget {
  const _RoundIconBtn({
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
      color: AppTheme.fill.withValues(alpha: enabled ? 1 : 0.5),
      shape: const CircleBorder(),
      child: InkWell(
        onTap: enabled ? onTap : null,
        customBorder: const CircleBorder(),
        child: SizedBox(
          width: 44,
          height: 44,
          child: Icon(
            icon,
            size: 22,
            color: enabled ? AppTheme.label : AppTheme.quaternaryLabel,
          ),
        ),
      ),
    );
  }
}

class _ReasonChip extends StatelessWidget {
  const _ReasonChip({
    required this.label,
    required this.delta,
    required this.accent,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final int delta;
  final Color accent;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final deltaText = '${delta > 0 ? '+' : ''}$delta';
    return Material(
      color: selected ? accent.withValues(alpha: 0.12) : AppTheme.surface,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: selected
                  ? accent.withValues(alpha: 0.45)
                  : AppTheme.separator.withValues(alpha: 0.5),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                  color: selected ? accent : AppTheme.label,
                ),
              ),
              const SizedBox(width: 6),
              Text(
                deltaText,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: accent,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StudentPickRow extends StatelessWidget {
  const _StudentPickRow({
    required this.student,
    required this.selected,
    required this.accent,
    required this.onTap,
  });

  final Student student;
  final bool selected;
  final Color accent;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final sub = [
      if (student.studentNo.isNotEmpty) student.studentNo,
      if (student.groupName.isNotEmpty) student.groupName,
      '${student.points}分',
    ].join(' · ');

    return Material(
      color: selected ? accent.withValues(alpha: 0.06) : Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Row(
            children: [
              StudentAvatar(name: student.name, size: 36),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      student.name,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight:
                            selected ? FontWeight.w600 : FontWeight.w500,
                      ),
                    ),
                    if (sub.isNotEmpty)
                      Text(
                        sub,
                        style: TextStyle(
                          fontSize: 12,
                          color: AppTheme.tertiaryLabel,
                        ),
                      ),
                  ],
                ),
              ),
              Icon(
                selected ? AppIcons.circleCheck : AppIcons.circle,
                size: 22,
                color: selected ? accent : AppTheme.quaternaryLabel,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
