import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:smart_class/providers/class_controller.dart';
import 'package:smart_class/screens/students/student_detail_screen.dart';
import 'package:smart_class/theme/app_theme.dart';
import 'package:smart_class/widgets/apple_widgets.dart';

class GroupsScreen extends StatelessWidget {
  const GroupsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final ctrl = context.watch<ClassController>();
    final groups = ctrl.groupNames;
    final ungrouped = ctrl.students.where((s) => s.groupName.isEmpty).toList();

    return Scaffold(
      appBar: PageAppBar(title: const Text('小组')),
      body: ListView(
        padding: const EdgeInsets.only(top: 8, bottom: 28),
        children: [
          if (groups.isEmpty && ungrouped.isEmpty)
            Padding(
              padding: EdgeInsets.all(40),
              child: Center(
                child: Text('在学生资料里填写「小组」即可分组',
                    style: TextStyle(color: AppTheme.tertiaryLabel)),
              ),
            ),
          for (final g in groups) ...[
            GroupedSection(
              header: '$g · ${ctrl.studentsInGroup(g).length} 人',
              children: [
                for (final s in ctrl.studentsInGroup(g))
                  GroupedTile(
                    title: s.name,
                    subtitle: s.studentNo.isEmpty ? null : '学号 ${s.studentNo}',
                    trailing: Text('${s.points}'),
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => StudentDetailScreen(studentId: s.id),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 14),
          ],
          if (ungrouped.isNotEmpty)
            GroupedSection(
              header: '未分组 · ${ungrouped.length} 人',
              children: [
                for (final s in ungrouped)
                  GroupedTile(
                    title: s.name,
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => StudentDetailScreen(studentId: s.id),
                      ),
                    ),
                  ),
              ],
            ),
        ],
      ),
    );
  }
}
