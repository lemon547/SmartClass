import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:smart_class/models/models.dart';
import 'package:smart_class/providers/class_controller.dart';
import 'package:smart_class/screens/classes/classes_screen.dart';
import 'package:smart_class/theme/app_icons.dart';
import 'package:smart_class/theme/app_theme.dart';
import 'package:smart_class/widgets/apple_widgets.dart';

/// 切换班级：独立全屏页（替代底部弹窗）
class ClassSwitcherScreen extends StatelessWidget {
  const ClassSwitcherScreen({super.key});

  static Future<void> open(BuildContext context) {
    return Navigator.of(context).push<void>(
      MaterialPageRoute(builder: (_) => const ClassSwitcherScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final ctrl = context.watch<ClassController>();
    final bySchool = <String, List<ManagedClass>>{};
    for (final c in ctrl.classes) {
      bySchool.putIfAbsent(c.schoolLabel, () => []).add(c);
    }
    final schools = bySchool.keys.toList()
      ..sort((a, b) {
        if (a == '未填写学校') return 1;
        if (b == '未填写学校') return -1;
        return a.compareTo(b);
      });

    return Scaffold(
      backgroundColor: AppTheme.bg,
      appBar: PageAppBar(
        title: const Text('切换班级'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const ClassesScreen()),
            ),
            child: const Text('管理'),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.only(bottom: 28, top: 8),
        children: [
          if (ctrl.classes.isEmpty)
            const Padding(
              padding: EdgeInsets.all(24),
              child: Center(
                child: Text('暂无班级，请前往管理添加'),
              ),
            )
          else ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
              child: Text(
                '共 ${ctrl.classes.length} 个班级，点选即可切换',
                style: TextStyle(
                  fontSize: 13,
                  color: AppTheme.tertiaryLabel,
                  height: 1.35,
                ),
              ),
            ),
            for (final school in schools) ...[
              GroupedSection(
                header: school,
                children: [
                  for (final c in bySchool[school]!)
                    GroupedTile(
                      leading: _ClassAvatar(cls: c),
                      title: c.displayTitle,
                      subtitle: c.roleLabel,
                      trailing: c.id == ctrl.currentClass?.id
                          ? Icon(AppIcons.circleCheck, color: AppTheme.blue)
                          : null,
                      onTap: () async {
                        if (c.id == ctrl.currentClass?.id) {
                          Navigator.pop(context);
                          return;
                        }
                        await ctrl.switchClass(c.id);
                        if (context.mounted) {
                          Navigator.pop(context);
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('已切换到 ${c.displayTitle}')),
                          );
                        }
                      },
                    ),
                ],
              ),
              const SizedBox(height: 12),
            ],
          ],
        ],
      ),
    );
  }
}

class _ClassAvatar extends StatelessWidget {
  const _ClassAvatar({required this.cls});

  final ManagedClass cls;

  @override
  Widget build(BuildContext context) {
    final raw = cls.school.trim().isNotEmpty
        ? cls.school.trim()
        : cls.displayTitle;
    final letter = raw.isNotEmpty ? raw.substring(0, 1) : '班';
    return Container(
      width: 36,
      height: 36,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: AppTheme.blue.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        letter,
        style: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w700,
          color: AppTheme.blue,
        ),
      ),
    );
  }
}
