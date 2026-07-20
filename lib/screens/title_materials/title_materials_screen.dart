import 'package:file_picker/file_picker.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:smart_class/models/models.dart';
import 'package:smart_class/providers/class_controller.dart';
import 'package:smart_class/services/file_share.dart';
import 'package:smart_class/services/media_open.dart';
import 'package:smart_class/theme/app_icons.dart';
import 'package:smart_class/theme/app_theme.dart';
import 'package:smart_class/widgets/app_toast.dart';
import 'package:smart_class/widgets/apple_widgets.dart';

class TitleMaterialsScreen extends StatefulWidget {
  const TitleMaterialsScreen({super.key});

  @override
  State<TitleMaterialsScreen> createState() => _TitleMaterialsScreenState();
}

class _TitleMaterialsScreenState extends State<TitleMaterialsScreen> {
  final Set<int> _expandedYears = {};
  final _search = TextEditingController();
  String _query = '';
  String? _categoryFilter;
  bool _didSeedExpand = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<ClassController>().refreshTitleMaterials();
    });
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  List<TitleMaterial> _filtered(List<TitleMaterial> all) {
    final q = _query.trim().toLowerCase();
    return all.where((m) {
      if (_categoryFilter != null && m.category != _categoryFilter) {
        return false;
      }
      if (q.isEmpty) return true;
      return m.title.toLowerCase().contains(q) ||
          m.originalName.toLowerCase().contains(q);
    }).toList();
  }

  Map<int, Map<String, List<TitleMaterial>>> _group(
    List<TitleMaterial> items,
  ) {
    final byYear = <int, Map<String, List<TitleMaterial>>>{};
    for (final m in items) {
      byYear.putIfAbsent(m.year, () => {});
      byYear[m.year]!.putIfAbsent(m.category, () => []).add(m);
    }
    for (final cats in byYear.values) {
      final ordered = <String, List<TitleMaterial>>{};
      for (final c in TitleMaterial.categories) {
        if (cats.containsKey(c)) ordered[c] = cats[c]!;
      }
      for (final e in cats.entries) {
        ordered.putIfAbsent(e.key, () => e.value);
      }
      cats
        ..clear()
        ..addAll(ordered);
    }
    return byYear;
  }

  Future<void> _import() async {
    final result = await FilePicker.pickFiles(
      type: FileType.any,
      allowMultiple: true,
    );
    if (result == null || result.files.isEmpty || !mounted) return;

    final files = result.files.where((f) => f.path != null).toList();
    if (files.isEmpty) return;

    var year = DateTime.now().year;
    var category = TitleMaterial.categories.first;
    final singleTitle = files.length == 1
        ? TextEditingController(text: files.first.name)
        : null;

    final ok = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (ctx) {
        return Padding(
          padding: EdgeInsets.only(
            left: 16,
            right: 16,
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                files.length == 1 ? '归档材料' : '归档 ${files.length} 个文件',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                files.length == 1
                    ? '选择年份与分类后保存到本机。'
                    : '共用同一年份与分类，各文件标题使用原文件名。',
                style: TextStyle(
                  fontSize: 13,
                  color: AppTheme.secondaryLabel,
                ),
              ),
              const SizedBox(height: 14),
              if (singleTitle != null) ...[
                TextField(
                  controller: singleTitle,
                  decoration: const InputDecoration(
                    labelText: '标题',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
              ],
              DropdownButtonFormField<int>(
                initialValue: year,
                decoration: const InputDecoration(
                  labelText: '年份',
                  border: OutlineInputBorder(),
                ),
                items: [
                  for (var y = DateTime.now().year + 1;
                      y >= DateTime.now().year - 10;
                      y--)
                    DropdownMenuItem(value: y, child: Text('$y')),
                ],
                onChanged: (v) {
                  if (v != null) year = v;
                },
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: category,
                decoration: const InputDecoration(
                  labelText: '分类',
                  border: OutlineInputBorder(),
                ),
                items: [
                  for (final c in TitleMaterial.categories)
                    DropdownMenuItem(value: c, child: Text(c)),
                ],
                onChanged: (v) {
                  if (v != null) category = v;
                },
              ),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: Text(files.length == 1 ? '保存' : '全部归档'),
              ),
            ],
          ),
        );
      },
    );

    if (ok != true || !mounted) {
      singleTitle?.dispose();
      return;
    }

    final ctrl = context.read<ClassController>();
    var saved = 0;
    for (final f in files) {
      final title = files.length == 1
          ? (singleTitle!.text.trim().isEmpty
              ? f.name
              : singleTitle.text.trim())
          : f.name;
      await ctrl.importTitleMaterial(
        year: year,
        category: category,
        title: title,
        sourcePath: f.path!,
        originalName: f.name,
      );
      saved++;
    }
    singleTitle?.dispose();

    if (!mounted) return;
    setState(() => _expandedYears.add(year));
    AppToast.success(
      context,
      saved == 1 ? '已归档' : '已归档 $saved 份材料',
    );
  }

  Future<void> _editMeta(TitleMaterial item) async {
    var year = item.year;
    var category = TitleMaterial.categories.contains(item.category)
        ? item.category
        : '其他';
    final title = TextEditingController(text: item.title);
    final ok = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (ctx) {
        return Padding(
          padding: EdgeInsets.only(
            left: 16,
            right: 16,
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                '编辑材料',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: title,
                decoration: const InputDecoration(
                  labelText: '标题',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<int>(
                initialValue: year,
                decoration: const InputDecoration(
                  labelText: '年份',
                  border: OutlineInputBorder(),
                ),
                items: [
                  for (var y = DateTime.now().year + 1;
                      y >= DateTime.now().year - 10;
                      y--)
                    DropdownMenuItem(value: y, child: Text('$y')),
                ],
                onChanged: (v) {
                  if (v != null) year = v;
                },
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: category,
                decoration: const InputDecoration(
                  labelText: '分类',
                  border: OutlineInputBorder(),
                ),
                items: [
                  for (final c in TitleMaterial.categories)
                    DropdownMenuItem(value: c, child: Text(c)),
                ],
                onChanged: (v) {
                  if (v != null) category = v;
                },
              ),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('保存'),
              ),
            ],
          ),
        );
      },
    );
    if (ok != true || !mounted) {
      title.dispose();
      return;
    }
    await context.read<ClassController>().updateTitleMaterial(
          item.copyWith(
            year: year,
            category: category,
            title: title.text.trim().isEmpty ? item.title : title.text.trim(),
          ),
        );
    title.dispose();
  }

  Future<void> _delete(TitleMaterial item) async {
    final ok = await showCupertinoDialog<bool>(
      context: context,
      builder: (ctx) => CupertinoAlertDialog(
        title: const Text('删除材料？'),
        content: Text(item.title),
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
    if (ok == true && mounted) {
      await context.read<ClassController>().deleteTitleMaterial(item.id);
    }
  }

  Future<void> _onMenu(String action, TitleMaterial m) async {
    final ctrl = context.read<ClassController>();
    if (action == 'edit') {
      await _editMeta(m);
      return;
    }
    if (action == 'delete') {
      await _delete(m);
      return;
    }
    final path = await ctrl.titleMaterialPath(m);
    if (action == 'open') {
      await MediaOpen.open(path);
    } else if (action == 'share') {
      await FileShare.shareFile(filePath: path, subject: m.title);
    }
  }

  @override
  Widget build(BuildContext context) {
    final ctrl = context.watch<ClassController>();
    final all = ctrl.titleMaterials;
    final filtered = _filtered(all);
    final grouped = _group(filtered);
    final years = grouped.keys.toList()..sort((a, b) => b.compareTo(a));
    if (!_didSeedExpand && years.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || _didSeedExpand) return;
        setState(() {
          _didSeedExpand = true;
          _expandedYears.add(years.first);
        });
      });
    }

    return Scaffold(
      backgroundColor: AppTheme.bg,
      appBar: PageAppBar(
        title: const Text('职称材料归档'),
        actions: [
          IconButton(
            tooltip: '导入',
            onPressed: _import,
            icon: const Icon(AppIcons.upload),
          ),
        ],
      ),
      body: all.isEmpty
          ? _EmptyState(onImport: _import)
          : Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _SummaryBar(items: all),
                SearchField(
                  controller: _search,
                  hint: '搜索标题或文件名',
                  onChanged: (v) => setState(() => _query = v),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        _CategoryChip(
                          label: '全部',
                          selected: _categoryFilter == null,
                          onTap: () => setState(() => _categoryFilter = null),
                        ),
                        const SizedBox(width: 8),
                        for (final c in TitleMaterial.categories) ...[
                          _CategoryChip(
                            label: c,
                            selected: _categoryFilter == c,
                            onTap: () => setState(() => _categoryFilter = c),
                          ),
                          const SizedBox(width: 8),
                        ],
                      ],
                    ),
                  ),
                ),
                Expanded(
                  child: years.isEmpty
                      ? Center(
                          child: Text(
                            '没有匹配的材料',
                            style: TextStyle(color: AppTheme.tertiaryLabel),
                          ),
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.fromLTRB(16, 4, 16, 28),
                          itemCount: years.length,
                          itemBuilder: (context, yi) {
                            final year = years[yi];
                            final cats = grouped[year]!;
                            final expanded = _expandedYears.contains(year);
                            final count = cats.values
                                .fold<int>(0, (n, list) => n + list.length);
                            return Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                _YearHeader(
                                  year: year,
                                  count: count,
                                  expanded: expanded,
                                  onTap: () {
                                    setState(() {
                                      if (_expandedYears.contains(year)) {
                                        _expandedYears.remove(year);
                                      } else {
                                        _expandedYears.add(year);
                                      }
                                    });
                                  },
                                ),
                                if (expanded) ...[
                                  const SizedBox(height: 8),
                                  for (final entry in cats.entries) ...[
                                    Padding(
                                      padding: const EdgeInsets.fromLTRB(
                                        4,
                                        6,
                                        4,
                                        4,
                                      ),
                                      child: Text(
                                        entry.key,
                                        style: TextStyle(
                                          fontSize: 13,
                                          fontWeight: FontWeight.w600,
                                          color: AppTheme.secondaryLabel,
                                        ),
                                      ),
                                    ),
                                    for (final m in entry.value)
                                      Padding(
                                        padding:
                                            const EdgeInsets.only(bottom: 6),
                                        child: _MaterialTile(
                                          item: m,
                                          onOpen: () async {
                                            final path = await ctrl
                                                .titleMaterialPath(m);
                                            await MediaOpen.open(path);
                                          },
                                          onMenu: (v) => _onMenu(v, m),
                                        ),
                                      ),
                                  ],
                                ],
                                const SizedBox(height: 12),
                              ],
                            );
                          },
                        ),
                ),
              ],
            ),
    );
  }
}

class _SummaryBar extends StatelessWidget {
  const _SummaryBar({required this.items});

  final List<TitleMaterial> items;

  @override
  Widget build(BuildContext context) {
    final years = items.map((e) => e.year).toSet().toList()..sort();
    final yearLabel = years.isEmpty
        ? ''
        : years.length == 1
            ? '${years.first} 年'
            : '${years.first}–${years.last} 年';

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
      child: Text(
        '共 ${items.length} 份'
        '${yearLabel.isEmpty ? '' : ' · 覆盖 $yearLabel'}',
        style: TextStyle(
          fontSize: 13,
          color: AppTheme.secondaryLabel,
        ),
      ),
    );
  }
}

class _CategoryChip extends StatelessWidget {
  const _CategoryChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return FilterChip(
      label: Text(label),
      selected: selected,
      showCheckmark: false,
      onSelected: (_) => onTap(),
      visualDensity: VisualDensity.compact,
      selectedColor: AppTheme.blue.withValues(alpha: 0.12),
      labelStyle: TextStyle(
        fontSize: 13,
        fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
        color: selected ? AppTheme.blue : AppTheme.label,
      ),
      side: BorderSide(
        color: selected ? AppTheme.blue.withValues(alpha: 0.35) : AppTheme.separator,
      ),
    );
  }
}

class _YearHeader extends StatelessWidget {
  const _YearHeader({
    required this.year,
    required this.count,
    required this.expanded,
    required this.onTap,
  });

  final int year;
  final int count;
  final bool expanded;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppTheme.surface,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          child: Row(
            children: [
              Icon(AppIcons.folder, color: AppTheme.blue, size: 20),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  '$year 年',
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              Text(
                '$count 份',
                style: TextStyle(color: AppTheme.secondaryLabel),
              ),
              Icon(
                expanded ? Icons.expand_less : Icons.expand_more,
                color: AppTheme.tertiaryLabel,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MaterialTile extends StatelessWidget {
  const _MaterialTile({
    required this.item,
    required this.onOpen,
    required this.onMenu,
  });

  final TitleMaterial item;
  final VoidCallback onOpen;
  final ValueChanged<String> onMenu;

  @override
  Widget build(BuildContext context) {
    final meta = [
      if (item.sizeBytes > 0) _formatSize(item.sizeBytes),
      DateFormat('M月d日').format(item.createdAt),
    ].join(' · ');

    return Material(
      color: AppTheme.surface,
      borderRadius: BorderRadius.circular(10),
      child: ListTile(
        contentPadding: const EdgeInsets.fromLTRB(12, 2, 4, 2),
        leading: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: AppTheme.blue.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(
            _fileIcon(item),
            size: 20,
            color: AppTheme.blue,
          ),
        ),
        title: Text(
          item.title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontWeight: FontWeight.w500),
        ),
        subtitle: Text(
          meta,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(fontSize: 12, color: AppTheme.tertiaryLabel),
        ),
        trailing: PopupMenuButton<String>(
          icon: Icon(AppIcons.moreVert, color: AppTheme.tertiaryLabel),
          onSelected: onMenu,
          itemBuilder: (_) => const [
            PopupMenuItem(value: 'open', child: Text('打开')),
            PopupMenuItem(value: 'share', child: Text('分享')),
            PopupMenuItem(value: 'edit', child: Text('编辑')),
            PopupMenuItem(value: 'delete', child: Text('删除')),
          ],
        ),
        onTap: onOpen,
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.onImport});

  final VoidCallback onImport;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(24, 48, 24, 32),
      children: [
        Icon(
          AppIcons.folder,
          size: 44,
          color: AppTheme.blue.withValues(alpha: 0.85),
        ),
        const SizedBox(height: 16),
        const Text(
          '按年份与分类归档',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w700,
            letterSpacing: -0.3,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          '把教学成果、证书、论文等收好，职称评审时按年、按类快速取用。',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 14,
            height: 1.45,
            color: AppTheme.secondaryLabel,
          ),
        ),
        const SizedBox(height: 28),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          alignment: WrapAlignment.center,
          children: [
            for (final c in TitleMaterial.categories)
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: AppTheme.surface,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: AppTheme.separator),
                ),
                child: Text(
                  c,
                  style: TextStyle(
                    fontSize: 13,
                    color: AppTheme.secondaryLabel,
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 36),
        FilledButton.icon(
          onPressed: onImport,
          icon: const Icon(AppIcons.upload),
          label: const Text('导入文件'),
        ),
      ],
    );
  }
}

IconData _fileIcon(TitleMaterial m) {
  final name = '${m.originalName} ${m.mimeHint}'.toLowerCase();
  if (name.contains('image') ||
      name.endsWith('.png') ||
      name.endsWith('.jpg') ||
      name.endsWith('.jpeg') ||
      name.endsWith('.heic') ||
      name.endsWith('.webp') ||
      name.endsWith('.gif')) {
    return AppIcons.photo;
  }
  if (name.endsWith('.xls') ||
      name.endsWith('.xlsx') ||
      name.endsWith('.csv') ||
      name.contains('sheet')) {
    return AppIcons.fileSheet;
  }
  if (name.contains('video') ||
      name.endsWith('.mp4') ||
      name.endsWith('.mov')) {
    return AppIcons.video;
  }
  return AppIcons.file;
}

String _formatSize(int bytes) {
  if (bytes < 1024) return '$bytes B';
  if (bytes < 1024 * 1024) {
    return '${(bytes / 1024).toStringAsFixed(bytes < 10 * 1024 ? 1 : 0)} KB';
  }
  return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
}
