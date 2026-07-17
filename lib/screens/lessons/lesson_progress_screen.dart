import 'package:file_picker/file_picker.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:smart_class/theme/app_icons.dart';
import 'package:open_filex/open_filex.dart';
import 'package:provider/provider.dart';
import 'package:smart_class/models/models.dart';
import 'package:smart_class/providers/class_controller.dart';
import 'package:smart_class/theme/app_theme.dart';
import 'package:smart_class/widgets/apple_widgets.dart';
import 'package:smart_class/widgets/excel_import_sheet.dart';
import 'package:smart_class/screens/lessons/lesson_edit_screen.dart';

/// 授课进度 + PPT/课件本地存档
class LessonProgressScreen extends StatefulWidget {
  const LessonProgressScreen({super.key});

  @override
  State<LessonProgressScreen> createState() => _LessonProgressScreenState();
}

class _LessonProgressScreenState extends State<LessonProgressScreen> {
  LessonStatus? _filter;

  @override
  Widget build(BuildContext context) {
    final ctrl = context.watch<ClassController>();
    var list = [...ctrl.lessonUnits];
    if (_filter != null) {
      list = list.where((e) => e.status == _filter).toList();
    }

    return Scaffold(
      appBar: PageAppBar(
        title: const Text('授课进度'),
        actions: [
          IconButton(
            tooltip: '导入导出',
            onPressed: () => showExcelImportActions(
              context: context,
              title: '授课进度',
              downloadTemplate: () =>
                  context.read<ClassController>().exportLessonTemplateFile(),
              importBytes: (bytes, _) =>
                  context.read<ClassController>().importLessonFromBytes(bytes),
            ),
            icon: const Icon(AppIcons.moreVert),
          ),
          IconButton(
            tooltip: '添加课时',
            onPressed: () => _editUnit(context),
            icon: const Icon(Icons.add),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.only(bottom: 28),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
            child: Wrap(
              spacing: 8,
              children: [
                FilterChip(
                  label: const Text('全部'),
                  selected: _filter == null,
                  onSelected: (_) => setState(() => _filter = null),
                ),
                for (final s in LessonStatus.values)
                  FilterChip(
                    label: Text(s.label),
                    selected: _filter == s,
                    onSelected: (_) => setState(() => _filter = s),
                  ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
            child: Text(
              '可记录每课进度，并上传 PPT、Word、PDF 等课件到本机存档。',
              style: TextStyle(fontSize: 13, color: AppTheme.secondaryLabel),
            ),
          ),
          if (list.isEmpty)
            const Padding(
              padding: EdgeInsets.all(24),
              child: Text('暂无课时，点右上角添加。'),
            )
          else
            GroupedSection(
              children: [
                for (final u in list)
                  GroupedTile(
                    title: u.title,
                    subtitle: [
                      if (u.subject.isNotEmpty) u.subject,
                      if (u.chapter.isNotEmpty) u.chapter,
                      u.status.label,
                      if (ctrl.filesOfLesson(u.id).isNotEmpty)
                        '${ctrl.filesOfLesson(u.id).length} 个课件',
                    ].join(' · '),
                    trailing: Icon(Icons.chevron_right, color: AppTheme.tertiaryLabel),
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => LessonUnitDetailScreen(unitId: u.id),
                      ),
                    ),
                    onLongPress: () => _editUnit(context, existing: u),
                  ),
              ],
            ),
        ],
      ),
    );
  }

  void _editUnit(BuildContext context, {LessonUnit? existing}) {
    LessonEditScreen.push(context, existing: existing);
  }
}

class LessonUnitDetailScreen extends StatelessWidget {
  const LessonUnitDetailScreen({super.key, required this.unitId});

  final String unitId;

  @override
  Widget build(BuildContext context) {
    final ctrl = context.watch<ClassController>();
    LessonUnit? unit;
    for (final u in ctrl.lessonUnits) {
      if (u.id == unitId) {
        unit = u;
        break;
      }
    }
    if (unit == null) {
      return Scaffold(
        appBar: PageAppBar(title: const Text('课时')),
        body: const Center(child: Text('课时不存在或已删除')),
      );
    }
    final files = ctrl.filesOfLesson(unitId);

    return Scaffold(
      appBar: PageAppBar(
        title: Text(unit.title),
        actions: [
          IconButton(
            tooltip: '上传课件',
            onPressed: () => _pickFiles(context, unitId),
            icon: const Icon(Icons.upload_file_outlined),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.only(bottom: 28),
        children: [
          GroupedSection(
            header: '进度',
            children: [
              GroupedTile(title: '状态', trailing: Text(unit.status.label)),
              if (unit.subject.isNotEmpty)
                GroupedTile(title: '科目', trailing: Text(unit.subject)),
              if (unit.chapter.isNotEmpty)
                GroupedTile(title: '章节', trailing: Text(unit.chapter)),
              if (unit.plannedDate.isNotEmpty)
                GroupedTile(title: '计划日期', trailing: Text(unit.plannedDate)),
              if (unit.taughtDate.isNotEmpty)
                GroupedTile(title: '授课日', trailing: Text(unit.taughtDate)),
              if (unit.progressNote.isNotEmpty)
                GroupedTile(
                  title: '备注',
                  subtitle: unit.progressNote,
                ),
            ],
          ),
          const SizedBox(height: 16),
          GroupedSection(
            header: '课件存档',
            footer: files.isEmpty
                ? '支持 PPT / Word / PDF / 图片等，文件保存在本机'
                : '点文件可用系统应用打开；长按删除',
            children: [
              GroupedTile(
                title: '上传文件',
                subtitle: '从相册或文件管理器选择',
                leading: Icon(Icons.add_circle_outline, color: AppTheme.blue),
                onTap: () => _pickFiles(context, unitId),
              ),
              for (final f in files)
                GroupedTile(
                  title: f.fileName,
                  subtitle:
                      '${f.isPpt ? 'PPT · ' : ''}${_formatSize(f.sizeBytes)}',
                  leading: Icon(
                    f.isPpt ? Icons.slideshow_outlined : Icons.insert_drive_file_outlined,
                    color: AppTheme.blue,
                  ),
                  onTap: () => _openFile(context, f),
                  onLongPress: () => _deleteFile(context, f),
                ),
            ],
          ),
        ],
      ),
    );
  }

  static String _formatSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  static Future<void> _pickFiles(BuildContext context, String unitId) async {
    final ctrl = context.read<ClassController>();
    final result = await FilePicker.pickFiles(
      allowMultiple: true,
      type: FileType.any,
      withData: false,
    );
    if (result == null || result.files.isEmpty) return;
    var ok = 0;
    for (final f in result.files) {
      final path = f.path;
      if (path == null || path.isEmpty) continue;
      await ctrl.attachLessonFile(
        unitId: unitId,
        sourcePath: path,
        originalName: f.name,
      );
      ok++;
    }
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(ok == 0 ? '未能读取所选文件' : '已存档 $ok 个文件')),
      );
    }
  }

  static Future<void> _openFile(BuildContext context, LessonFile file) async {
    final ctrl = context.read<ClassController>();
    final path = await ctrl.lessonFilePath(file);
    final res = await OpenFilex.open(path);
    if (res.type != ResultType.done && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(res.message.isEmpty ? '无法打开文件，请安装对应应用' : res.message)),
      );
    }
  }

  static Future<void> _deleteFile(BuildContext context, LessonFile file) async {
    final ok = await showCupertinoDialog<bool>(
      context: context,
      builder: (d) => CupertinoAlertDialog(
        title: const Text('删除该课件？'),
        content: Text(file.fileName),
        actions: [
          CupertinoDialogAction(
            onPressed: () => Navigator.pop(d, false),
            child: const Text('取消'),
          ),
          CupertinoDialogAction(
            isDestructiveAction: true,
            onPressed: () => Navigator.pop(d, true),
            child: const Text('删除'),
          ),
        ],
      ),
    );
    if (ok == true && context.mounted) {
      await context.read<ClassController>().deleteLessonFile(file);
    }
  }
}
