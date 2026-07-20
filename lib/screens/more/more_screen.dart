import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:smart_class/app_info.dart';
import 'package:smart_class/legal/legal_texts.dart';
import 'package:smart_class/providers/ai_settings_controller.dart';
import 'package:smart_class/providers/class_controller.dart';
import 'package:smart_class/providers/theme_controller.dart';
import 'package:smart_class/screens/legal/legal_doc_screen.dart';
import 'package:smart_class/screens/more/ai_settings_screen.dart';
import 'package:smart_class/screens/salary/salary_screen.dart';
import 'package:smart_class/screens/title_materials/title_materials_screen.dart';
import 'package:smart_class/services/file_export.dart';
import 'package:smart_class/theme/app_icons.dart';
import 'package:smart_class/theme/app_theme.dart';
import 'package:smart_class/theme/mascot_assets.dart';
import 'package:smart_class/widgets/apple_widgets.dart';
import 'package:smart_class/widgets/app_toast.dart';
import 'package:smart_class/widgets/paddi_mascot.dart';

/// 老师个人中心：档案、工资、外观、备份、关于
class MoreScreen extends StatelessWidget {
  const MoreScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final ctrl = context.watch<ClassController>();
    final themeCtrl = context.watch<ThemeController>();
    final aiCtrl = context.watch<AiSettingsController>();

    return Scaffold(
      backgroundColor: AppTheme.bg,
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.only(bottom: 28),
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(20, 8, 20, 16),
              child: Text(
                '我的',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.4,
                ),
              ),
            ),

            GroupedSection(
              header: '工作',
              children: [
                GroupedTile(
                  leading: Icon(AppIcons.folder, color: AppTheme.blue, size: 22),
                  title: '职称材料归档',
                  onTap: () => _push(context, const TitleMaterialsScreen()),
                ),
                GroupedTile(
                  leading: Icon(AppIcons.wallet, color: AppTheme.blue, size: 22),
                  title: '每月工资',
                  subtitle: ctrl.salaryRecords.isEmpty
                      ? null
                      : '已记录 ${ctrl.salaryRecords.length} 个月',
                  onTap: () => _push(context, const SalaryScreen()),
                ),
              ],
            ),
            const SizedBox(height: 20),

            GroupedSection(
              header: '设置',
              children: [
                GroupedTile(
                  leading:
                      Icon(AppIcons.settings, color: AppTheme.blue, size: 22),
                  title: '外观主题',
                  subtitle: themeCtrl.mode.label,
                  trailing: themeCtrl.mode == AppThemeMode.paddi
                      ? const PaddiThemePreview()
                      : null,
                  onTap: () => _pickTheme(context),
                ),
                GroupedTile(
                  leading:
                      Icon(AppIcons.sparkles, color: AppTheme.blue, size: 22),
                  title: 'AI 助手',
                  subtitle: aiCtrl.hasApiKey ? '已配置' : '未配置',
                  onTap: () => _push(context, const AiSettingsScreen()),
                ),
              ],
            ),
            const SizedBox(height: 20),

            GroupedSection(
              header: '数据',
              footer: '备份包含全部班级与老师数据，可用于换机迁移。',
              children: [
                GroupedTile(
                  leading:
                      Icon(AppIcons.download, color: AppTheme.blue, size: 22),
                  title: '导出备份',
                  onTap: () async {
                    try {
                      final saved = await FileExport.saveGenerated(
                        () => ctrl.exportBackupFile(),
                        dialogTitle: '保存备份',
                      );
                      if (!context.mounted) return;
                      FileExport.showSavedSnackBar(context, saved);
                    } catch (e) {
                      FileExport.showErrorSnackBar(context, e);
                    }
                  },
                ),
                GroupedTile(
                  leading:
                      Icon(AppIcons.upload, color: AppTheme.blue, size: 22),
                  title: '导入备份',
                  onTap: () => _importBackup(context),
                ),
              ],
            ),
            const SizedBox(height: 20),

            GroupedSection(
              header: '关于',
              children: [
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
                  title: '安全协议',
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
            const SizedBox(height: 24),
            Center(
              child: Text(
                '${AppInfo.name} ${AppInfo.versionLabel}',
                style: TextStyle(
                  fontSize: 12,
                  color: AppTheme.quaternaryLabel,
                ),
              ),
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
      showDragHandle: true,
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(4, 4, 4, 12),
                  child: Text(
                    '外观主题',
                    style: Theme.of(ctx).textTheme.titleMedium,
                  ),
                ),
                for (final mode in AppThemeMode.selectable) ...[
                  Material(
                    color: themeCtrl.mode == mode
                        ? AppTheme.blue.withValues(alpha: 0.08)
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(12),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(12),
                      onTap: () async {
                        await themeCtrl.setMode(mode);
                        if (ctx.mounted) Navigator.pop(ctx);
                      },
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 12,
                        ),
                        child: Row(
                          children: [
                            if (mode == AppThemeMode.paddi)
                              const PaddiMascot(
                                asset: MascotAssets.emote,
                                height: 40,
                                force: true,
                              )
                            else
                              Container(
                                width: 40,
                                height: 40,
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
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: AppTheme.separator),
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
                                      fontSize: 16,
                                      fontWeight: themeCtrl.mode == mode
                                          ? FontWeight.w600
                                          : FontWeight.w400,
                                    ),
                                  ),
                                  Text(
                                    mode.hint,
                                    style: TextStyle(
                                      fontSize: 12,
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
                  const SizedBox(height: 4),
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
      showDragHandle: true,
      builder: (ctx) {
        return Padding(
          padding: EdgeInsets.only(
            left: 20,
            right: 20,
            top: 8,
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
                  backgroundColor: AppTheme.destructive,
                ),
                onPressed: () async {
                  try {
                    jsonDecode(text.text);
                    await ctrl.importBackupJson(text.text);
                    if (ctx.mounted) {
                      Navigator.pop(ctx);
                      AppToast.success(context, '导入成功');
                    }
                  } catch (e) {
                    if (context.mounted) {
                      AppToast.error(context, '失败：$e');
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
