import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:smart_class/app_info.dart';
import 'package:smart_class/providers/class_controller.dart';
import 'package:smart_class/providers/theme_controller.dart';
import 'package:smart_class/legal/legal_texts.dart';
import 'package:smart_class/screens/legal/legal_doc_screen.dart';
import 'package:smart_class/screens/salary/salary_screen.dart';
import 'package:smart_class/theme/app_theme.dart';
import 'package:smart_class/theme/mascot_assets.dart';
import 'package:smart_class/widgets/app_brand.dart';
import 'package:smart_class/widgets/apple_widgets.dart';
import 'package:smart_class/widgets/paddi_mascot.dart';

/// 老师个人中心：工资、外观、备份、关于（不含班务功能）
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
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 0),
              child: Text(
                '个人事务与 App 设置。考勤、成绩、授课进度等班务功能请前往底部「班级」。',
                style: TextStyle(
                  fontSize: 13,
                  color: AppTheme.secondaryLabel,
                  height: 1.45,
                ),
              ),
            ),
            const SizedBox(height: 16),
            GroupedSection(
              header: '收入',
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
            GroupedSection(
              header: '数据',
              footer: '备份包含全部班级与老师数据，用于换机迁移。',
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
