import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:smart_class/providers/class_controller.dart';
import 'package:smart_class/screens/grades/exam_detail_screen.dart';
import 'package:smart_class/theme/app_theme.dart';
import 'package:smart_class/widgets/apple_widgets.dart';

/// 尚未录入成绩的学生名单。
class ExamMissingScreen extends StatelessWidget {
  const ExamMissingScreen({super.key, required this.examId});

  final String examId;

  static void push(BuildContext context, {required String examId}) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ExamMissingScreen(examId: examId),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final ctrl = context.watch<ClassController>();
    final exam = ctrl.examById(examId);
    if (exam == null) {
      return Scaffold(
        appBar: PageAppBar(title: const Text('缺考名单')),
        body: const Center(child: Text('考试不存在')),
      );
    }

    final scoredIds =
        ctrl.scoresOfExam(examId).map((s) => s.studentId).toSet();
    final missing = [
      for (final stu in ctrl.students)
        if (!scoredIds.contains(stu.id)) stu,
    ];

    return Scaffold(
      appBar: PageAppBar(title: const Text('缺考名单')),
      body: ListView(
        padding: const EdgeInsets.only(bottom: 28, top: 8),
        children: [
          GroupedSection(
            header: '${exam.title} · ${missing.length} 人未录入',
            footer: missing.isEmpty
                ? '全班成绩已录入'
                : '可在成绩表中补录，或重新导入 Excel',
            children: [
              if (missing.isEmpty)
                Padding(
                  padding: const EdgeInsets.all(18),
                  child: Text(
                    '暂无缺考',
                    style: TextStyle(color: AppTheme.tertiaryLabel),
                  ),
                )
              else
                for (final stu in missing)
                  GroupedTile(
                    title: stu.name,
                    subtitle: stu.studentNo.isEmpty ? null : stu.studentNo,
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => ExamDetailScreen(
                          examId: examId,
                          initialTab: 0,
                        ),
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
