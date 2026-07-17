import 'package:smart_class/theme/app_icons.dart';
import 'package:flutter/material.dart';

import 'package:provider/provider.dart';
import 'package:smart_class/models/models.dart';
import 'package:smart_class/providers/class_controller.dart';
import 'package:smart_class/screens/homework/homework_screen.dart';
import 'package:smart_class/screens/roll_call/roll_call_screen.dart';
import 'package:smart_class/screens/tools/countdown_screen.dart';
import 'package:smart_class/theme/app_theme.dart';
import 'package:smart_class/widgets/apple_widgets.dart';
import 'package:smart_class/widgets/paddi_mascot.dart';

String _todayLabel() {
  final n = DateTime.now();
  const week = ['一', '二', '三', '四', '五', '六', '日'];
  return '${n.month}月${n.day}日 周${week[n.weekday - 1]}';
}

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final ctrl = context.watch<ClassController>();
    final present = ctrl.selectedDate == ctrl.todayKey
        ? ctrl.countStatus(AttendanceStatus.present)
        : null;
    final leave = ctrl.selectedDate == ctrl.todayKey
        ? ctrl.countStatus(AttendanceStatus.leave)
        : null;
    final top = ctrl.rankedByPoints.take(5).toList();
    final todayDuty = ctrl.dutyList
        .where((d) => d.weekday == DateTime.now().weekday)
        .toList();
    final birthdays = ctrl.todayBirthdays;
    final countdown = ctrl.nearestCountdown;

    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.only(bottom: 28),
          children: [
            LargeTitle(
              '班主任助手',
              showLogo: true,
              trailing: Padding(
                padding: const EdgeInsets.only(bottom: 6, right: 8),
                child: Text(
                  _todayLabel(),
                  style: TextStyle(
                    fontSize: 13,
                    color: AppTheme.tertiaryLabel,
                  ),
                ),
              ),
            ),
            const PaddiHomeBanner(),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 18),
              child: Text(
                '${ctrl.profile.grade} · ${ctrl.profile.name}',
                style: TextStyle(
                  fontSize: 15,
                  color: AppTheme.tertiaryLabel,
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                children: [
                  QuietStat(label: '学生', value: '${ctrl.students.length}'),
                  QuietStat(label: '出勤', value: '${present ?? '—'}'),
                  QuietStat(label: '请假', value: '${leave ?? '—'}'),
                ],
              ),
            ),
            if (birthdays.isNotEmpty ||
                (countdown != null && countdown.daysLeft <= 14)) ...[
              const SizedBox(height: 18),
              GroupedSection(
                header: '提醒',
                children: [
                  if (birthdays.isNotEmpty)
                    GroupedTile(
                      title: '今日生日',
                      subtitle: birthdays.map((s) => s.name).join('、'),
                      leading: Icon(AppIcons.cake, color: AppTheme.blue),
                    ),
                  if (countdown != null && countdown.daysLeft <= 14)
                    GroupedTile(
                      title: countdown.title,
                      subtitle: countdown.daysLeft > 0
                          ? '还有 ${countdown.daysLeft} 天 · ${countdown.targetDate}'
                          : (countdown.daysLeft == 0
                              ? '就是今天'
                              : '已过期'),
                      leading: Icon(AppIcons.hourglass, color: AppTheme.blue),
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute(
                            builder: (_) => const CountdownScreen()),
                      ),
                    ),
                ],
              ),
            ],
            const SizedBox(height: 22),
            GroupedSection(
              header: '常用',
              children: [
                GroupedTile(
                  title: '随机点名',
                  subtitle: '公平抽取，记录历史',
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const RollCallScreen()),
                  ),
                ),
                GroupedTile(
                  title: '今日作业',
                  subtitle: ctrl.homework.isEmpty
                      ? '登记并勾选完成情况'
                      : '${ctrl.homework.length} 项作业',
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const HomeworkScreen()),
                  ),
                ),
                GroupedTile(
                  title: '快速加分',
                  onTap: () => _quickPoints(context, true),
                ),
                GroupedTile(
                  title: '快速扣分',
                  onTap: () => _quickPoints(context, false),
                ),
                if (ctrl.students.isEmpty)
                  GroupedTile(
                    title: '填充演示数据',
                    subtitle: '含小组与奖品示例',
                    onTap: () => ctrl.seedDemo(),
                  ),
              ],
            ),
            const SizedBox(height: 18),
            GroupedSection(
              header: '积分榜',
              footer: top.isEmpty ? '添加学生后显示' : null,
              children: [
                if (top.isEmpty)
                  Padding(
                    padding: EdgeInsets.all(18),
                    child: Text('暂无数据',
                        style: TextStyle(color: AppTheme.tertiaryLabel)),
                  )
                else
                  for (var i = 0; i < top.length; i++)
                    GroupedTile(
                      title: '${i + 1}.  ${top[i].name}',
                      subtitle: [
                        if (top[i].role.isNotEmpty) top[i].role,
                        if (top[i].groupName.isNotEmpty) top[i].groupName,
                      ].isEmpty
                          ? null
                          : [
                              if (top[i].role.isNotEmpty) top[i].role,
                              if (top[i].groupName.isNotEmpty) top[i].groupName,
                            ].join(' · '),
                      trailing: Text(
                        '${top[i].points}',
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w500,
                          color: AppTheme.secondaryLabel,
                        ),
                      ),
                    ),
              ],
            ),
            if (todayDuty.isNotEmpty) ...[
              const SizedBox(height: 18),
              GroupedSection(
                header: '今日值日',
                children: [
                  for (final d in todayDuty)
                    GroupedTile(
                      title: ctrl.studentById(d.studentId)?.name ?? '未知',
                      subtitle: d.task,
                    ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _quickPoints(BuildContext context, bool positive) async {
    final ctrl = context.read<ClassController>();
    if (ctrl.students.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('请先添加学生')),
      );
      return;
    }
    final presets = ctrl.pointPresets
        .where((p) => positive ? p.delta >= 0 : p.delta < 0)
        .toList();
    final fallback = positive
        ? const PointReasonPreset(reason: '表扬', delta: 2)
        : const PointReasonPreset(reason: '提醒', delta: -1);
    final list = presets.isEmpty ? [fallback] : presets;
    String? studentId = ctrl.students.first.id;
    var selected = list.first;
    var amount = selected.delta.abs().clamp(1, 99);

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
                top: 12,
                bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Center(
                    child: Container(
                      width: 36,
                      height: 5,
                      decoration: BoxDecoration(
                        color: AppTheme.quaternaryLabel,
                        borderRadius: BorderRadius.circular(3),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    positive ? '快速加分' : '快速扣分',
                    style: Theme.of(ctx).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 14),
                  DropdownButtonFormField<String>(
                    value: studentId,
                    items: [
                      for (final s in ctrl.students)
                        DropdownMenuItem(value: s.id, child: Text(s.name)),
                    ],
                    onChanged: (v) => setState(() => studentId = v),
                    decoration: const InputDecoration(labelText: '学生'),
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final p in list)
                        ChoiceChip(
                          label: Text(
                            '${p.reason} ${p.delta > 0 ? '+' : ''}${p.delta}',
                          ),
                          selected: selected.reason == p.reason,
                          onSelected: (_) => setState(() {
                            selected = p;
                            amount = p.delta.abs().clamp(1, 99);
                          }),
                        ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      const Text('分值', style: TextStyle(fontSize: 17)),
                      const Spacer(),
                      IconButton(
                        onPressed: () => setState(() {
                          if (amount > 1) amount--;
                        }),
                        icon: const Icon(AppIcons.circleMinus),
                      ),
                      Text('$amount',
                          style: const TextStyle(
                              fontSize: 22, fontWeight: FontWeight.w600)),
                      IconButton(
                        onPressed: () => setState(() => amount++),
                        icon: const Icon(AppIcons.circlePlus),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  FilledButton(
                    onPressed: studentId == null
                        ? null
                        : () async {
                            await ctrl.adjustPoints(
                              studentId: studentId!,
                              delta: positive ? amount : -amount,
                              reason: selected.reason,
                            );
                            if (ctx.mounted) Navigator.pop(ctx);
                          },
                    child: const Text('确认'),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}
