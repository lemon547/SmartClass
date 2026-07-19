import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:smart_class/services/file_export.dart';
import 'package:provider/provider.dart';
import 'package:smart_class/app_info.dart';
import 'package:smart_class/models/models.dart';
import 'package:smart_class/providers/class_controller.dart';
import 'package:smart_class/providers/theme_controller.dart';
import 'package:smart_class/legal/legal_texts.dart';
import 'package:smart_class/providers/ai_settings_controller.dart';
import 'package:smart_class/screens/legal/legal_doc_screen.dart';
import 'package:smart_class/screens/more/ai_settings_screen.dart';
import 'package:smart_class/screens/salary/salary_screen.dart';
import 'package:smart_class/screens/title_materials/title_materials_screen.dart';
import 'package:smart_class/theme/app_icons.dart';
import 'package:smart_class/theme/app_theme.dart';
import 'package:smart_class/theme/mascot_assets.dart';
import 'package:smart_class/widgets/app_brand.dart';
import 'package:smart_class/widgets/apple_widgets.dart';
import 'package:smart_class/widgets/paddi_mascot.dart';

/// 老师个人中心：档案、工资、外观、备份、关于
class MoreScreen extends StatelessWidget {
  const MoreScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final ctrl = context.watch<ClassController>();
    final themeCtrl = context.watch<ThemeController>();
    final aiCtrl = context.watch<AiSettingsController>();
    final current = ctrl.currentClass;

    return Scaffold(
      backgroundColor: AppTheme.bg,
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.only(bottom: 28),
          children: [
            const SizedBox(height: 8),
            const Padding(
              padding: EdgeInsets.fromLTRB(20, 0, 20, 4),
              child: Text(
                '我的',
                style: TextStyle(
                  fontSize: 34,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.5,
                ),
              ),
            ),
            const SizedBox(height: 12),
            _TeacherProfileCard(ctrl: ctrl, current: current),
            const SizedBox(height: 20),
            GroupedSection(
              header: '个人',
              children: [
                GroupedTile(
                  leading: Icon(AppIcons.folder, color: AppTheme.blue, size: 22),
                  title: '职称材料归档',
                  subtitle: '按年份与分类保存、打开与分享',
                  onTap: () => _push(context, const TitleMaterialsScreen()),
                ),
                GroupedTile(
                  leading: Icon(AppIcons.wallet, color: AppTheme.blue, size: 22),
                  title: '每月工资',
                  subtitle: ctrl.salaryRecords.isEmpty
                      ? '记录基本工资、补贴与扣款'
                      : '已记录 ${ctrl.salaryRecords.length} 个月',
                  onTap: () => _push(context, const SalaryScreen()),
                ),
                GroupedTile(
                  leading: Icon(AppIcons.settings, color: AppTheme.blue, size: 22),
                  title: '外观主题',
                  subtitle: themeCtrl.mode.label,
                  trailing: themeCtrl.mode == AppThemeMode.paddi
                      ? const PaddiThemePreview()
                      : null,
                  onTap: () => _pickTheme(context),
                ),
                GroupedTile(
                  leading: Icon(AppIcons.sparkles, color: AppTheme.blue, size: 22),
                  title: 'AI 助手形象',
                  subtitle: themeCtrl.fabMascotOption.label,
                  trailing: Image.asset(
                    themeCtrl.fabMascotAsset,
                    width: 36,
                    height: 36,
                    fit: BoxFit.contain,
                    gaplessPlayback: true,
                  ),
                  onTap: () => _pickFabMascot(context),
                ),
                GroupedTile(
                  leading: Icon(AppIcons.sparkles, color: AppTheme.blue, size: 22),
                  title: 'AI 助手',
                  subtitle: aiCtrl.hasApiKey
                      ? 'DeepSeek · ${aiCtrl.maskedApiKey}'
                      : '配置 DeepSeek，润色工作留痕',
                  onTap: () => _push(context, const AiSettingsScreen()),
                ),
              ],
            ),
            const SizedBox(height: 16),
            GroupedSection(
              header: '数据与安全',
              footer: '备份包含全部班级与老师数据，可用于换机迁移。',
              children: [
                GroupedTile(
                  leading: Icon(AppIcons.download, color: AppTheme.blue, size: 22),
                  title: '导出备份',
                  subtitle: '保存到本机',
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
                  leading: Icon(AppIcons.upload, color: AppTheme.blue, size: 22),
                  title: '导入备份',
                  subtitle: '从 JSON 恢复',
                  onTap: () => _importBackup(context),
                ),
              ],
            ),
            const SizedBox(height: 16),
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
            const SizedBox(height: 20),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                children: [
                  const AppBrandMark(size: 72),
                  const SizedBox(height: 8),
                  Text(
                    AppInfo.name,
                    style: TextStyle(
                      fontSize: 13,
                      color: AppTheme.secondaryLabel,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${AppInfo.versionLabel} · ${AppInfo.tagline}',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 11,
                      color: AppTheme.quaternaryLabel,
                      height: 1.4,
                    ),
                  ),
                ],
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

  Future<void> _pickFabMascot(BuildContext context) async {
    final themeCtrl = context.read<ThemeController>();
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (ctx) {
        final maxH = MediaQuery.sizeOf(ctx).height * 0.72;
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
            child: ConstrainedBox(
              constraints: BoxConstraints(maxHeight: maxH),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(4, 4, 4, 8),
                    child: Text(
                      'AI 助手形象',
                      style: Theme.of(ctx).textTheme.titleMedium,
                    ),
                  ),
                  Text(
                    '悬浮入口与首页 AI 助教会同步使用',
                    style: TextStyle(fontSize: 13, color: AppTheme.tertiaryLabel),
                  ),
                  const SizedBox(height: 12),
                  Flexible(
                    child: GridView.count(
                      crossAxisCount: 2,
                      mainAxisSpacing: 10,
                      crossAxisSpacing: 10,
                      childAspectRatio: 1.05,
                      children: [
                        for (final opt in MascotAssets.fabOptions)
                          DecoratedBox(
                            decoration: BoxDecoration(
                              color: themeCtrl.fabMascotId == opt.id
                                  ? AppTheme.blue.withValues(alpha: 0.10)
                                  : AppTheme.fill,
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(
                                color: themeCtrl.fabMascotId == opt.id
                                    ? AppTheme.blue
                                    : AppTheme.separator,
                              ),
                            ),
                            child: Material(
                              color: Colors.transparent,
                              child: InkWell(
                                borderRadius: BorderRadius.circular(14),
                                onTap: () async {
                                  await themeCtrl.setFabMascotId(opt.id);
                                  if (ctx.mounted) Navigator.pop(ctx);
                                },
                                child: Padding(
                                  padding: const EdgeInsets.all(10),
                                  child: Column(
                                    children: [
                                      Expanded(
                                        child: Image.asset(
                                          opt.asset,
                                          fit: BoxFit.contain,
                                          gaplessPlayback: true,
                                        ),
                                      ),
                                      const SizedBox(height: 6),
                                      Text(
                                        opt.label,
                                        style: TextStyle(
                                          fontSize: 14,
                                          fontWeight:
                                              themeCtrl.fabMascotId == opt.id
                                                  ? FontWeight.w600
                                                  : FontWeight.w500,
                                        ),
                                      ),
                                      Text(
                                        opt.animated ? '动态' : '静态',
                                        style: TextStyle(
                                          fontSize: 11,
                                          color: AppTheme.tertiaryLabel,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
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
                  child: Text('外观主题', style: Theme.of(ctx).textTheme.titleMedium),
                ),
                for (final mode in AppThemeMode.values) ...[
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

class _TeacherProfileCard extends StatelessWidget {
  const _TeacherProfileCard({required this.ctrl, required this.current});

  final ClassController ctrl;
  final ManagedClass? current;

  @override
  Widget build(BuildContext context) {
    final school = current?.school.trim() ?? '';
    final title = school.isNotEmpty ? school : '教师工作台';
    final roleTags = <String>{};
    for (final c in ctrl.classes) {
      roleTags.addAll(c.roleTags);
    }
    final classLine = current?.displayTitle ?? '尚未选择班级';

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: AppTheme.surface,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 56,
                    height: 56,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: AppTheme.blue.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(28),
                    ),
                    child: Text(
                      school.isNotEmpty ? school.substring(0, 1) : '师',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.blue,
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                            letterSpacing: -0.3,
                          ),
                        ),
                        const SizedBox(height: 6),
                        if (roleTags.isNotEmpty)
                          Wrap(
                            spacing: 6,
                            runSpacing: 4,
                            children: [
                              for (final tag in roleTags)
                                _RoleChip(label: tag),
                            ],
                          )
                        else
                          Text(
                            '教师',
                            style: TextStyle(
                              fontSize: 13,
                              color: AppTheme.secondaryLabel,
                            ),
                          ),
                        const SizedBox(height: 6),
                        Text(
                          '当前：$classLine',
                          style: TextStyle(
                            fontSize: 13,
                            color: AppTheme.tertiaryLabel,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Divider(height: 1, color: AppTheme.separator),
              const SizedBox(height: 14),
              Row(
                children: [
                  _ProfileStat(
                    value: '${ctrl.classes.length}',
                    label: '任教班级',
                  ),
                  _ProfileStat(
                    value: '${ctrl.students.length}',
                    label: '当前学生',
                  ),
                  _ProfileStat(
                    value: '${ctrl.salaryRecords.length}',
                    label: '工资记录',
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RoleChip extends StatelessWidget {
  const _RoleChip({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: AppTheme.fill,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 12,
          color: AppTheme.secondaryLabel,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }
}

class _ProfileStat extends StatelessWidget {
  const _ProfileStat({required this.value, required this.label});

  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        children: [
          Text(
            value,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w600,
              letterSpacing: -0.3,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: TextStyle(fontSize: 12, color: AppTheme.tertiaryLabel),
          ),
        ],
      ),
    );
  }
}
