import 'dart:convert';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:smart_class/app_info.dart';
import 'package:smart_class/providers/class_controller.dart';
import 'package:smart_class/providers/theme_controller.dart';
import 'package:smart_class/screens/attendance/attendance_screen.dart';
import 'package:smart_class/screens/duty/duty_screen.dart';
import 'package:smart_class/screens/groups/groups_screen.dart';
import 'package:smart_class/screens/homework/homework_screen.dart';
import 'package:smart_class/screens/notes/notes_screen.dart';
import 'package:smart_class/screens/points/point_rules_screen.dart';
import 'package:smart_class/screens/points/settlements_screen.dart';
import 'package:smart_class/screens/reports/weekly_report_screen.dart';
import 'package:smart_class/screens/rewards/rewards_screen.dart';
import 'package:smart_class/screens/roll_call/roll_call_screen.dart';
import 'package:smart_class/screens/seating/seating_screen.dart';
import 'package:smart_class/screens/timetable/timetable_screen.dart';
import 'package:smart_class/screens/tools/countdown_screen.dart';
import 'package:smart_class/screens/tools/fund_screen.dart';
import 'package:smart_class/screens/work_logs/work_logs_screen.dart';
import 'package:smart_class/features/class_features.dart';
import 'package:smart_class/legal/legal_texts.dart';
import 'package:smart_class/screens/classes/class_features_screen.dart';
import 'package:smart_class/screens/classes/classes_screen.dart';
import 'package:smart_class/screens/grades/grades_screen.dart';
import 'package:smart_class/screens/legal/legal_doc_screen.dart';
import 'package:smart_class/screens/lessons/lesson_progress_screen.dart';
import 'package:smart_class/screens/salary/salary_screen.dart';
import 'package:smart_class/screens/semesters/semesters_screen.dart';
import 'package:smart_class/theme/app_theme.dart';
import 'package:smart_class/theme/mascot_assets.dart';
import 'package:smart_class/widgets/app_brand.dart';
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
            const LargeTitle('我的'),
            GroupedSection(
              header: '班级',
              children: [
                GroupedTile(
                  title: '班级管理',
                  subtitle:
                      '${ctrl.profile.displayTitle} · ${ctrl.currentClass?.roleLabel ?? ''}',
                  onTap: () => _push(context, const ClassesScreen()),
                ),
                GroupedTile(
                  title: '本班功能',
                  subtitle: '自定义首页与入口显示',
                  onTap: () => _push(context, const ClassFeaturesScreen()),
                ),
              ],
            ),
            const SizedBox(height: 18),
            GroupedSection(
              header: '个人',
              children: [
                GroupedTile(
                  title: '每月工资',
                  subtitle: ctrl.salaryRecords.isEmpty
                      ? '记录基本工资、补贴与扣款'
                      : '共 ${ctrl.salaryRecords.length} 条',
                  onTap: () => _push(context, const SalaryScreen()),
                ),
              ],
            ),
            const SizedBox(height: 18),
            if ([
              ClassFeatureIds.attendance,
              ClassFeatureIds.rollCall,
              ClassFeatureIds.homework,
              ClassFeatureIds.duty,
            ].any(ctrl.isFeatureVisible))
            GroupedSection(
              header: '日常工作',
              children: [
                if (ctrl.isFeatureVisible(ClassFeatureIds.attendance))
                  GroupedTile(
                    title: '考勤',
                    subtitle: '今日出勤登记',
                    onTap: () => _push(context, const AttendanceScreen()),
                  ),
                if (ctrl.isFeatureVisible(ClassFeatureIds.rollCall))
                  GroupedTile(
                    title: '随机点名',
                    onTap: () => _push(context, const RollCallScreen()),
                  ),
                if (ctrl.isFeatureVisible(ClassFeatureIds.homework))
                  GroupedTile(
                    title: '作业检查',
                    onTap: () => _push(context, const HomeworkScreen()),
                  ),
                if (ctrl.isFeatureVisible(ClassFeatureIds.duty))
                  GroupedTile(
                    title: '值日安排',
                    onTap: () => _push(context, const DutyScreen()),
                  ),
              ],
            ),
            if ([
              ClassFeatureIds.grades,
              ClassFeatureIds.workLogs,
              ClassFeatureIds.timetable,
              ClassFeatureIds.seating,
              ClassFeatureIds.lessonProgress,
            ].any(ctrl.isFeatureVisible)) ...[
            const SizedBox(height: 18),
            GroupedSection(
              header: '教学管理',
              children: [
                if (ctrl.isFeatureVisible(ClassFeatureIds.grades))
                  GroupedTile(
                    title: '成绩分析',
                    subtitle: ctrl.exams.isEmpty
                        ? '期末 · 半期 · 月考存档'
                        : '共 ${ctrl.exams.length} 次考试',
                    onTap: () => _push(context, const GradesScreen()),
                  ),
                if (ctrl.isFeatureVisible(ClassFeatureIds.lessonProgress))
                  GroupedTile(
                    title: '授课进度',
                    subtitle: ctrl.lessonUnits.isEmpty
                        ? '课时进度 · PPT 课件存档'
                        : '共 ${ctrl.lessonUnits.length} 课 · ${ctrl.lessonFilesByUnit.values.fold<int>(0, (a, b) => a + b.length)} 个课件',
                    onTap: () => _push(context, const LessonProgressScreen()),
                  ),
                if (ctrl.isFeatureVisible(ClassFeatureIds.workLogs))
                  GroupedTile(
                    title: '工作留痕',
                    subtitle: ctrl.workLogs.isEmpty
                        ? '班会 · 谈话 · 家访等'
                        : '共 ${ctrl.workLogs.length} 条',
                    onTap: () => _push(context, const WorkLogsScreen()),
                  ),
                if (ctrl.isFeatureVisible(ClassFeatureIds.timetable))
                  GroupedTile(
                    title: '课程表',
                    subtitle: ctrl.timetable.isEmpty
                        ? '点格子填写科目'
                        : '已排 ${ctrl.timetable.where((s) => s.subject.trim().isNotEmpty).length} 节',
                    onTap: () => _push(context, const TimetableScreen()),
                  ),
                if (ctrl.isFeatureVisible(ClassFeatureIds.seating))
                  GroupedTile(
                    title: '座位表',
                    subtitle:
                        '${ctrl.profile.seatRows}×${ctrl.profile.seatCols}',
                    onTap: () => _push(context, const SeatingScreen()),
                  ),
              ],
            ),
            ],
            if ([
              ClassFeatureIds.groups,
              ClassFeatureIds.rewards,
              ClassFeatureIds.countdowns,
              ClassFeatureIds.fund,
              ClassFeatureIds.notes,
              ClassFeatureIds.weeklyReport,
            ].any(ctrl.isFeatureVisible)) ...[
            const SizedBox(height: 18),
            GroupedSection(
              header: '班级事务',
              children: [
                if (ctrl.isFeatureVisible(ClassFeatureIds.groups))
                  GroupedTile(
                    title: '小组',
                    subtitle: ctrl.groupNames.isEmpty
                        ? '未设置'
                        : '${ctrl.groupNames.length} 个小组',
                    onTap: () => _push(context, const GroupsScreen()),
                  ),
                if (ctrl.isFeatureVisible(ClassFeatureIds.rewards))
                  GroupedTile(
                    title: '积分兑换',
                    onTap: () => _push(context, const RewardsScreen()),
                  ),
                if (ctrl.isFeatureVisible(ClassFeatureIds.countdowns))
                  GroupedTile(
                    title: '倒数日',
                    subtitle: ctrl.nearestCountdown == null
                        ? '可设置多个倒计时'
                        : '${ctrl.upcomingCountdowns.length} 个进行中',
                    onTap: () => _push(context, const CountdownScreen()),
                  ),
                if (ctrl.isFeatureVisible(ClassFeatureIds.fund))
                  GroupedTile(
                    title: '班费',
                    subtitle: '余额 ${ctrl.fundBalance}',
                    onTap: () => _push(context, const FundScreen()),
                  ),
                if (ctrl.isFeatureVisible(ClassFeatureIds.notes))
                  GroupedTile(
                    title: '班级记事',
                    onTap: () => _push(context, const NotesScreen()),
                  ),
                if (ctrl.isFeatureVisible(ClassFeatureIds.weeklyReport))
                  GroupedTile(
                    title: '本周概况',
                    onTap: () => _push(context, const WeeklyReportScreen()),
                  ),
              ],
            ),
            ],
            const SizedBox(height: 18),
            GroupedSection(
              header: '外观',
              children: [
                GroupedTile(
                  title: '主题',
                  subtitle: themeCtrl.mode.label,
                  leading: themeCtrl.mode == AppThemeMode.paddi
                      ? const PaddiThemePreview()
                      : null,
                  onTap: () => _pickTheme(context),
                ),
              ],
            ),
            const SizedBox(height: 18),
            if (ctrl.isFeatureVisible(ClassFeatureIds.points)) ...[
              const SizedBox(height: 18),
              GroupedSection(
                header: '设置',
                children: [
                  GroupedTile(
                    title: '积分规则',
                    subtitle: ctrl.pointPresets.isEmpty
                        ? '自定义加分 / 扣分项'
                        : '${ctrl.pointPresets.where((p) => p.delta >= 0).length} 条加分 · ${ctrl.pointPresets.where((p) => p.delta < 0).length} 条扣分',
                    onTap: () => _push(context, const PointRulesScreen()),
                  ),
                  if (ctrl.isFeatureVisible(ClassFeatureIds.settlements)) ...[
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
                  ],
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
                  GroupedTile(
                    title: '清空全部积分',
                    titleColor: AppTheme.destructive,
                    onTap: () => _resetPoints(context),
                  ),
                ],
              ),
            ],
            const SizedBox(height: 18),
            GroupedSection(
              header: '数据',
              footer: '学期存档可查阅历史；备份用于换机迁移。',
              children: [
                if (ctrl.isFeatureVisible(ClassFeatureIds.semesters))
                  GroupedTile(
                    title: '学期',
                    subtitle: ctrl.activeSemester == null
                        ? '按学期存档与新开'
                        : '当前：${ctrl.activeSemester!.title}',
                    onTap: () => _push(context, const SemestersScreen()),
                  ),
                GroupedTile(
                  title: '导出班级学期汇总',
                  subtitle: 'Excel：概况、考勤、成绩、积分、留痕',
                  onTap: () async {
                    try {
                      final path =
                          await ctrl.exportClassSemesterReportFile();
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
                ),
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
            const SizedBox(height: 18),
            GroupedSection(
              header: '关于',
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
                  child: Row(
                    children: [
                      const AppLogo(size: 48),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              AppInfo.name,
                              style: TextStyle(
                                fontSize: 17,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              AppInfo.tagline,
                              style: TextStyle(
                                fontSize: 13,
                                color: AppTheme.tertiaryLabel,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              AppInfo.versionLabel,
                              style: TextStyle(
                                fontSize: 12,
                                color: AppTheme.quaternaryLabel,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                GroupedTile(
                  title: '用户协议',
                  onTap: () => _push(
                    context,
                    const LegalDocScreen(
                      title: LegalTexts.agreementTitle,
                      body: LegalTexts.userAgreement,
                    ),
                  ),
                ),
                GroupedTile(
                  title: '隐私政策',
                  onTap: () => _push(
                    context,
                    const LegalDocScreen(
                      title: LegalTexts.privacyTitle,
                      body: LegalTexts.privacyPolicy,
                    ),
                  ),
                ),
                GroupedTile(
                  title: '安全与合规使用提示',
                  onTap: () => _push(
                    context,
                    const LegalDocScreen(
                      title: LegalTexts.securityTipsTitle,
                      body: LegalTexts.securityTips,
                    ),
                  ),
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
                  '懒羊羊是少量贴纸点缀：图标照常，不整页换色',
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
