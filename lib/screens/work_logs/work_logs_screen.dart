import 'dart:async';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:path/path.dart' as p;
import 'package:permission_handler/permission_handler.dart';
import 'package:provider/provider.dart';
import 'package:smart_class/models/models.dart';
import 'package:smart_class/providers/ai_settings_controller.dart';
import 'package:smart_class/providers/class_controller.dart';
import 'package:smart_class/screens/more/ai_settings_screen.dart';
import 'package:smart_class/screens/work_logs/work_log_media_preview.dart';
import 'package:smart_class/services/deepseek_ai_service.dart';
import 'package:smart_class/services/file_export.dart';
import 'package:smart_class/services/file_share.dart';
import 'package:smart_class/services/share_inbox.dart';
import 'package:smart_class/theme/app_icons.dart';
import 'package:smart_class/theme/app_theme.dart';
import 'package:smart_class/widgets/apple_widgets.dart';
import 'package:smart_class/widgets/excel_import_sheet.dart';
import 'package:uuid/uuid.dart';

/// 工作留痕：安全教育 / 主题班会 / 学生谈话 / 心理关注 / 家长沟通 / 家访
class WorkLogsScreen extends StatefulWidget {
  const WorkLogsScreen({super.key, this.initialCategory});
  final WorkLogCategory? initialCategory;

  @override
  State<WorkLogsScreen> createState() => _WorkLogsScreenState();
}

class _WorkLogsScreenState extends State<WorkLogsScreen> {
  WorkLogCategory? _filter;

  static const _tagColors = <WorkLogCategory, Color>{
    WorkLogCategory.safetyEdu: Color(0xFFFF3B30),
    WorkLogCategory.classMeeting: Color(0xFF007AFF),
    WorkLogCategory.studentTalk: Color(0xFFFF9500),
    WorkLogCategory.mentalCare: Color(0xFFAF52DE),
    WorkLogCategory.parentComm: Color(0xFF34C759),
    WorkLogCategory.homeVisit: Color(0xFF5856D6),
  };

  @override
  void initState() {
    super.initState();
    _filter = widget.initialCategory;
  }

  @override
  Widget build(BuildContext context) {
    final ctrl = context.watch<ClassController>();
    final list = ctrl.workLogsOf(_filter);
    final canPop = Navigator.canPop(context);

    return Scaffold(
      backgroundColor: AppTheme.bg,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 8, 0),
              child: Row(
                children: [
                  if (canPop)
                    IconButton(
                      icon: const Icon(AppIcons.chevronLeft),
                      onPressed: () => Navigator.maybePop(context),
                    ),
                  const Expanded(
                    child: Text(
                      '工作留痕',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                        letterSpacing: -0.3,
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: '导入',
                    onPressed: () => showExcelImportActions(
                      context: context,
                      title: '工作留痕',
                      downloadTemplate: () => context
                          .read<ClassController>()
                          .exportWorkLogTemplateFile(),
                      importBytes: (bytes, _) => context
                          .read<ClassController>()
                          .importWorkLogFromBytes(bytes),
                    ),
                    icon: Icon(AppIcons.moreVert, color: AppTheme.secondaryLabel),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),
            SizedBox(
              height: 36,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                children: [
                  _FilterPill(
                    label: '全部',
                    selected: _filter == null,
                    onTap: () => setState(() => _filter = null),
                  ),
                  for (final c in WorkLogCategory.values)
                    Padding(
                      padding: const EdgeInsets.only(left: 8),
                      child: _FilterPill(
                        label: c.label,
                        selected: _filter == c,
                        onTap: () => setState(() => _filter = c),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: list.isEmpty
                  ? Center(
                      child: Text(
                        _filter == null
                            ? '还没有工作留痕'
                            : '暂无「${_filter!.label}」记录',
                        style: TextStyle(color: AppTheme.tertiaryLabel),
                      ),
                    )
                  : ListView(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 100),
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
                                          indent: 16,
                                          endIndent: 16,
                                          color: AppTheme.separator,
                                        ),
                                      AppleDeleteSlidable(
                                        itemKey: ValueKey(list[i].id),
                                        confirmTitle: '删除「${list[i].title}」？',
                                        onDelete: () =>
                                            ctrl.deleteWorkLog(list[i].id),
                                        child: _LogTile(
                                          log: list[i],
                                          tagColor:
                                              _tagColors[list[i].category] ??
                                                  AppTheme.blue,
                                          subtitle: _subtitle(ctrl, list[i]),
                                          attachments: ctrl.attachmentsOfWorkLog(
                                            list[i].id,
                                          ),
                                          onTap: () => _edit(
                                            context,
                                            existing: list[i],
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
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      floatingActionButton: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Row(
          children: [
            Expanded(
              child: Material(
                elevation: 2,
                borderRadius: BorderRadius.circular(24),
                color: AppTheme.surface,
                child: InkWell(
                  borderRadius: BorderRadius.circular(24),
                  onTap: () => _export(context, ctrl),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(AppIcons.upload, size: 18, color: AppTheme.blue),
                        const SizedBox(width: 6),
                        Text(
                          '导出',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: AppTheme.blue,
                            fontWeight: FontWeight.w600,
                            fontSize: 15,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              flex: 2,
              child: Material(
                elevation: 2,
                borderRadius: BorderRadius.circular(24),
                color: AppTheme.blue,
                child: InkWell(
                  borderRadius: BorderRadius.circular(24),
                  onTap: () => _edit(context, category: _filter),
                  child: const Padding(
                    padding: EdgeInsets.symmetric(vertical: 14),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(AppIcons.plus, color: Colors.white, size: 20),
                        SizedBox(width: 4),
                        Text(
                          '记一笔',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                            fontSize: 15,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _subtitle(ClassController ctrl, WorkLog w) {
    final parts = <String>[];
    if (w.content.trim().isNotEmpty) {
      final c = w.content.trim().replaceAll('\n', ' ');
      parts.add(c.length > 28 ? '${c.substring(0, 28)}…' : c);
    } else if (w.studentIdList.isNotEmpty) {
      parts.add(_studentNames(ctrl, w.studentIdList));
    } else {
      parts.add('有记录');
    }
    return parts.join(' · ');
  }

  String _studentNames(ClassController ctrl, List<String> ids) {
    final names = [
      for (final id in ids) ctrl.studentById(id)?.name ?? '',
    ].where((e) => e.isNotEmpty).toList();
    if (names.isEmpty) return '${ids.length} 人';
    if (names.length <= 2) return names.join('、');
    return '${names.take(2).join('、')} 等${names.length}人';
  }

  Future<void> _export(BuildContext context, ClassController ctrl) async {
    if (ctrl.workLogs.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('暂无记录可导出')),
      );
      return;
    }

    final mode = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(16, 4, 16, 8),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  '导出工作留痕',
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
                ),
              ),
            ),
            ListTile(
              leading: Icon(AppIcons.fileSheet, color: AppTheme.blue),
              title: const Text('仅导出 Excel 表格'),
              subtitle: const Text('包含类别、标题、内容、日期'),
              onTap: () => Navigator.pop(ctx, 'excel'),
            ),
            ListTile(
              leading: Icon(AppIcons.download, color: AppTheme.blue),
              title: const Text('导出 Excel 与附件'),
              subtitle: const Text('打包为 ZIP，附件按记录分文件夹存放'),
              onTap: () => Navigator.pop(ctx, 'zip'),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
    if (mode == null || !context.mounted) return;

    try {
      if (mode == 'excel') {
        final path = await ctrl.exportWorkLogsExcelFile();
        await FileShare.shareXlsx(
          filePath: path,
          subject: '工作留痕',
          text: '班级工作留痕台账',
        );
        if (!context.mounted) return;
        FileExport.showSavedSnackBar(context, path);
      } else {
        final path = await ctrl.exportWorkLogsReportFile();
        await FileShare.shareZip(
          filePath: path,
          subject: '工作留痕',
          text: '班级工作留痕台账及附件',
        );
        if (!context.mounted) return;
        FileExport.showSavedSnackBar(context, path);
      }
    } catch (e) {
      if (!context.mounted) return;
      FileExport.showErrorSnackBar(context, e);
    }
  }

  void _edit(
    BuildContext context, {
    WorkLog? existing,
    WorkLogCategory? category,
  }) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => _WorkLogEditScreen(
          existing: existing,
          initialCategory: category,
        ),
      ),
    );
  }
}

class _FilterPill extends StatelessWidget {
  const _FilterPill({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? AppTheme.label : AppTheme.surface,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: selected ? AppTheme.bg : AppTheme.secondaryLabel,
            ),
          ),
        ),
      ),
    );
  }
}

class _LogTile extends StatelessWidget {
  const _LogTile({
    required this.log,
    required this.tagColor,
    required this.subtitle,
    required this.attachments,
    required this.onTap,
  });

  final WorkLog log;
  final Color tagColor;
  final String subtitle;
  final List<WorkLogAttachment> attachments;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final md = log.date.length >= 10
        ? log.date.substring(5, 10).replaceAll('-', '-')
        : log.date;
    final photos =
        attachments.where((a) => a.kind == WorkLogMediaKind.photo).length;
    final audios =
        attachments.where((a) => a.kind == WorkLogMediaKind.audio).length;
    final videos =
        attachments.where((a) => a.kind == WorkLogMediaKind.video).length;
    final files =
        attachments.where((a) => a.kind == WorkLogMediaKind.file).length;

    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 12, 12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: tagColor.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          log.category.label,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: tagColor,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        md,
                        style: TextStyle(
                          fontSize: 12,
                          color: AppTheme.tertiaryLabel,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    log.title,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 13,
                      color: AppTheme.secondaryLabel,
                    ),
                  ),
                  if (attachments.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 10,
                      runSpacing: 4,
                      children: [
                        if (photos > 0)
                          _MediaBadge(
                            icon: AppIcons.photo,
                            label: '$photos',
                          ),
                        if (audios > 0)
                          _MediaBadge(
                            icon: AppIcons.mic,
                            label: '$audios',
                          ),
                        if (videos > 0)
                          _MediaBadge(
                            icon: AppIcons.video,
                            label: '$videos',
                          ),
                        if (files > 0)
                          _MediaBadge(
                            icon: AppIcons.file,
                            label: '$files',
                          ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
            Icon(AppIcons.chevronRight, size: 18, color: AppTheme.quaternaryLabel),
          ],
        ),
      ),
    );
  }
}

class _MediaBadge extends StatelessWidget {
  const _MediaBadge({required this.icon, required this.label});
  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: AppTheme.tertiaryLabel),
        const SizedBox(width: 3),
        Text(
          label,
          style: TextStyle(fontSize: 12, color: AppTheme.tertiaryLabel),
        ),
      ],
    );
  }
}

class _WorkLogEditScreen extends StatefulWidget {
  const _WorkLogEditScreen({this.existing, this.initialCategory});
  final WorkLog? existing;
  final WorkLogCategory? initialCategory;

  @override
  State<_WorkLogEditScreen> createState() => _WorkLogEditScreenState();
}

class _PendingMedia {
  const _PendingMedia({
    required this.kind,
    required this.path,
    required this.name,
    required this.sizeBytes,
  });
  final WorkLogMediaKind kind;
  final String path;
  final String name;
  final int sizeBytes;
}

class _WorkLogEditScreenState extends State<_WorkLogEditScreen> {
  late final TextEditingController _titleCtrl;
  late final TextEditingController _contentCtrl;
  late final String _logId;
  late WorkLogCategory _cat;
  late DateTime _date;
  late Set<String> _selectedStudents;
  final List<_PendingMedia> _pending = [];
  bool _busy = false;
  bool _aiBusy = false;
  bool _awaitingWeChatShare = false;
  WorkLogMediaKind _awaitingWeChatKind = WorkLogMediaKind.file;
  StreamSubscription<SharedFileItem>? _shareSub;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    _logId = e?.id ?? const Uuid().v4();
    _titleCtrl = TextEditingController(text: e?.title ?? '');
    _contentCtrl = TextEditingController(text: e?.content ?? '');
    _cat = e?.category ?? widget.initialCategory ?? WorkLogCategory.classMeeting;
    _date =
        e != null ? (DateTime.tryParse(e.date) ?? DateTime.now()) : DateTime.now();
    _selectedStudents = {...?e?.studentIdList};
    unawaited(ShareInbox.ensureStarted());
    _shareSub = ShareInbox.subscribe(_onSharedFile);
  }

  @override
  void dispose() {
    _shareSub?.cancel();
    _titleCtrl.dispose();
    _contentCtrl.dispose();
    super.dispose();
  }

  void _onSharedFile(SharedFileItem item) {
    if (!mounted) return;
    final kind = _awaitingWeChatKind;
    if (_awaitingWeChatShare) {
      setState(() => _awaitingWeChatShare = false);
    }
    unawaited(
      _addMediaPath(
        path: item.path,
        name: item.name,
        kind: kind,
      ),
    );
  }

  bool _needsStudent(WorkLogCategory c) =>
      c == WorkLogCategory.studentTalk ||
      c == WorkLogCategory.mentalCare ||
      c == WorkLogCategory.parentComm ||
      c == WorkLogCategory.homeVisit;

  Future<int> _resolveFileSize(String path, int? reported) async {
    if (reported != null && reported > 0) return reported;
    final file = File(path);
    if (await file.exists()) return file.length();
    return 0;
  }

  Future<void> _save() async {
    if (_titleCtrl.text.trim().isEmpty) return;
    final ctrl = context.read<ClassController>();
    await ctrl.saveWorkLog(
      id: _logId,
      category: _cat,
      title: _titleCtrl.text,
      content: _contentCtrl.text,
      date: DateFormat('yyyy-MM-dd').format(_date),
      studentIds: _selectedStudents.toList(),
    );
    for (final item in _pending) {
      await ctrl.attachWorkLogMedia(
        workLogId: _logId,
        kind: item.kind,
        sourcePath: item.path,
        originalName: item.name,
      );
    }
    if (mounted) Navigator.pop(context);
  }

  Future<void> _runAi(Future<String> Function(DeepSeekAiService ai) action) async {
    final aiCtrl = context.read<AiSettingsController>();
    if (!aiCtrl.hasApiKey) {
      final go = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('尚未配置 AI'),
          content: const Text('请先在「我的 → AI 助手」填写 DeepSeek API Key。'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('取消'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('去配置'),
            ),
          ],
        ),
      );
      if (go == true && mounted) {
        await Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const AiSettingsScreen()),
        );
      }
      return;
    }

    setState(() => _aiBusy = true);
    try {
      final text = await action(aiCtrl.createService());
      if (!mounted) return;
      setState(() => _contentCtrl.text = text);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('AI 已写入正文，请核对后保存')),
      );
    } on DeepSeekAiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('AI 失败：$e')),
      );
    } finally {
      if (mounted) setState(() => _aiBusy = false);
    }
  }

  Future<void> _aiPolish() async {
    if (_contentCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('请先写一些内容再润色')),
      );
      return;
    }
    await _runAi(
      (ai) => ai.polishWorkLog(
        categoryLabel: _cat.label,
        title: _titleCtrl.text,
        content: _contentCtrl.text,
      ),
    );
  }

  Future<void> _aiExpand() async {
    if (_titleCtrl.text.trim().isEmpty && _contentCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('请先填写标题或要点')),
      );
      return;
    }
    await _runAi(
      (ai) => ai.expandWorkLog(
        categoryLabel: _cat.label,
        title: _titleCtrl.text,
        content: _contentCtrl.text,
      ),
    );
  }

  Future<void> _addMediaPath({
    required String path,
    required String name,
    required WorkLogMediaKind kind,
  }) async {
    final inferred = WorkLogMediaKind.fromFileName(name) ?? kind;
    final sizeBytes = await _resolveFileSize(path, null);
    if (!mounted) return;
    final isExisting = widget.existing != null;
    final ctrl = context.read<ClassController>();

    if (isExisting) {
      await ctrl.attachWorkLogMedia(
        workLogId: _logId,
        kind: inferred,
        sourcePath: path,
        originalName: name,
      );
    } else {
      setState(() {
        _pending.add(
          _PendingMedia(
            kind: inferred,
            path: path,
            name: name,
            sizeBytes: sizeBytes,
          ),
        );
      });
    }

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('已添加 1 个${inferred.label}')),
    );
  }

  Future<void> _pickMedia(WorkLogMediaKind kind) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final FileType type;
      List<String>? allowedExtensions;
      switch (kind) {
        case WorkLogMediaKind.photo:
          type = FileType.image;
        case WorkLogMediaKind.audio:
          type = FileType.custom;
          allowedExtensions = const [
            'mp3',
            'm4a',
            'aac',
            'wav',
            'ogg',
            'amr',
            'flac',
          ];
        case WorkLogMediaKind.video:
          type = FileType.custom;
          allowedExtensions = const [
            'mp4',
            'mov',
            'm4v',
            'avi',
            'mkv',
            '3gp',
            'webm',
          ];
        case WorkLogMediaKind.file:
          type = FileType.any;
      }

      final result = await FilePicker.pickFiles(
        allowMultiple: true,
        type: type,
        allowedExtensions: allowedExtensions,
        withData: false,
      );
      if (result == null || result.files.isEmpty || !mounted) return;

      final isExisting = widget.existing != null;
      final ctrl = context.read<ClassController>();
      var ok = 0;
      for (final f in result.files) {
        final path = f.path;
        if (path == null || path.isEmpty) continue;
        final inferred = WorkLogMediaKind.fromFileName(f.name) ?? kind;
        final sizeBytes = await _resolveFileSize(path, f.size);
        if (isExisting) {
          await ctrl.attachWorkLogMedia(
            workLogId: _logId,
            kind: inferred,
            sourcePath: path,
            originalName: f.name,
          );
        } else {
          _pending.add(
            _PendingMedia(
              kind: inferred,
              path: path,
              name: f.name,
              sizeBytes: sizeBytes,
            ),
          );
        }
        ok++;
      }
      if (!mounted) return;
      setState(() {});
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(ok == 0 ? '未能读取所选文件' : '已添加 $ok 个${kind.label}'),
        ),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('选择文件失败：$e')),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _showMediaOptions(WorkLogMediaKind kind) async {
    final sheetTitle = switch (kind) {
      WorkLogMediaKind.photo => '添加照片',
      WorkLogMediaKind.audio => '添加录音',
      WorkLogMediaKind.video => '添加视频',
      WorkLogMediaKind.file => '添加文件',
    };
    final captureTitle = switch (kind) {
      WorkLogMediaKind.photo => '拍照',
      WorkLogMediaKind.audio => '现场录音',
      WorkLogMediaKind.video => '现场录像',
      WorkLogMediaKind.file => null,
    };
    final pickTitle = switch (kind) {
      WorkLogMediaKind.photo => '从相册选择',
      WorkLogMediaKind.audio => '从手机选择',
      WorkLogMediaKind.video => '从手机选择',
      WorkLogMediaKind.file => '从手机选择',
    };
    final pickSubtitle = switch (kind) {
      WorkLogMediaKind.photo => '从系统相册中选取',
      WorkLogMediaKind.audio => '浏览本机音频文件',
      WorkLogMediaKind.video => '浏览本机视频文件',
      WorkLogMediaKind.file => '浏览本机文档与其他文件',
    };
    final wechatSubtitle = switch (kind) {
      WorkLogMediaKind.photo => '在微信中打开后，选择用本应用打开',
      WorkLogMediaKind.audio => '在微信中打开语音或音频后导入',
      WorkLogMediaKind.video => '在微信中打开视频后导入',
      WorkLogMediaKind.file => '在微信中打开文件后导入',
    };
    final captureIcon = switch (kind) {
      WorkLogMediaKind.photo => AppIcons.camera,
      WorkLogMediaKind.audio => AppIcons.mic,
      WorkLogMediaKind.video => AppIcons.video,
      WorkLogMediaKind.file => AppIcons.file,
    };
    final showCapture = captureTitle != null;
    final showWeChat = kind != WorkLogMediaKind.photo;

    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  sheetTitle,
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
            if (showCapture)
              ListTile(
                leading: Icon(captureIcon, color: AppTheme.blue),
                title: Text(captureTitle),
                onTap: () async {
                  Navigator.pop(ctx);
                  switch (kind) {
                    case WorkLogMediaKind.photo:
                      await _capturePhoto();
                    case WorkLogMediaKind.audio:
                      await _recordVoice();
                    case WorkLogMediaKind.video:
                      await _captureVideo();
                    case WorkLogMediaKind.file:
                      break;
                  }
                },
              ),
            ListTile(
              leading: Icon(
                kind == WorkLogMediaKind.photo
                    ? AppIcons.photo
                    : AppIcons.folder,
                color: AppTheme.blue,
              ),
              title: Text(pickTitle),
              subtitle: Text(pickSubtitle),
              onTap: () {
                Navigator.pop(ctx);
                _pickMedia(kind);
              },
            ),
            if (showWeChat)
              ListTile(
                leading: Icon(AppIcons.message, color: AppTheme.blue),
                title: const Text('从微信导入'),
                subtitle: Text(wechatSubtitle),
                onTap: () {
                  Navigator.pop(ctx);
                  unawaited(_importFromWeChat(kind));
                },
              ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Future<void> _importFromWeChat(WorkLogMediaKind kind) async {
    await ShareInbox.ensureStarted();
    if (!mounted) return;

    final kindLabel = switch (kind) {
      WorkLogMediaKind.audio => '录音或音频',
      WorkLogMediaKind.video => '视频',
      WorkLogMediaKind.file => '文件',
      WorkLogMediaKind.photo => '图片',
    };

    final go = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('从微信导入'),
        content: Text(
          '请按以下步骤完成导入：\n\n'
          '1. 在微信中打开需要导入的$kindLabel\n'
          '2. 轻点右上角「···」，选择「用其他应用打开」或「分享」\n'
          '3. 在应用列表中选择「班主任助手」\n\n'
          '导入成功后，将自动添加至本条留痕。',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('前往微信'),
          ),
        ],
      ),
    );
    if (go != true || !mounted) return;

    setState(() {
      _awaitingWeChatShare = true;
      _awaitingWeChatKind = kind;
    });
    final opened = await ShareInbox.openWeChat();
    if (!mounted) return;
    if (!opened) {
      setState(() => _awaitingWeChatShare = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('未安装微信，请安装后重试')),
      );
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('请在微信中选择用「班主任助手」打开$kindLabel'),
        duration: const Duration(seconds: 4),
      ),
    );
  }

  Future<bool> _ensureCameraPermission({required bool forVideo}) async {
    var cam = await Permission.camera.status;
    if (!cam.isGranted) {
      cam = await Permission.camera.request();
    }
    if (!cam.isGranted) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('需要相机权限才能拍摄')),
        );
      }
      return false;
    }
    if (forVideo) {
      var mic = await Permission.microphone.status;
      if (!mic.isGranted) {
        mic = await Permission.microphone.request();
      }
      if (!mic.isGranted) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('录像需要麦克风权限')),
          );
        }
        return false;
      }
    }
    return true;
  }

  Future<void> _capturePhoto() async {
    if (_busy) return;
    if (!await _ensureCameraPermission(forVideo: false)) return;
    setState(() => _busy = true);
    try {
      final file = await ImagePicker().pickImage(
        source: ImageSource.camera,
        imageQuality: 88,
        maxWidth: 2560,
      );
      if (file == null || !mounted) return;
      await _addMediaPath(
        path: file.path,
        name: file.name.isEmpty
            ? 'photo_${DateTime.now().millisecondsSinceEpoch}.jpg'
            : file.name,
        kind: WorkLogMediaKind.photo,
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('拍照失败：$e')),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _captureVideo() async {
    if (_busy) return;
    if (!await _ensureCameraPermission(forVideo: true)) return;
    setState(() => _busy = true);
    try {
      final file = await ImagePicker().pickVideo(
        source: ImageSource.camera,
        maxDuration: const Duration(minutes: 10),
      );
      if (file == null || !mounted) return;
      await _addMediaPath(
        path: file.path,
        name: file.name.isEmpty
            ? 'video_${DateTime.now().millisecondsSinceEpoch}.mp4'
            : file.name,
        kind: WorkLogMediaKind.video,
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('录像失败：$e')),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _recordVoice() async {
    final path = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => const _VoiceRecordSheet(),
    );
    if (path == null || path.isEmpty || !mounted) return;
    await _addMediaPath(
      path: path,
      name: p.basename(path),
      kind: WorkLogMediaKind.audio,
    );
  }

  Future<void> _openAttachment(WorkLogAttachment item) async {
    try {
      final path =
          await context.read<ClassController>().workLogAttachmentPath(item);
      if (!mounted) return;
      await WorkLogMediaPreviewPage.open(
        context,
        path: path,
        kind: item.kind,
        title: item.fileName,
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('无法打开：$e')),
      );
    }
  }

  Future<void> _openPending(_PendingMedia item) async {
    try {
      await WorkLogMediaPreviewPage.open(
        context,
        path: item.path,
        kind: item.kind,
        title: item.name,
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('无法打开：$e')),
      );
    }
  }

  Future<void> _deleteAttachment(WorkLogAttachment item) async {
    final ok = await showCupertinoDialog<bool>(
      context: context,
      builder: (d) => CupertinoAlertDialog(
        title: Text('删除该${item.kind.label}？'),
        content: Text(item.fileName),
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
    if (ok == true && mounted) {
      await context.read<ClassController>().deleteWorkLogAttachment(item);
    }
  }

  String _formatSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  IconData _iconFor(WorkLogMediaKind kind) => switch (kind) {
        WorkLogMediaKind.photo => AppIcons.photo,
        WorkLogMediaKind.audio => AppIcons.mic,
        WorkLogMediaKind.video => AppIcons.video,
        WorkLogMediaKind.file => AppIcons.file,
      };

  @override
  Widget build(BuildContext context) {
    final ctrl = context.watch<ClassController>();
    final saved = ctrl.attachmentsOfWorkLog(_logId);
    final totalCount = saved.length + _pending.length;

    return Scaffold(
      appBar: PageAppBar(
        title: Text(widget.existing == null ? '记一笔' : '编辑留痕'),
        actions: [TextButton(onPressed: _save, child: const Text('保存'))],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
        children: [
          Text('类别', style: TextStyle(color: AppTheme.tertiaryLabel)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final c in WorkLogCategory.values)
                ChoiceChip(
                  label: Text(c.label),
                  selected: _cat == c,
                  showCheckmark: false,
                  onSelected: (_) => setState(() => _cat = c),
                ),
            ],
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _titleCtrl,
            decoration: InputDecoration(hintText: _cat.hint),
          ),
          const SizedBox(height: 8),
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('日期'),
            subtitle: Text(DateFormat('yyyy-MM-dd').format(_date)),
            trailing: const Icon(AppIcons.calendar),
            onTap: () async {
              final d = await showDatePicker(
                context: context,
                initialDate: _date,
                firstDate: DateTime(2020),
                lastDate: DateTime(2100),
              );
              if (d != null) setState(() => _date = d);
            },
          ),
          TextField(
            controller: _contentCtrl,
            minLines: 3,
            maxLines: 6,
            decoration: const InputDecoration(
              hintText: '过程、要点、结果与后续跟进',
              alignLabelWithHint: true,
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: (_busy || _aiBusy) ? null : _aiPolish,
                  icon: _aiBusy
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Icon(AppIcons.wand, size: 18, color: AppTheme.blue),
                  label: Text(_aiBusy ? '生成中…' : 'AI 润色'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: (_busy || _aiBusy) ? null : _aiExpand,
                  icon: Icon(AppIcons.sparkles, size: 18, color: AppTheme.blue),
                  label: const Text('AI 扩写'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Text('凭据附件', style: TextStyle(color: AppTheme.tertiaryLabel)),
          const SizedBox(height: 4),
          Text(
            '支持现场拍摄与录音，也可从手机或微信导入附件。',
            style: TextStyle(fontSize: 12, color: AppTheme.quaternaryLabel),
          ),
          if (_awaitingWeChatShare) ...[
            const SizedBox(height: 8),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: AppTheme.blue.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                children: [
                  Icon(AppIcons.message, size: 18, color: AppTheme.blue),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '正在等待从微信导入。请在微信中选择用「班主任助手」打开。',
                      style: TextStyle(
                        fontSize: 13,
                        color: AppTheme.label,
                      ),
                    ),
                  ),
                  TextButton(
                    onPressed: () =>
                        setState(() => _awaitingWeChatShare = false),
                    child: const Text('取消'),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _AttachButton(
                  icon: AppIcons.photo,
                  label: '照片',
                  onTap: _busy
                      ? null
                      : () => _showMediaOptions(WorkLogMediaKind.photo),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _AttachButton(
                  icon: AppIcons.mic,
                  label: '录音',
                  onTap: _busy
                      ? null
                      : () => _showMediaOptions(WorkLogMediaKind.audio),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _AttachButton(
                  icon: AppIcons.video,
                  label: '视频',
                  onTap: _busy
                      ? null
                      : () => _showMediaOptions(WorkLogMediaKind.video),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _AttachButton(
                  icon: AppIcons.file,
                  label: '文件',
                  onTap: _busy
                      ? null
                      : () => _showMediaOptions(WorkLogMediaKind.file),
                ),
              ),
            ],
          ),
          if (totalCount > 0) ...[
            const SizedBox(height: 12),
            Container(
              decoration: BoxDecoration(
                color: AppTheme.surface,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                children: [
                  for (var i = 0; i < saved.length; i++) ...[
                    if (i > 0)
                      Divider(
                        height: 1,
                        indent: 16,
                        endIndent: 16,
                        color: AppTheme.separator,
                      ),
                    ListTile(
                      leading: Icon(
                        _iconFor(saved[i].kind),
                        color: AppTheme.blue,
                      ),
                      title: Text(
                        saved[i].fileName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      subtitle: Text(
                        '${saved[i].kind.label} · ${_formatSize(saved[i].sizeBytes)}',
                      ),
                      trailing: IconButton(
                        icon: Icon(AppIcons.trash, color: AppTheme.tertiaryLabel),
                        onPressed: () => _deleteAttachment(saved[i]),
                      ),
                      onTap: () => _openAttachment(saved[i]),
                    ),
                  ],
                  for (var i = 0; i < _pending.length; i++) ...[
                    if (saved.isNotEmpty || i > 0)
                      Divider(
                        height: 1,
                        indent: 16,
                        endIndent: 16,
                        color: AppTheme.separator,
                      ),
                    ListTile(
                      leading: Icon(
                        _iconFor(_pending[i].kind),
                        color: AppTheme.blue,
                      ),
                      title: Text(
                        _pending[i].name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      subtitle: Text(
                        '${_pending[i].kind.label} · ${_formatSize(_pending[i].sizeBytes)} · 待保存',
                      ),
                      trailing: IconButton(
                        icon: Icon(AppIcons.trash, color: AppTheme.tertiaryLabel),
                        onPressed: () => setState(() => _pending.removeAt(i)),
                      ),
                      onTap: () => _openPending(_pending[i]),
                    ),
                  ],
                ],
              ),
            ),
          ],
          if (_needsStudent(_cat) && ctrl.students.isNotEmpty) ...[
            const SizedBox(height: 16),
            Text('关联学生（可选）',
                style: TextStyle(color: AppTheme.tertiaryLabel)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final s in ctrl.students)
                  FilterChip(
                    label: Text(s.name),
                    selected: _selectedStudents.contains(s.id),
                    showCheckmark: false,
                    onSelected: (v) => setState(() {
                      if (v) {
                        _selectedStudents.add(s.id);
                      } else {
                        _selectedStudents.remove(s.id);
                      }
                    }),
                  ),
              ],
            ),
          ],
          const SizedBox(height: 24),
          FilledButton(onPressed: _save, child: const Text('保存')),
        ],
      ),
    );
  }
}

class _AttachButton extends StatelessWidget {
  const _AttachButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppTheme.surface,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 14),
          child: Column(
            children: [
              Icon(icon, color: AppTheme.blue, size: 22),
              const SizedBox(height: 4),
              Text(
                label,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: onTap == null
                      ? AppTheme.quaternaryLabel
                      : AppTheme.secondaryLabel,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _VoiceRecordSheet extends StatefulWidget {
  const _VoiceRecordSheet();

  @override
  State<_VoiceRecordSheet> createState() => _VoiceRecordSheetState();
}

class _VoiceRecordSheetState extends State<_VoiceRecordSheet> {
  static const _channel = MethodChannel('smart_class/voice_record');
  bool _recording = false;
  bool _starting = false;
  int _seconds = 0;
  Timer? _timer;
  String? _error;
  String? _path;

  @override
  void dispose() {
    _timer?.cancel();
    if (_recording) {
      unawaited(_channel.invokeMethod<void>('cancel').catchError((_) {}));
    }
    super.dispose();
  }

  Future<void> _toggleRecording() async {
    if (_starting) return;
    if (_recording) {
      _starting = true;
      try {
        final path = await _channel.invokeMethod<String>('stop');
        _timer?.cancel();
        if (mounted) {
          setState(() => _recording = false);
          final out = (path != null && path.isNotEmpty) ? path : _path;
          if (out != null && out.isNotEmpty) {
            Navigator.pop(context, out);
          }
        }
      } on PlatformException catch (e) {
        if (mounted) setState(() => _error = '停止录音失败：${e.message}');
      } catch (e) {
        if (mounted) setState(() => _error = '停止录音失败：$e');
      } finally {
        _starting = false;
      }
      return;
    }

    _starting = true;
    try {
      var mic = await Permission.microphone.status;
      if (!mic.isGranted) {
        mic = await Permission.microphone.request();
      }
      if (!mic.isGranted) {
        if (mounted) {
          setState(() => _error = '需要麦克风权限才能录音（系统设置 → 应用权限）');
        }
        return;
      }

      final path = await _channel.invokeMethod<String>('start');
      if (path == null || path.isEmpty) {
        if (mounted) setState(() => _error = '录音启动失败');
        return;
      }
      _path = path;
      if (!mounted) return;
      setState(() {
        _recording = true;
        _seconds = 0;
        _error = null;
      });
      _timer = Timer.periodic(const Duration(seconds: 1), (_) {
        if (mounted) setState(() => _seconds++);
      });
    } on PlatformException catch (e) {
      if (mounted) setState(() => _error = '录音失败：${e.message ?? e.code}');
    } catch (e) {
      if (mounted) setState(() => _error = '录音失败：$e');
    } finally {
      _starting = false;
    }
  }

  String _formatDuration(int seconds) {
    final m = (seconds ~/ 60).toString().padLeft(2, '0');
    final s = (seconds % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 8, 24, 28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('录音', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 20),
            Icon(
              AppIcons.mic,
              size: 48,
              color: _recording ? AppTheme.destructive : AppTheme.blue,
            ),
            const SizedBox(height: 12),
            Text(
              _recording ? _formatDuration(_seconds) : '点按开始录音',
              style: TextStyle(
                fontSize: 16,
                color: AppTheme.secondaryLabel,
              ),
            ),
            if (_error != null) ...[
              const SizedBox(height: 8),
              Text(
                _error!,
                textAlign: TextAlign.center,
                style: TextStyle(color: AppTheme.destructive, fontSize: 13),
              ),
            ],
            const SizedBox(height: 20),
            FilledButton.icon(
              onPressed: _toggleRecording,
              icon: Icon(_recording ? AppIcons.close : AppIcons.mic),
              label: Text(_recording ? '完成' : '开始录音'),
            ),
          ],
        ),
      ),
    );
  }
}
