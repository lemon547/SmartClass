import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:smart_class/providers/class_controller.dart';
import 'package:smart_class/screens/grades/exam_actions.dart';
import 'package:smart_class/theme/app_icons.dart';
import 'package:smart_class/theme/app_theme.dart';
import 'package:smart_class/widgets/apple_widgets.dart';

/// 单场考试的原始文件列表（试卷、答题卡、扫描件等）。
class ExamFilesScreen extends StatelessWidget {
  const ExamFilesScreen({super.key, required this.examId});

  final String examId;

  static void push(BuildContext context, {required String examId}) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ExamFilesScreen(examId: examId),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final ctrl = context.watch<ClassController>();
    final exam = ctrl.examById(examId);
    if (exam == null) {
      return Scaffold(
        appBar: PageAppBar(title: const Text('原始文件')),
        body: const Center(child: Text('考试不存在')),
      );
    }

    final files = ctrl.filesOfExam(examId);

    return Scaffold(
      appBar: PageAppBar(
        title: const Text('原始文件'),
        actions: [
          IconButton(
            tooltip: '上传',
            onPressed: () => ExamActions.pickExamFiles(context, examId),
            icon: const Icon(AppIcons.upload),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.only(bottom: 28, top: 8),
        children: [
          if (files.isEmpty)
            Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                children: [
                  Icon(AppIcons.folder, size: 40, color: AppTheme.quaternaryLabel),
                  const SizedBox(height: 12),
                  Text(
                    '还没有存档文件',
                    style: TextStyle(color: AppTheme.tertiaryLabel),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '可上传试卷 PDF、答题卡照片、扫描件等',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 13,
                      color: AppTheme.quaternaryLabel,
                    ),
                  ),
                  const SizedBox(height: 16),
                  FilledButton.icon(
                    onPressed: () => ExamActions.pickExamFiles(context, examId),
                    icon: const Icon(AppIcons.upload, size: 18),
                    label: const Text('上传文件'),
                  ),
                ],
              ),
            )
          else
            ExamActions.filesSection(context, ctrl, exam),
        ],
      ),
    );
  }
}
