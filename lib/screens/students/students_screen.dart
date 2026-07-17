import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:open_filex/open_filex.dart';
import 'package:provider/provider.dart';
import 'package:smart_class/models/models.dart';
import 'package:smart_class/providers/class_controller.dart';
import 'package:smart_class/screens/students/student_detail_screen.dart';
import 'package:smart_class/screens/students/student_edit_screen.dart';
import 'package:smart_class/theme/app_icons.dart';
import 'package:smart_class/theme/app_theme.dart';
import 'package:smart_class/theme/mascot_assets.dart';
import 'package:smart_class/widgets/apple_widgets.dart';
import 'package:smart_class/widgets/paddi_mascot.dart';

class StudentsScreen extends StatefulWidget {
  const StudentsScreen({super.key});

  @override
  State<StudentsScreen> createState() => _StudentsScreenState();
}

class _StudentsScreenState extends State<StudentsScreen> {
  final _search = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ctrl = context.watch<ClassController>();
    final list = ctrl.searchStudents(_query);

    return Scaffold(
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            LargeTitle(
              '学生',
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    onPressed: () => _showRosterActions(context),
                    icon: Icon(AppIcons.moreVert, color: AppTheme.blue),
                    tooltip: '导入导出',
                  ),
                  IconButton(
                    onPressed: () => _editStudent(context),
                    icon: Icon(AppIcons.plus, color: AppTheme.blue),
                    tooltip: '添加学生',
                  ),
                ],
              ),
            ),
            SearchField(
              controller: _search,
              hint: '搜索姓名、学号、小组',
              onChanged: (v) => setState(() => _query = v),
            ),
            Expanded(
              child: list.isEmpty
                  ? Center(
                      child: PaddiEmptyHint(
                        message: ctrl.students.isEmpty
                            ? '点右上角添加学生'
                            : '没有匹配结果',
                        asset: MascotAssets.sleepy,
                      ),
                    )
                  : ListView(
                      padding: const EdgeInsets.only(bottom: 24),
                      children: [
                        GroupedSection(
                          header: '${list.length} 人',
                          children: [
                            for (final s in list)
                              Dismissible(
                                key: ValueKey(s.id),
                                direction: DismissDirection.endToStart,
                                background: Container(
                                  alignment: Alignment.centerRight,
                                  padding: const EdgeInsets.only(right: 20),
                                  color: AppTheme.destructive,
                                  child: const Icon(AppIcons.trash,
                                      color: Colors.white),
                                ),
                                confirmDismiss: (_) => _confirmDelete(s),
                                onDismissed: (_) =>
                                    ctrl.removeStudent(s.id),
                                child: GroupedTile(
                                  title: s.name,
                                  subtitle: _subtitle(s),
                                  leading: StudentAvatar(name: s.name),
                                  trailing: Text(
                                    '${s.points}',
                                    style: TextStyle(
                                      fontSize: 17,
                                      color: AppTheme.tertiaryLabel,
                                    ),
                                  ),
                                  onTap: () => Navigator.of(context).push(
                                    MaterialPageRoute(
                                      builder: (_) =>
                                          StudentDetailScreen(studentId: s.id),
                                    ),
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }

  String _subtitle(Student s) {
    final parts = <String>[];
    if (s.role.isNotEmpty) parts.add(s.role);
    if (s.studentNo.isNotEmpty) parts.add(s.studentNo);
    if (s.groupName.isNotEmpty) parts.add(s.groupName);
    if (s.gender == '男' || s.gender == '女') parts.add(s.gender);
    if (s.birthday.isNotEmpty) parts.add('生日 ${s.birthday}');
    return parts.isEmpty ? '查看详情' : parts.join(' · ');
  }

  Future<bool> _confirmDelete(Student s) async {
    final ok = await showCupertinoDialog<bool>(
      context: context,
      builder: (ctx) => CupertinoAlertDialog(
        title: Text('删除 ${s.name}？'),
        content: const Text('相关记录将一并删除。'),
        actions: [
          CupertinoDialogAction(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('取消'),
          ),
          CupertinoDialogAction(
            isDestructiveAction: true,
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('删除'),
          ),
        ],
      ),
    );
    return ok ?? false;
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
                leading: Icon(AppIcons.upload, color: AppTheme.blue),
                title: const Text('通过表格导入'),
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
              // 弱化区：下载模板
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
                  icon: const Icon(Icons.download_outlined,
                      size: 15, color: Colors.grey),
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
      final path = await ctrl.exportStudentTemplateFile();
      if (!context.mounted) return;
      await showModalBottomSheet<void>(
        context: context,
        showDragHandle: true,
        builder: (ctx) => SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(8, 0, 8, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const ListTile(
                  title: Text('模板已保存到本机'),
                  subtitle: Text('可直接用表格软件打开填写'),
                ),
                ListTile(
                  leading: Icon(AppIcons.openFile, color: AppTheme.blue),
                  title: const Text('用表格软件打开'),
                  onTap: () async {
                    Navigator.pop(ctx);
                    await OpenFilex.open(path);
                  },
                ),
                ListTile(
                  leading: Icon(AppIcons.copy, color: AppTheme.blue),
                  title: const Text('复制文件路径'),
                  onTap: () async {
                    await Clipboard.setData(ClipboardData(text: path));
                    if (!ctx.mounted) return;
                    Navigator.pop(ctx);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('路径已复制')),
                    );
                  },
                ),
              ],
            ),
          ),
        ),
      );
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('生成失败：$e')),
      );
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

      final parts = <String>[
        if (result.added > 0) '新增 ${result.added} 人',
        if (result.updated > 0) '更新 ${result.updated} 人',
      ];
      final msg = parts.isEmpty
          ? (result.warnings.isNotEmpty
              ? result.warnings.join('\n')
              : '没有导入任何学生')
          : parts.join('，');
      final detail = result.warnings.isEmpty
          ? msg
          : '$msg\n${result.warnings.join('\n')}';

      await showCupertinoDialog<void>(
        context: context,
        builder: (ctx) => CupertinoAlertDialog(
          title: Text(result.total > 0 ? '导入完成' : '未能导入'),
          content: Text(detail),
          actions: [
            CupertinoDialogAction(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('好'),
            ),
          ],
        ),
      );
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('导入失败：$e')),
      );
    }
  }

  Future<void> _batchAdd(BuildContext context) {
    return Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const _BatchAddScreen()),
    );
  }

  Future<void> _editStudent(BuildContext context, {Student? student}) {
    return StudentEditScreen.push(context, student: student);
  }
}

class _BatchAddScreen extends StatefulWidget {
  const _BatchAddScreen();

  @override
  State<_BatchAddScreen> createState() => _BatchAddScreenState();
}

class _BatchAddScreenState extends State<_BatchAddScreen> {
  final _text = TextEditingController();

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final names = _text.text.split(RegExp(r'[\n,，、]'));
    await context.read<ClassController>().batchAddStudents(names);
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: PageAppBar(
        title: const Text('批量添加'),
        actions: [TextButton(onPressed: _save, child: const Text('添加'))],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
        children: [
          Text(
            '每行一个姓名，粘贴花名册即可',
            style: TextStyle(color: AppTheme.tertiaryLabel, fontSize: 13),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _text,
            minLines: 6,
            maxLines: 10,
            decoration: const InputDecoration(hintText: '张三\n李四\n王五'),
            autofocus: true,
          ),
          const SizedBox(height: 24),
          FilledButton(onPressed: _save, child: const Text('添加')),
        ],
      ),
    );
  }
}
