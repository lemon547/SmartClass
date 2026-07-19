import 'package:file_picker/file_picker.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:smart_class/models/models.dart';
import 'package:smart_class/providers/class_controller.dart';
import 'package:smart_class/services/media_open.dart';
import 'package:smart_class/theme/app_icons.dart';
import 'package:smart_class/theme/app_theme.dart';
import 'package:smart_class/widgets/apple_widgets.dart';
import 'package:uuid/uuid.dart';

enum _LeaveFilter { active, overdue, returned, all }

class LeaveScreen extends StatefulWidget {
  const LeaveScreen({super.key});

  @override
  State<LeaveScreen> createState() => _LeaveScreenState();
}

class _LeaveScreenState extends State<LeaveScreen> {
  _LeaveFilter _filter = _LeaveFilter.active;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<ClassController>().refreshDailyOps();
    });
  }

  List<LeaveRecord> _filtered(List<LeaveRecord> all) {
    return switch (_filter) {
      _LeaveFilter.active => all.where((e) => e.isActive && !e.isOverdue).toList(),
      _LeaveFilter.overdue => all.where((e) => e.isOverdue).toList(),
      _LeaveFilter.returned =>
        all.where((e) => e.status == LeaveStatus.returned).toList(),
      _LeaveFilter.all => all,
    };
  }

  Future<void> _shareList(ClassController ctrl, List<LeaveRecord> list) async {
    final fmt = DateFormat('M/d HH:mm');
    final buf = StringBuffer('请假名单\n');
    for (final e in list) {
      final name = ctrl.studentById(e.studentId)?.name ?? e.studentId;
      buf.writeln(
        '$name · ${fmt.format(e.startAt)}–${fmt.format(e.endAt)}'
        '${e.isOverdue ? '（逾期未销假）' : ''}'
        '${e.reason.isNotEmpty ? ' · ${e.reason}' : ''}',
      );
    }
    await Share.share(buf.toString());
  }

  @override
  Widget build(BuildContext context) {
    final ctrl = context.watch<ClassController>();
    final list = _filtered(ctrl.leaveRecords);

    return Scaffold(
      backgroundColor: AppTheme.bg,
      appBar: PageAppBar(
        title: const Text('请假管理'),
        actions: [
          IconButton(
            tooltip: '分享名单',
            onPressed: list.isEmpty ? null : () => _shareList(ctrl, list),
            icon: const Icon(AppIcons.share),
          ),
          IconButton(
            tooltip: '登记请假',
            onPressed: () => _openEditor(context),
            icon: const Icon(AppIcons.plus),
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  for (final f in _LeaveFilter.values)
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: ChoiceChip(
                        label: Text(switch (f) {
                          _LeaveFilter.active => '请假中',
                          _LeaveFilter.overdue =>
                            '逾期 ${ctrl.overdueLeaveCount}',
                          _LeaveFilter.returned => '已销假',
                          _LeaveFilter.all => '全部',
                        }),
                        selected: _filter == f,
                        onSelected: (_) => setState(() => _filter = f),
                      ),
                    ),
                ],
              ),
            ),
          ),
          if (ctrl.overdueLeaveCount > 0 && _filter != _LeaveFilter.overdue)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
              child: Material(
                color: const Color(0xFFFFE5E5),
                borderRadius: BorderRadius.circular(10),
                child: InkWell(
                  onTap: () => setState(() => _filter = _LeaveFilter.overdue),
                  borderRadius: BorderRadius.circular(10),
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Row(
                      children: [
                        Icon(AppIcons.alert, color: Colors.red, size: 18),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            '有 ${ctrl.overdueLeaveCount} 人逾期未销假',
                            style: const TextStyle(
                              color: Colors.red,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        const Icon(AppIcons.chevronRight,
                            size: 16, color: Colors.red),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          Expanded(
            child: list.isEmpty
                ? Center(
                    child: Text(
                      '暂无记录',
                      style: TextStyle(color: AppTheme.tertiaryLabel),
                    ),
                  )
                : ListView.separated(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
                    itemCount: list.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (context, i) {
                      final e = list[i];
                      final name =
                          ctrl.studentById(e.studentId)?.name ?? '未知学生';
                      final fmt = DateFormat('M/d HH:mm');
                      return Material(
                        color: AppTheme.surface,
                        borderRadius: BorderRadius.circular(12),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(12),
                          onTap: () => _openEditor(context, existing: e),
                          child: Padding(
                            padding: const EdgeInsets.all(14),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        name,
                                        style: const TextStyle(
                                          fontSize: 17,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 8,
                                        vertical: 2,
                                      ),
                                      decoration: BoxDecoration(
                                        color: e.isOverdue
                                            ? const Color(0xFFFFE5E5)
                                            : e.isActive
                                                ? const Color(0xFFE5F1FF)
                                                : AppTheme.fill,
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Text(
                                        e.isOverdue ? '逾期未销假' : e.status.label,
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: e.isOverdue
                                              ? Colors.red
                                              : AppTheme.secondaryLabel,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  '${fmt.format(e.startAt)} – ${fmt.format(e.endAt)}',
                                  style: TextStyle(
                                    color: AppTheme.secondaryLabel,
                                    fontSize: 13,
                                  ),
                                ),
                                if (e.reason.isNotEmpty) ...[
                                  const SizedBox(height: 4),
                                  Text(e.reason,
                                      style: TextStyle(
                                          color: AppTheme.tertiaryLabel)),
                                ],
                                const SizedBox(height: 10),
                                Row(
                                  children: [
                                    if (e.isActive)
                                      TextButton(
                                        onPressed: () async {
                                          await ctrl.returnLeave(e.id);
                                          if (context.mounted) {
                                            ScaffoldMessenger.of(context)
                                                .showSnackBar(
                                              const SnackBar(
                                                  content: Text('已销假')),
                                            );
                                          }
                                        },
                                        child: const Text('销假'),
                                      ),
                                    if (e.hasProof)
                                      TextButton(
                                        onPressed: () async {
                                          final path =
                                              await ctrl.leaveProofPath(e);
                                          await MediaOpen.open(path);
                                        },
                                        child: const Text('凭证'),
                                      ),
                                    const Spacer(),
                                    IconButton(
                                      tooltip: '删除',
                                      onPressed: () async {
                                        final ok =
                                            await showCupertinoDialog<bool>(
                                          context: context,
                                          builder: (ctx) => CupertinoAlertDialog(
                                            title: const Text('删除请假？'),
                                            actions: [
                                              CupertinoDialogAction(
                                                onPressed: () =>
                                                    Navigator.pop(ctx, false),
                                                child: const Text('取消'),
                                              ),
                                              CupertinoDialogAction(
                                                isDestructiveAction: true,
                                                onPressed: () =>
                                                    Navigator.pop(ctx, true),
                                                child: const Text('删除'),
                                              ),
                                            ],
                                          ),
                                        );
                                        if (ok == true) {
                                          await ctrl.deleteLeave(e.id);
                                        }
                                      },
                                      icon: Icon(AppIcons.trash,
                                          size: 18,
                                          color: AppTheme.tertiaryLabel),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Future<void> _openEditor(BuildContext context, {LeaveRecord? existing}) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => LeaveEditScreen(existing: existing),
      ),
    );
  }
}

class LeaveEditScreen extends StatefulWidget {
  const LeaveEditScreen({super.key, this.existing});

  final LeaveRecord? existing;

  @override
  State<LeaveEditScreen> createState() => _LeaveEditScreenState();
}

class _LeaveEditScreenState extends State<LeaveEditScreen> {
  late String? _studentId;
  late DateTime _start;
  late DateTime _end;
  final _reason = TextEditingController();
  final _pickup = TextEditingController();
  String _proofStored = '';
  String _proofOriginal = '';
  late final String _leaveId;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    _leaveId = e?.id ?? const Uuid().v4();
    _studentId = e?.studentId;
    _start = e?.startAt ?? DateTime.now();
    _end = e?.endAt ?? DateTime.now().add(const Duration(hours: 4));
    _reason.text = e?.reason ?? '';
    _pickup.text = e?.pickup ?? '';
    _proofStored = e?.proofStoredName ?? '';
    _proofOriginal = e?.proofOriginalName ?? '';
  }

  @override
  void dispose() {
    _reason.dispose();
    _pickup.dispose();
    super.dispose();
  }

  String get _dateKey => DateFormat('yyyy-MM-dd').format(_start);

  Future<void> _pickProof() async {
    final result = await FilePicker.pickFiles(type: FileType.any);
    if (result == null || result.files.isEmpty) return;
    final f = result.files.first;
    if (f.path == null) return;
    final ctrl = context.read<ClassController>();
    final imported = await ctrl.importLeaveProof(
      leaveId: _leaveId,
      sourcePath: f.path!,
      originalName: f.name,
    );
    setState(() {
      _proofStored = imported.storedName;
      _proofOriginal = imported.originalName;
    });
  }

  Future<void> _save() async {
    final id = _studentId;
    if (id == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('请选择学生')),
      );
      return;
    }
    if (_end.isBefore(_start)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('结束时间不能早于开始时间')),
      );
      return;
    }
    setState(() => _saving = true);
    final existing = widget.existing;
    await context.read<ClassController>().saveLeaveRecord(
          id: _leaveId,
          studentId: id,
          date: _dateKey,
          reason: _reason.text,
          pickup: _pickup.text,
          startAt: _start,
          endAt: _end,
          proofStoredName: _proofStored,
          proofOriginalName: _proofOriginal,
          status: existing?.status ?? LeaveStatus.active,
          returnedAt: existing?.returnedAt,
        );
    if (!mounted) return;
    Navigator.pop(context);
  }

  Future<void> _pickDateTime({required bool isStart}) async {
    final initial = isStart ? _start : _end;
    final date = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(2020),
      lastDate: DateTime(2035),
    );
    if (date == null || !mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(initial),
    );
    if (time == null || !mounted) return;
    final dt = DateTime(date.year, date.month, date.day, time.hour, time.minute);
    setState(() {
      if (isStart) {
        _start = dt;
      } else {
        _end = dt;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final students = context.watch<ClassController>().students;
    final fmt = DateFormat('yyyy-MM-dd HH:mm');

    return Scaffold(
      backgroundColor: AppTheme.bg,
      appBar: PageAppBar(
        title: Text(widget.existing == null ? '登记请假' : '编辑请假'),
        actions: [
          TextButton(onPressed: _saving ? null : _save, child: const Text('保存')),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
        children: [
          GroupedSection(
            header: '学生',
            children: [
              GroupedTile(
                title: () {
                  if (_studentId == null) return '选择学生';
                  for (final s in students) {
                    if (s.id == _studentId) return s.name;
                  }
                  return '未知';
                }(),
                trailing: const Icon(AppIcons.chevronRight, size: 18),
                onTap: widget.existing != null
                    ? null
                    : () async {
                        final picked = await showModalBottomSheet<String>(
                          context: context,
                          showDragHandle: true,
                          builder: (ctx) => ListView(
                            children: [
                              for (final s in students)
                                ListTile(
                                  title: Text(s.name),
                                  subtitle: Text(s.studentNo),
                                  onTap: () => Navigator.pop(ctx, s.id),
                                ),
                            ],
                          ),
                        );
                        if (picked != null) setState(() => _studentId = picked);
                      },
              ),
            ],
          ),
          const SizedBox(height: 16),
          GroupedSection(
            header: '时间',
            children: [
              GroupedTile(
                title: '开始',
                trailing: Text(fmt.format(_start)),
                onTap: () => _pickDateTime(isStart: true),
              ),
              GroupedTile(
                title: '结束',
                trailing: Text(fmt.format(_end)),
                onTap: () => _pickDateTime(isStart: false),
              ),
            ],
          ),
          const SizedBox(height: 16),
          GroupedSection(
            header: '详情',
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                child: TextField(
                  controller: _reason,
                  decoration: const InputDecoration(
                    labelText: '事由',
                    border: InputBorder.none,
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                child: TextField(
                  controller: _pickup,
                  decoration: const InputDecoration(
                    labelText: '接送 / 备注',
                    border: InputBorder.none,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          GroupedSection(
            header: '凭证',
            children: [
              GroupedTile(
                title: _proofOriginal.isEmpty ? '上传凭证图片/文件' : _proofOriginal,
                leading: Icon(AppIcons.photo, color: AppTheme.blue),
                onTap: _pickProof,
              ),
            ],
          ),
        ],
      ),
    );
  }
}
