import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:smart_class/providers/class_controller.dart';
import 'package:smart_class/screens/classes/class_hub_screen.dart';
import 'package:smart_class/screens/more/more_screen.dart';
import 'package:smart_class/screens/points/quick_points_screen.dart';
import 'package:smart_class/theme/app_theme.dart';
import 'package:smart_class/widgets/apple_widgets.dart';
import 'package:smart_class/widgets/class_switcher_sheet.dart';

/// 日常管理：请假 / 违纪 / 加扣分 / 规则提醒
class DailyScreen extends StatelessWidget {
  const DailyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final ctrl = context.watch<ClassController>();
    final points = ctrl.todayPointsDelta;
    final pointsLabel = points > 0
        ? '+$points'
        : points == 0
            ? '0'
            : '$points';

    return Scaffold(
      backgroundColor: AppTheme.bg,
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '日常管理',
                        style: TextStyle(
                          fontSize: 34,
                          fontWeight: FontWeight.w700,
                          letterSpacing: -0.5,
                          height: 1.1,
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        '请假、违纪、量化积分自动关联学生档案',
                        style: TextStyle(
                          fontSize: 13,
                          color: Color(0xFF8E8E93),
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  tooltip: '班级设置',
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const ClassHubScreen()),
                  ),
                  icon: Icon(Icons.grid_view_rounded, color: AppTheme.secondaryLabel),
                ),
                IconButton(
                  tooltip: '我的',
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const MoreScreen()),
                  ),
                  icon: Icon(Icons.person_outline, color: AppTheme.secondaryLabel),
                ),
              ],
            ),
            const SizedBox(height: 14),
            InkWell(
              onTap: () => showClassSwitcherSheet(context),
              borderRadius: BorderRadius.circular(6),
              child: Text(
                ctrl.currentClass?.displayTitle ?? '未选班级',
                style: TextStyle(fontSize: 13, color: AppTheme.tertiaryLabel),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _StatCard(
                    value: '${ctrl.todayLeaveCount}',
                    label: '今日请假',
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _StatCard(
                    value: '${ctrl.todayDisciplineCount}',
                    label: '违纪处理',
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _StatCard(
                    value: pointsLabel,
                    label: '今日积分',
                    valueColor: points > 0
                        ? const Color(0xFF34C759)
                        : points < 0
                            ? const Color(0xFFFF3B30)
                            : null,
                  ),
                ),
              ],
            ),
            if (ctrl.deductionAlerts.isNotEmpty) ...[
              const SizedBox(height: 12),
              _AlertBanner(
                name: ctrl.deductionAlerts.first.$1.name,
                deducted: ctrl.deductionAlerts.first.$2,
                threshold: ctrl.deductionReminderThreshold,
              ),
            ],
            const SizedBox(height: 14),
            GridView.count(
              crossAxisCount: 2,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              mainAxisSpacing: 10,
              crossAxisSpacing: 10,
              childAspectRatio: 1.55,
              children: [
                _ActionCard(
                  glyph: '假',
                  glyphBg: const Color(0xFF007AFF),
                  title: '记请假',
                  subtitle: '原因 / 谁来接',
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const _LeaveFormScreen()),
                  ),
                ),
                _ActionCard(
                  glyph: '纪',
                  glyphBg: const Color(0xFFFF3B30),
                  title: '记违纪',
                  subtitle: '处理 / 关联扣分',
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => const _DisciplineFormScreen(),
                    ),
                  ),
                ),
                _ActionCard(
                  glyph: '分',
                  glyphBg: const Color(0xFFAF52DE),
                  title: '加扣分',
                  subtitle: '常用项目点选',
                  onTap: () => QuickPointsScreen.open(context, positive: true),
                ),
                _ActionCard(
                  glyph: '规',
                  glyphBg: const Color(0xFF34C759),
                  title: '规则',
                  subtitle: '扣分阈值提醒',
                  onTap: () => _openRules(context, ctrl),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Container(
              decoration: BoxDecoration(
                color: AppTheme.surface,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Padding(
                    padding: EdgeInsets.fromLTRB(16, 14, 16, 4),
                    child: Text(
                      '规则设置',
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  SwitchListTile.adaptive(
                    contentPadding: const EdgeInsets.fromLTRB(16, 4, 8, 8),
                    title: const Text(
                      '累计扣分提醒',
                      style: TextStyle(fontWeight: FontWeight.w500),
                    ),
                    subtitle: Text(
                      '累计扣分 ≥ ${ctrl.deductionReminderThreshold}：提醒老师跟进处理',
                      style: TextStyle(
                        fontSize: 13,
                        color: AppTheme.tertiaryLabel,
                      ),
                    ),
                    value: ctrl.deductionReminderEnabled,
                    activeTrackColor: const Color(0xFF34C759),
                    onChanged: (v) => ctrl.setDeductionReminder(enabled: v),
                  ),
                ],
              ),
            ),
            if (ctrl.leaveRecords.isNotEmpty ||
                ctrl.disciplineRecords.isNotEmpty) ...[
              const SizedBox(height: 16),
              Text(
                '最近记录',
                style: TextStyle(
                  fontSize: 13,
                  color: AppTheme.tertiaryLabel,
                ),
              ),
              const SizedBox(height: 8),
              Container(
                decoration: BoxDecoration(
                  color: AppTheme.surface,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Column(
                  children: [
                    for (final r in ctrl.leaveRecords.take(3))
                      ListTile(
                        title: Text(
                          '${ctrl.studentById(r.studentId)?.name ?? '学生'} · 请假',
                        ),
                        subtitle: Text(
                          [
                            r.date,
                            if (r.reason.isNotEmpty) r.reason,
                            if (r.pickup.isNotEmpty) '接人：${r.pickup}',
                          ].join(' · '),
                        ),
                      ),
                    for (final r in ctrl.disciplineRecords.take(3))
                      ListTile(
                        title: Text(
                          '${ctrl.studentById(r.studentId)?.name ?? '学生'} · ${r.title}',
                        ),
                        subtitle: Text(
                          [
                            r.date,
                            if (r.action.isNotEmpty) r.action,
                            if (r.pointsDelta != 0) '${r.pointsDelta} 分',
                          ].join(' · '),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _openRules(BuildContext context, ClassController ctrl) async {
    final input = TextEditingController(
      text: '${ctrl.deductionReminderThreshold}',
    );
    final saved = await showDialog<int>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('累计扣分提醒'),
        content: TextField(
          controller: input,
          autofocus: true,
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          decoration: const InputDecoration(
            labelText: '阈值（分）',
            hintText: '如 10',
            helperText: '累计扣分达到该值时提醒',
          ),
          onSubmitted: (_) {
            final n = int.tryParse(input.text.trim());
            if (n == null || n < 1) return;
            Navigator.pop(ctx, n.clamp(1, 999));
          },
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () {
              final n = int.tryParse(input.text.trim());
              if (n == null || n < 1) {
                ScaffoldMessenger.of(ctx).showSnackBar(
                  const SnackBar(content: Text('请输入有效的阈值（至少 1）')),
                );
                return;
              }
              Navigator.pop(ctx, n.clamp(1, 999));
            },
            child: const Text('保存'),
          ),
        ],
      ),
    );
    // 等对话框完全关闭后再 dispose，避免「controller used after dispose」
    await Future<void>.delayed(Duration.zero);
    input.dispose();
    if (saved == null || !context.mounted) return;
    try {
      await ctrl.setDeductionReminder(threshold: saved);
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('已设置扣分阈值：$saved')),
      );
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('保存失败：$e')),
      );
    }
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.value,
    required this.label,
    this.valueColor,
  });

  final String value;
  final String label;
  final Color? valueColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 10),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Text(
            value,
            style: TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.w700,
              color: valueColor ?? AppTheme.label,
              height: 1.1,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(fontSize: 12, color: AppTheme.tertiaryLabel),
          ),
        ],
      ),
    );
  }
}

class _AlertBanner extends StatelessWidget {
  const _AlertBanner({
    required this.name,
    required this.deducted,
    required this.threshold,
  });

  final String name;
  final int deducted;
  final int threshold;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF3E8),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '规则提醒',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: Color(0xFFC45C16),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '$name 累计扣分 $deducted，已达「累计扣分提醒」（≥$threshold）：建议约谈跟进',
            style: TextStyle(
              fontSize: 14,
              color: AppTheme.secondaryLabel,
              height: 1.35,
            ),
          ),
        ],
      ),
    );
  }
}

class _ActionCard extends StatelessWidget {
  const _ActionCard({
    required this.glyph,
    required this.glyphBg,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final String glyph;
  final Color glyphBg;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppTheme.surface,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 32,
                height: 32,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: glyphBg,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  glyph,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    fontSize: 15,
                  ),
                ),
              ),
              const Spacer(),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: TextStyle(fontSize: 12, color: AppTheme.tertiaryLabel),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LeaveFormScreen extends StatefulWidget {
  const _LeaveFormScreen();

  @override
  State<_LeaveFormScreen> createState() => _LeaveFormScreenState();
}

class _LeaveFormScreenState extends State<_LeaveFormScreen> {
  String? _studentId;
  final _reason = TextEditingController();
  final _pickup = TextEditingController();
  late String _date;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _date = DateFormat('yyyy-MM-dd').format(DateTime.now());
  }

  @override
  void dispose() {
    _reason.dispose();
    _pickup.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final id = _studentId;
    if (id == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('请选择学生')),
      );
      return;
    }
    setState(() => _saving = true);
    await context.read<ClassController>().saveLeaveRecord(
          studentId: id,
          date: _date,
          reason: _reason.text,
          pickup: _pickup.text,
        );
    if (!mounted) return;
    Navigator.pop(context);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('已记请假')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final students = context.watch<ClassController>().students;
    return Scaffold(
      backgroundColor: AppTheme.bg,
      appBar: PageAppBar(
        title: const Text('记请假'),
        actions: [
          TextButton(onPressed: _saving ? null : _save, child: const Text('保存')),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
        children: [
          Text('学生', style: TextStyle(color: AppTheme.secondaryLabel)),
          const SizedBox(height: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              color: AppTheme.fill,
              borderRadius: BorderRadius.circular(10),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                isExpanded: true,
                value: _studentId,
                hint: const Text('选择学生'),
                items: [
                  for (final s in students)
                    DropdownMenuItem(value: s.id, child: Text(s.name)),
                ],
                onChanged: (v) => setState(() => _studentId = v),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text('日期', style: TextStyle(color: AppTheme.secondaryLabel)),
          const SizedBox(height: 6),
          TextField(
            readOnly: true,
            controller: TextEditingController(text: _date),
            onTap: () async {
              final now = DateTime.now();
              final picked = await showDatePicker(
                context: context,
                initialDate: DateTime.tryParse(_date) ?? now,
                firstDate: DateTime(now.year - 1),
                lastDate: DateTime(now.year + 1),
              );
              if (picked != null) {
                setState(() {
                  _date = DateFormat('yyyy-MM-dd').format(picked);
                });
              }
            },
            decoration: const InputDecoration(hintText: '选择日期'),
          ),
          const SizedBox(height: 16),
          Text('原因', style: TextStyle(color: AppTheme.secondaryLabel)),
          const SizedBox(height: 6),
          TextField(
            controller: _reason,
            decoration: const InputDecoration(hintText: '如：身体不适、家里有事'),
          ),
          const SizedBox(height: 16),
          Text('谁来接', style: TextStyle(color: AppTheme.secondaryLabel)),
          const SizedBox(height: 6),
          TextField(
            controller: _pickup,
            decoration: const InputDecoration(hintText: '家长姓名 / 关系'),
          ),
        ],
      ),
    );
  }
}

class _DisciplineFormScreen extends StatefulWidget {
  const _DisciplineFormScreen();

  @override
  State<_DisciplineFormScreen> createState() => _DisciplineFormScreenState();
}

class _DisciplineFormScreenState extends State<_DisciplineFormScreen> {
  String? _studentId;
  final _title = TextEditingController();
  final _action = TextEditingController();
  int _points = -2;
  late String _date;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _date = DateFormat('yyyy-MM-dd').format(DateTime.now());
  }

  @override
  void dispose() {
    _title.dispose();
    _action.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final id = _studentId;
    if (id == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('请选择学生')),
      );
      return;
    }
    if (_title.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('请填写违纪事由')),
      );
      return;
    }
    setState(() => _saving = true);
    await context.read<ClassController>().saveDisciplineRecord(
          studentId: id,
          date: _date,
          title: _title.text,
          action: _action.text,
          pointsDelta: _points,
        );
    if (!mounted) return;
    Navigator.pop(context);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('已记违纪')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final students = context.watch<ClassController>().students;
    return Scaffold(
      backgroundColor: AppTheme.bg,
      appBar: PageAppBar(
        title: const Text('记违纪'),
        actions: [
          TextButton(onPressed: _saving ? null : _save, child: const Text('保存')),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
        children: [
          Text('学生', style: TextStyle(color: AppTheme.secondaryLabel)),
          const SizedBox(height: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              color: AppTheme.fill,
              borderRadius: BorderRadius.circular(10),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                isExpanded: true,
                value: _studentId,
                hint: const Text('选择学生'),
                items: [
                  for (final s in students)
                    DropdownMenuItem(value: s.id, child: Text(s.name)),
                ],
                onChanged: (v) => setState(() => _studentId = v),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text('事由', style: TextStyle(color: AppTheme.secondaryLabel)),
          const SizedBox(height: 6),
          TextField(
            controller: _title,
            decoration: const InputDecoration(hintText: '如：课堂违纪、迟到'),
          ),
          const SizedBox(height: 16),
          Text('处理方式', style: TextStyle(color: AppTheme.secondaryLabel)),
          const SizedBox(height: 6),
          TextField(
            controller: _action,
            decoration: const InputDecoration(hintText: '如：口头教育、联系家长'),
          ),
          const SizedBox(height: 16),
          Text('关联扣分', style: TextStyle(color: AppTheme.secondaryLabel)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            children: [
              for (final p in const [0, -1, -2, -3, -5])
                ChoiceChip(
                  label: Text(p == 0 ? '不扣分' : '$p'),
                  selected: _points == p,
                  onSelected: (_) => setState(() => _points = p),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
