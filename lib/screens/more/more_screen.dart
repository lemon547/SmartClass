import 'dart:convert';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:smart_class/models/models.dart';
import 'package:smart_class/providers/class_controller.dart';
import 'package:smart_class/providers/theme_controller.dart';
import 'package:smart_class/screens/duty/duty_screen.dart';
import 'package:smart_class/screens/groups/groups_screen.dart';
import 'package:smart_class/screens/homework/homework_screen.dart';
import 'package:smart_class/screens/notes/notes_screen.dart';
import 'package:smart_class/screens/points/settlements_screen.dart';
import 'package:smart_class/screens/reports/weekly_report_screen.dart';
import 'package:smart_class/screens/rewards/rewards_screen.dart';
import 'package:smart_class/screens/roll_call/roll_call_screen.dart';
import 'package:smart_class/screens/seating/seating_screen.dart';
import 'package:smart_class/screens/timetable/timetable_screen.dart';
import 'package:smart_class/screens/tools/countdown_screen.dart';
import 'package:smart_class/screens/tools/fund_screen.dart';
import 'package:smart_class/theme/app_theme.dart';
import 'package:smart_class/theme/mascot_assets.dart';
import 'package:smart_class/widgets/apple_widgets.dart';
import 'package:smart_class/widgets/paddi_mascot.dart';

class MoreScreen extends StatelessWidget {
  const MoreScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final ctrl = context.watch<ClassController>();
    final themeCtrl = context.watch<ThemeController>();

    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.only(bottom: 28),
          children: [
            const LargeTitle('更多'),
            GroupedSection(
              header: '外观',
              children: [
                GroupedTile(
                  title: '主题',
                  subtitle: themeCtrl.mode.label,
                  onTap: () => _pickTheme(context),
                ),
              ],
            ),
            const SizedBox(height: 18),
            GroupedSection(
              header: '课堂',
              children: [
                GroupedTile(
                  title: '随机点名',
                  onTap: () => _push(context, const RollCallScreen()),
                ),
                GroupedTile(
                  title: '作业检查',
                  onTap: () => _push(context, const HomeworkScreen()),
                ),
                GroupedTile(
                  title: '座位表',
                  subtitle:
                      '${ctrl.profile.seatRows}×${ctrl.profile.seatCols}',
                  onTap: () => _push(context, const SeatingScreen()),
                ),
                GroupedTile(
                  title: '值日安排',
                  onTap: () => _push(context, const DutyScreen()),
                ),
                GroupedTile(
                  title: '课程表',
                  onTap: () => _push(context, const TimetableScreen()),
                ),
              ],
            ),
            const SizedBox(height: 18),
            GroupedSection(
              header: '管理',
              children: [
                GroupedTile(
                  title: '小组',
                  subtitle: ctrl.groupNames.isEmpty
                      ? '未设置'
                      : '${ctrl.groupNames.length} 个小组',
                  onTap: () => _push(context, const GroupsScreen()),
                ),
                GroupedTile(
                  title: '积分兑换',
                  onTap: () => _push(context, const RewardsScreen()),
                ),
                GroupedTile(
                  title: '倒数日',
                  subtitle: ctrl.nearestCountdown == null
                      ? '考试 / 放假倒计时'
                      : '${ctrl.nearestCountdown!.title} · ${ctrl.nearestCountdown!.daysLeft} 天',
                  onTap: () => _push(context, const CountdownScreen()),
                ),
                GroupedTile(
                  title: '班费',
                  subtitle: '余额 ${ctrl.fundBalance}',
                  onTap: () => _push(context, const FundScreen()),
                ),
                GroupedTile(
                  title: '班级记事',
                  onTap: () => _push(context, const NotesScreen()),
                ),
                GroupedTile(
                  title: '本周概况',
                  onTap: () => _push(context, const WeeklyReportScreen()),
                ),
                GroupedTile(
                  title: '导出积分排行',
                  subtitle: 'CSV 保存到本机',
                  onTap: () async {
                    final path = await ctrl.exportRankingFile();
                    await Clipboard.setData(ClipboardData(text: path));
                    if (!context.mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('已导出：\n$path')),
                    );
                  },
                ),
              ],
            ),
            const SizedBox(height: 18),
            GroupedSection(
              header: '设置',
              children: [
                GroupedTile(
                  title: '班级信息',
                  subtitle: '${ctrl.profile.grade} · ${ctrl.profile.name}',
                  onTap: () => _editClass(context),
                ),
                GroupedTile(
                  title: '积分预设',
                  subtitle: '${ctrl.pointPresets.length} 条 · 含默认分值',
                  onTap: () => _editPresets(context),
                ),
                GroupedTile(
                  title: '结算并重新开始',
                  subtitle: '保存排行快照后清零',
                  onTap: () => _settle(context),
                ),
                GroupedTile(
                  title: '结算记录',
                  subtitle: ctrl.settlements.isEmpty
                      ? '暂无'
                      : '${ctrl.settlements.length} 次',
                  onTap: () => _push(context, const SettlementsScreen()),
                ),
                GroupedTile(
                  title: '清空全部积分',
                  titleColor: AppTheme.destructive,
                  onTap: () => _resetPoints(context),
                ),
              ],
            ),
            const SizedBox(height: 18),
            GroupedSection(
              header: '数据',
              footer: '备份仅保存在本机，可用于换机迁移。',
              children: [
                GroupedTile(
                  title: '导出备份',
                  onTap: () async {
                    final path = await ctrl.exportBackupFile();
                    await Clipboard.setData(ClipboardData(text: path));
                    if (!context.mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('已导出：\n$path')),
                    );
                  },
                ),
                GroupedTile(
                  title: '导入备份',
                  onTap: () => _importBackup(context),
                ),
                if (ctrl.students.isEmpty)
                  GroupedTile(
                    title: '填充演示数据',
                    onTap: () => ctrl.seedDemo(),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _push(BuildContext context, Widget page) {
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => page));
  }

  Future<void> _pickTheme(BuildContext context) async {
    final themeCtrl = context.read<ThemeController>();
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text('选择主题', style: Theme.of(ctx).textTheme.titleLarge),
                const SizedBox(height: 6),
                Text(
                  '懒羊羊是贴纸皮肤，不会把整页染成黄色',
                  style: TextStyle(
                    fontSize: 13,
                    color: AppTheme.tertiaryLabel,
                  ),
                ),
                const SizedBox(height: 14),
                for (final mode in AppThemeMode.values) ...[
                  Material(
                    color: themeCtrl.mode == mode
                        ? AppTheme.blue.withValues(alpha: 0.1)
                        : AppTheme.surface,
                    borderRadius: BorderRadius.circular(12),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(12),
                      onTap: () async {
                        await themeCtrl.setMode(mode);
                        if (ctx.mounted) Navigator.pop(ctx);
                      },
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 12,
                        ),
                        child: Row(
                          children: [
                            if (mode == AppThemeMode.paddi)
                              const PaddiMascot(
                                asset: MascotAssets.emote,
                                height: 44,
                                force: true,
                              )
                            else
                              Container(
                                width: 44,
                                height: 44,
                                decoration: BoxDecoration(
                                  color: switch (mode) {
                                    AppThemeMode.day =>
                                      const Color(0xFFF2F2F7),
                                    AppThemeMode.night =>
                                      const Color(0xFF1C1C1E),
                                    AppThemeMode.eyeCare =>
                                      const Color(0xFFC7EDCC),
                                    AppThemeMode.paddi =>
                                      const Color(0xFFF2F2F7),
                                  },
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(
                                    color: AppTheme.separator,
                                  ),
                                ),
                              ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    mode.label,
                                    style: TextStyle(
                                      fontSize: 17,
                                      fontWeight: themeCtrl.mode == mode
                                          ? FontWeight.w600
                                          : FontWeight.w400,
                                      color: AppTheme.label,
                                    ),
                                  ),
                                  Text(
                                    mode.hint,
                                    style: TextStyle(
                                      fontSize: 13,
                                      color: AppTheme.tertiaryLabel,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            if (themeCtrl.mode == mode)
                              Icon(Icons.check, color: AppTheme.blue, size: 20),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _resetPoints(BuildContext context) async {
    final ok = await showCupertinoDialog<bool>(
      context: context,
      builder: (ctx) => CupertinoAlertDialog(
        title: const Text('清空全部积分？'),
        content: const Text('所有学生积分归零，积分记录也会删除。'),
        actions: [
          CupertinoDialogAction(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('取消'),
          ),
          CupertinoDialogAction(
            isDestructiveAction: true,
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('清空'),
          ),
        ],
      ),
    );
    if (ok == true && context.mounted) {
      await context.read<ClassController>().resetAllPoints();
    }
  }

  Future<void> _settle(BuildContext context) async {
    final name = TextEditingController(
      text: '第${context.read<ClassController>().settlements.length + 1}阶段',
    );
    final ok = await showCupertinoDialog<bool>(
      context: context,
      builder: (ctx) => CupertinoAlertDialog(
        title: const Text('结算并重新开始？'),
        content: Column(
          children: [
            const SizedBox(height: 8),
            const Text('将保存当前排行快照，然后清空积分与记录。'),
            const SizedBox(height: 12),
            CupertinoTextField(
              controller: name,
              placeholder: '阶段名称',
            ),
          ],
        ),
        actions: [
          CupertinoDialogAction(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('取消'),
          ),
          CupertinoDialogAction(
            isDestructiveAction: true,
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('结算'),
          ),
        ],
      ),
    );
    if (ok == true && context.mounted) {
      await context.read<ClassController>().settleAndRestart(name.text);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('已结算，积分重新开始')),
        );
      }
    }
  }

  Future<void> _editClass(BuildContext context) async {
    final ctrl = context.read<ClassController>();
    final name = TextEditingController(text: ctrl.profile.name);
    final grade = TextEditingController(text: ctrl.profile.grade);
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) {
        return Padding(
          padding: EdgeInsets.only(
            left: 20,
            right: 20,
            top: 16,
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('班级信息', style: Theme.of(ctx).textTheme.titleLarge),
              const SizedBox(height: 12),
              TextField(
                  controller: grade,
                  decoration: const InputDecoration(labelText: '年级')),
              const SizedBox(height: 8),
              TextField(
                  controller: name,
                  decoration: const InputDecoration(labelText: '班级名称')),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: () async {
                  await ctrl.updateProfile(
                    ctrl.profile.copyWith(
                      name: name.text.trim(),
                      grade: grade.text.trim(),
                    ),
                  );
                  if (ctx.mounted) Navigator.pop(ctx);
                },
                child: const Text('保存'),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _editPresets(BuildContext context) async {
    final ctrl = context.read<ClassController>();
    final lines = ctrl.pointPresets
        .map((e) => '${e.reason} ${e.delta > 0 ? '+' : ''}${e.delta}')
        .join('\n');
    final text = TextEditingController(text: lines);
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) {
        return Padding(
          padding: EdgeInsets.only(
            left: 20,
            right: 20,
            top: 16,
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('积分预设', style: Theme.of(ctx).textTheme.titleLarge),
              const SizedBox(height: 8),
              Text(
                '每行一条：理由 +分值，例如「课堂发言 +2」或「迟到 -1」',
                style: TextStyle(color: AppTheme.tertiaryLabel, fontSize: 13),
              ),
              const SizedBox(height: 12),
              TextField(controller: text, minLines: 8, maxLines: 12),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: () async {
                  final presets = <PointReasonPreset>[];
                  for (final line in text.text.split('\n')) {
                    final t = line.trim();
                    if (t.isEmpty) continue;
                    final m = RegExp(r'^(.+?)\s+([+-]?\d+)\s*$').firstMatch(t);
                    if (m != null) {
                      presets.add(PointReasonPreset(
                        reason: m.group(1)!.trim(),
                        delta: int.parse(m.group(2)!),
                      ));
                    } else {
                      presets.add(PointReasonPreset(reason: t, delta: 1));
                    }
                  }
                  if (presets.isEmpty) return;
                  await ctrl.savePointPresets(presets);
                  if (ctx.mounted) Navigator.pop(ctx);
                },
                child: const Text('保存'),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _importBackup(BuildContext context) async {
    final ctrl = context.read<ClassController>();
    final text = TextEditingController();
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) {
        return Padding(
          padding: EdgeInsets.only(
            left: 20,
            right: 20,
            top: 16,
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('导入备份', style: Theme.of(ctx).textTheme.titleLarge),
              const SizedBox(height: 8),
              Text(
                '粘贴备份 JSON。导入会覆盖当前数据。',
                style: TextStyle(color: AppTheme.tertiaryLabel, fontSize: 13),
              ),
              const SizedBox(height: 12),
              TextField(controller: text, minLines: 8, maxLines: 12),
              const SizedBox(height: 16),
              FilledButton(
                style: FilledButton.styleFrom(
                    backgroundColor: AppTheme.destructive),
                onPressed: () async {
                  try {
                    jsonDecode(text.text);
                    await ctrl.importBackupJson(text.text);
                    if (ctx.mounted) {
                      Navigator.pop(ctx);
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('导入成功')),
                      );
                    }
                  } catch (e) {
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('失败：$e')),
                      );
                    }
                  }
                },
                child: const Text('确认覆盖导入'),
              ),
            ],
          ),
        );
      },
    );
  }
}
