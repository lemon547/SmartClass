import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:provider/provider.dart';
import 'package:smart_class/models/models.dart';
import 'package:smart_class/providers/class_controller.dart';
import 'package:smart_class/screens/grades/grades_screen.dart';
import 'package:smart_class/screens/students/ai_student_import_screen.dart';
import 'package:smart_class/screens/students/student_detail_screen.dart';
import 'package:smart_class/screens/students/student_edit_screen.dart';
import 'package:smart_class/services/file_export.dart';
import 'package:smart_class/theme/app_icons.dart';
import 'package:smart_class/theme/app_theme.dart';
import 'package:smart_class/theme/mascot_assets.dart';
import 'package:smart_class/widgets/apple_widgets.dart';
import 'package:smart_class/widgets/paddi_mascot.dart';

/// 学生档案 Tab
class StudentsScreen extends StatefulWidget {
  const StudentsScreen({super.key});

  @override
  State<StudentsScreen> createState() => _StudentsScreenState();
}

class _StudentsScreenState extends State<StudentsScreen> {
  final _search = TextEditingController();
  final _searchFocus = FocusNode();
  String _query = '';

  @override
  void dispose() {
    _search.dispose();
    _searchFocus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ctrl = context.watch<ClassController>();
    final list = ctrl.searchStudents(_query);
    final title = ctrl.currentClass?.displayTitle ?? '本班';

    return Scaffold(
      backgroundColor: AppTheme.bg,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 8, 0),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          '学生档案',
                          style: TextStyle(
                            fontSize: 34,
                            fontWeight: FontWeight.w700,
                            letterSpacing: -0.5,
                            height: 1.1,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${ctrl.students.length} 人 · $title',
                          style: TextStyle(
                            fontSize: 13,
                            color: AppTheme.tertiaryLabel,
                          ),
                        ),
                      ],
                    ),
                  ),
                  TextButton.icon(
                    onPressed: () => _editStudent(context),
                    icon: Icon(AppIcons.plus, size: 18, color: AppTheme.blue),
                    label: Text('添加', style: TextStyle(color: AppTheme.blue)),
                  ),
                  IconButton(
                    tooltip: '搜索',
                    onPressed: () => _searchFocus.requestFocus(),
                    icon: Icon(AppIcons.search, color: AppTheme.secondaryLabel),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),
            SearchField(
              controller: _search,
              focusNode: _searchFocus,
              hint: '搜索姓名或学号',
              onChanged: (v) => setState(() => _query = v),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 8),
              child: Row(
                children: [
                  Expanded(
                    child: _SoftButton(
                      label: '导入名单 Excel',
                      color: const Color(0xFFE8F1FF),
                      textColor: AppTheme.blue,
                      onTap: () => _showRosterActions(context),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _SoftButton(
                      label: '成绩分析',
                      color: const Color(0xFFF0E8FF),
                      textColor: const Color(0xFF5856D6),
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => const GradesScreen()),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: list.isEmpty
                  ? Center(
                      child: PaddiEmptyHint(
                        message: ctrl.students.isEmpty
                            ? '点右上角添加学生，或导入名单'
                            : '没有匹配结果',
                        asset: MascotAssets.sleepy,
                      ),
                    )
                  : ListView(
                      padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                      children: [
                        Container(
                          decoration: BoxDecoration(
                            color: AppTheme.surface,
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Column(
                            children: [
                              SlidableAutoCloseBehavior(
                                child: Column(
                                  children: [
                                    for (var i = 0; i < list.length; i++) ...[
                                      if (i > 0)
                                        Divider(
                                          height: 1,
                                          indent: 68,
                                          endIndent: 16,
                                          color: AppTheme.separator,
                                        ),
                                      AppleDeleteSlidable(
                                        itemKey: ValueKey(list[i].id),
                                        confirmTitle: '删除 ${list[i].name}？',
                                        confirmMessage: '相关记录将一并删除。',
                                        onDelete: () =>
                                            ctrl.removeStudent(list[i].id),
                                        child: _StudentRow(
                                          student: list[i],
                                          talkCount: ctrl.talkLogCountFor(
                                            list[i].id,
                                          ),
                                          onTap: () =>
                                              Navigator.of(context).push(
                                            MaterialPageRoute(
                                              builder: (_) =>
                                                  StudentDetailScreen(
                                                studentId: list[i].id,
                                              ),
                                            ),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                            ],
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

  Future<void> _editStudent(BuildContext context, {Student? student}) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => StudentEditScreen(student: student),
      ),
    );
  }

  Future<void> _showRosterActions(BuildContext context) async {
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(8, 0, 8, 4),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
                child: Text(
                  '学生档案',
                  style: Theme.of(ctx).textTheme.titleMedium,
                ),
              ),
              ListTile(
                leading: Icon(AppIcons.sparkles, color: AppTheme.blue),
                title: const Text('AI 智能导入'),
                subtitle: const Text('Excel / Word / TXT / HTML 均可'),
                onTap: () {
                  Navigator.pop(ctx);
                  AiStudentImportScreen.push(context);
                },
              ),
              ListTile(
                leading: Icon(AppIcons.upload, color: AppTheme.blue),
                title: const Text('标准模板导入'),
                subtitle: const Text('选择已填好的 xlsx / csv'),
                onTap: () {
                  Navigator.pop(ctx);
                  _importExcel(context);
                },
              ),
              ListTile(
                leading: Icon(AppIcons.clipboardList, color: AppTheme.blue),
                title: const Text('粘贴名单'),
                subtitle: const Text('一行一个姓名，快速添加'),
                onTap: () {
                  Navigator.pop(ctx);
                  _batchAdd(context);
                },
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
                child: TextButton.icon(
                  style: TextButton.styleFrom(
                    foregroundColor: Colors.grey,
                    textStyle: const TextStyle(fontSize: 13),
                  ),
                  onPressed: () {
                    Navigator.pop(ctx);
                    _downloadTemplate(context);
                  },
                  icon: const Icon(
                    Icons.download_outlined,
                    size: 15,
                    color: Colors.grey,
                  ),
                  label: const Text('下载空白模板（用手机 WPS / Excel 填写）'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _downloadTemplate(BuildContext context) async {
    final ctrl = context.read<ClassController>();
    try {
      final saved = await FileExport.saveGenerated(
        () => ctrl.exportStudentTemplateFile(),
        dialogTitle: '保存学生导入模板',
      );
      if (!context.mounted) return;
      FileExport.showSavedSnackBar(context, saved);
    } catch (e) {
      FileExport.showErrorSnackBar(context, e);
    }
  }

  Future<void> _importExcel(BuildContext context) async {
    final ctrl = context.read<ClassController>();
    try {
      final picked = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: const ['xlsx', 'csv'],
        withData: true,
      );
      if (picked == null || picked.files.isEmpty) return;
      final file = picked.files.single;
      var bytes = file.bytes;
      if (bytes == null && file.path != null) {
        bytes = await File(file.path!).readAsBytes();
      }
      if (bytes == null) {
        if (!context.mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('无法读取文件')),
        );
        return;
      }

      final result = await ctrl.importStudentsFromBytes(
        bytes,
        fileName: file.name,
      );
      if (!context.mounted) return;
      final msg = StringBuffer(
        '新增 ${result.added}，更新 ${result.updated}',
      );
      if (result.warnings.isNotEmpty) {
        msg.write('\n${result.warnings.take(2).join('\n')}');
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(msg.toString())),
      );
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('导入失败：$e')),
      );
    }
  }

  Future<void> _batchAdd(BuildContext context) async {
    final text = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('粘贴名单'),
        content: TextField(
          controller: text,
          minLines: 6,
          maxLines: 12,
          decoration: const InputDecoration(
            hintText: '一行一个姓名',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('添加'),
          ),
        ],
      ),
    );
    if (ok != true || !context.mounted) return;
    final names = text.text
        .split(RegExp(r'[\r\n]+'))
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();
    text.dispose();
    if (names.isEmpty) return;
    final ctrl = context.read<ClassController>();
    await ctrl.batchAddStudents(names);
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('已添加 ${names.length} 人')),
    );
  }
}

class _SoftButton extends StatelessWidget {
  const _SoftButton({
    required this.label,
    required this.color,
    required this.textColor,
    required this.onTap,
  });

  final String label;
  final Color color;
  final Color textColor;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: color,
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: textColor,
            ),
          ),
        ),
      ),
    );
  }
}

class _StudentRow extends StatelessWidget {
  const _StudentRow({
    required this.student,
    required this.talkCount,
    required this.onTap,
  });

  final Student student;
  final int talkCount;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final parts = <String>[];
    if (student.studentNo.isNotEmpty) {
      parts.add('学号 ${student.studentNo}');
    }
    if (student.gender == '男' || student.gender == '女') {
      parts.add(student.gender);
    }
    parts.add('$talkCount 条谈话记录');

    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 12, 12, 12),
        child: Row(
          children: [
            StudentAvatar(name: student.name, gender: student.gender),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    student.name,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    parts.join(' · '),
                    style: TextStyle(
                      fontSize: 13,
                      color: AppTheme.secondaryLabel,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              AppIcons.chevronRight,
              size: 18,
              color: AppTheme.quaternaryLabel,
            ),
          ],
        ),
      ),
    );
  }
}
