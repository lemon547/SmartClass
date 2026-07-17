import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:smart_class/providers/class_controller.dart';
import 'package:smart_class/screens/groups/group_edit_screen.dart';
import 'package:smart_class/screens/students/student_detail_screen.dart';
import 'package:smart_class/theme/app_icons.dart';
import 'package:smart_class/theme/app_theme.dart';
import 'package:smart_class/widgets/apple_widgets.dart';

class GroupsScreen extends StatelessWidget {
  const GroupsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final ctrl = context.watch<ClassController>();
    final groups = ctrl.groupNames;

    return Scaffold(
      appBar: PageAppBar(
        title: const Text('小组'),
        actions: [
          IconButton(
            onPressed: () => GroupEditScreen.push(context),
            icon: const Icon(AppIcons.plus),
            tooltip: '添加小组',
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.only(top: 8, bottom: 28),
        children: [
          if (groups.isEmpty)
            Padding(
              padding: const EdgeInsets.all(40),
              child: Center(
                child: Column(
                  children: [
                    Text(
                      '暂无小组',
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w500,
                        color: AppTheme.secondaryLabel,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '点击右上角添加小组，从未分组学生中选人组成小组',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: AppTheme.tertiaryLabel),
                    ),
                  ],
                ),
              ),
            )
          else
            for (final g in groups) ...[
              GroupedSection(
                header: '$g · ${ctrl.studentsInGroup(g).length} 人',
                children: [
                  GroupedTile(
                    title: '编辑小组',
                    trailing: const Icon(AppIcons.chevronRight, size: 18),
                    onTap: () => GroupEditScreen.push(context, groupName: g),
                  ),
                  for (final s in ctrl.studentsInGroup(g))
                    GroupedTile(
                      title: s.name,
                      subtitle:
                          s.studentNo.isEmpty ? null : '学号 ${s.studentNo}',
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) =>
                              StudentDetailScreen(studentId: s.id),
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 14),
            ],
        ],
      ),
    );
  }
}
