import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:smart_class/providers/class_controller.dart';
import 'package:smart_class/screens/classes/classes_screen.dart';
import 'package:smart_class/theme/app_icons.dart';
import 'package:smart_class/theme/app_theme.dart';

/// 班级切换：底部列表（不下钻全屏页）
Future<void> showClassSwitcherSheet(BuildContext context) async {
  final ctrl = context.read<ClassController>();
  if (ctrl.classes.isEmpty) {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const ClassesScreen()),
    );
    return;
  }

  await showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (ctx) {
      final watch = ctx.watch<ClassController>();
      final currentId = watch.currentClass?.id;
      final maxH = MediaQuery.sizeOf(ctx).height * 0.55;
      return SafeArea(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxHeight: maxH),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 4, 12, 8),
                child: Row(
                  children: [
                    const Expanded(
                      child: Text(
                        '切换班级',
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    TextButton(
                      onPressed: () {
                        Navigator.pop(ctx);
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => const ClassesScreen(),
                          ),
                        );
                      },
                      child: const Text('管理'),
                    ),
                  ],
                ),
              ),
              Flexible(
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: watch.classes.length,
                  itemBuilder: (_, i) {
                    final c = watch.classes[i];
                    final selected = c.id == currentId;
                    final letter = c.displayTitle.characters.isEmpty
                        ? '班'
                        : c.displayTitle.characters.first;
                    return ListTile(
                      leading: CircleAvatar(
                        backgroundColor: AppTheme.blue.withValues(alpha: 0.12),
                        foregroundColor: AppTheme.blue,
                        child: Text(
                          letter,
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                      ),
                      title: Text(c.displayTitle),
                      subtitle:
                          c.roleLabel.isEmpty ? null : Text(c.roleLabel),
                      trailing: selected
                          ? Icon(AppIcons.circleCheck, color: AppTheme.blue)
                          : null,
                      onTap: () async {
                        Navigator.pop(ctx);
                        if (!selected) {
                          await ctrl.switchClass(c.id);
                        }
                      },
                    );
                  },
                ),
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      );
    },
  );
}
