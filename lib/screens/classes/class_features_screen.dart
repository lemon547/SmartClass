import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:smart_class/features/class_features.dart';
import 'package:smart_class/models/models.dart';
import 'package:smart_class/providers/class_controller.dart';
import 'package:smart_class/theme/app_theme.dart';
import 'package:smart_class/widgets/apple_widgets.dart';

/// 本班功能显隐（影响首页常用工具与「我的」入口）
class ClassFeaturesScreen extends StatelessWidget {
  const ClassFeaturesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final ctrl = context.watch<ClassController>();
    final role = ctrl.teacherRole;
    final teaching = ClassFeatures.all
        .where((f) => f.group == ClassFeatureGroup.teaching)
        .toList();
    final homeroom = ClassFeatures.all
        .where((f) => f.group == ClassFeatureGroup.homeroom)
        .toList();

    return Scaffold(
      appBar: AppBar(title: const Text('本班功能')),
      body: ListView(
        padding: const EdgeInsets.only(bottom: 28),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 4),
            child: Text(
              '当前角色：${role.label}。关闭的功能不会出现在首页常用工具和「我的」列表中。科任默认精简班务功能，可按需打开。',
              style: TextStyle(fontSize: 13, color: AppTheme.secondaryLabel, height: 1.4),
            ),
          ),
          GroupedSection(
            header: '教学',
            children: [
              for (final f in teaching)
                _FlagTile(feature: f, visible: ctrl.isFeatureVisible(f.id)),
            ],
          ),
          const SizedBox(height: 12),
          GroupedSection(
            header: '班务',
            children: [
              for (final f in homeroom)
                _FlagTile(feature: f, visible: ctrl.isFeatureVisible(f.id)),
            ],
          ),
        ],
      ),
    );
  }
}

class _FlagTile extends StatelessWidget {
  const _FlagTile({required this.feature, required this.visible});

  final ClassFeatureDef feature;
  final bool visible;

  @override
  Widget build(BuildContext context) {
    final ctrl = context.read<ClassController>();
    return SwitchListTile.adaptive(
      title: Text(feature.title),
      subtitle: feature.homeShortcut
          ? const Text('可出现在首页常用工具')
          : null,
      value: visible,
      onChanged: (v) => ctrl.setFeatureFlag(feature.id, v),
    );
  }
}
