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
import 'package:smart_class/widgets/apple_widgets.dart';

class TitleMaterialsScreen extends StatefulWidget {
  const TitleMaterialsScreen({super.key});

  @override
  State<TitleMaterialsScreen> createState() => _TitleMaterialsScreenState();
}

class _TitleMaterialsScreenState extends State<TitleMaterialsScreen> {
  final Set<int> _expandedYears = {};

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<ClassController>().refreshTitleMaterials();
    });
  }

  Map<int, Map<String, List<TitleMaterial>>> _group(
    List<TitleMaterial> items,
  ) {
    final byYear = <int, Map<String, List<TitleMaterial>>>{};
    for (final m in items) {
      byYear.putIfAbsent(m.year, () => {});
      byYear[m.year]!.putIfAbsent(m.category, () => []).add(m);
    }
    return byYear;
  }

  Future<void> _import() async {
    final result = await FilePicker.pickFiles(type: FileType.any);
    if (result == null || result.files.isEmpty) return;
    final f = result.files.first;
    if (f.path == null) return;

    var year = DateTime.now().year;
    var category = TitleMaterial.categories.first;
    final title = TextEditingController(text: f.name);

    final ok = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setLocal) {
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
                    '归档材料',
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
                    value: year,
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
                      if (v != null) setLocal(() => year = v);
                    },
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    value: category,
                    decoration: const InputDecoration(
                      labelText: '分类',
                      border: OutlineInputBorder(),
                    ),
                    items: [
                      for (final c in TitleMaterial.categories)
                        DropdownMenuItem(value: c, child: Text(c)),
                    ],
                    onChanged: (v) {
                      if (v != null) setLocal(() => category = v);
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
      },
    );
    if (ok != true || !mounted) return;

    await context.read<ClassController>().importTitleMaterial(
          year: year,
          category: category,
          title: title.text,
          sourcePath: f.path!,
          originalName: f.name,
        );
    if (mounted) {
      setState(() => _expandedYears.add(year));
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('已归档')),
      );
    }
  }

  Future<void> _editMeta(TitleMaterial item) async {
    var year = item.year;
    var category = item.category;
    final title = TextEditingController(text: item.title);
    final ok = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setLocal) {
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
                    value: year,
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
                      if (v != null) setLocal(() => year = v);
                    },
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    value: TitleMaterial.categories.contains(category)
                        ? category
                        : '其他',
                    decoration: const InputDecoration(
                      labelText: '分类',
                      border: OutlineInputBorder(),
                    ),
                    items: [
                      for (final c in TitleMaterial.categories)
                        DropdownMenuItem(value: c, child: Text(c)),
                    ],
                    onChanged: (v) {
                      if (v != null) setLocal(() => category = v);
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
      },
    );
    if (ok != true || !mounted) return;
    await context.read<ClassController>().updateTitleMaterial(
          item.copyWith(
            year: year,
            category: category,
            title: title.text.trim().isEmpty ? item.title : title.text.trim(),
          ),
        );
  }

  @override
  Widget build(BuildContext context) {
    final ctrl = context.watch<ClassController>();
    final grouped = _group(ctrl.titleMaterials);
    final years = grouped.keys.toList()..sort((a, b) => b.compareTo(a));

    return Scaffold(
      backgroundColor: AppTheme.bg,
      appBar: PageAppBar(
        title: const Text('职称材料归档'),
        actions: [
          IconButton(
            tooltip: '导入文件',
            onPressed: _import,
            icon: const Icon(AppIcons.plus),
          ),
        ],
      ),
      body: years.isEmpty
          ? Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '按年份与分类归档职称材料',
                    style: TextStyle(color: AppTheme.tertiaryLabel),
                  ),
                  const SizedBox(height: 12),
                  FilledButton.icon(
                    onPressed: _import,
                    icon: const Icon(AppIcons.upload),
                    label: const Text('导入文件'),
                  ),
                ],
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
              itemCount: years.length,
              itemBuilder: (context, yi) {
                final year = years[yi];
                final cats = grouped[year]!;
                final expanded = _expandedYears.contains(year) ||
                    _expandedYears.isEmpty && yi == 0;
                final count =
                    cats.values.fold<int>(0, (n, list) => n + list.length);
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Material(
                      color: AppTheme.surface,
                      borderRadius: BorderRadius.circular(12),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(12),
                        onTap: () {
                          setState(() {
                            if (_expandedYears.contains(year)) {
                              _expandedYears.remove(year);
                            } else {
                              _expandedYears.add(year);
                            }
                          });
                        },
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 14,
                          ),
                          child: Row(
                            children: [
                              Icon(AppIcons.folder, color: AppTheme.blue),
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
                                style: TextStyle(
                                  color: AppTheme.secondaryLabel,
                                ),
                              ),
                              Icon(
                                expanded
                                    ? Icons.expand_less
                                    : Icons.expand_more,
                                color: AppTheme.tertiaryLabel,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    if (expanded) ...[
                      const SizedBox(height: 8),
                      for (final entry in cats.entries) ...[
                        Padding(
                          padding: const EdgeInsets.fromLTRB(8, 8, 8, 4),
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
                            padding: const EdgeInsets.only(bottom: 6),
                            child: Material(
                              color: AppTheme.surface,
                              borderRadius: BorderRadius.circular(10),
                              child: ListTile(
                                title: Text(m.title),
                                subtitle: Text(
                                  m.originalName.isEmpty
                                      ? DateFormat('M/d').format(m.createdAt)
                                      : m.originalName,
                                ),
                                trailing: PopupMenuButton<String>(
                                  onSelected: (v) async {
                                    final path =
                                        await ctrl.titleMaterialPath(m);
                                    if (v == 'open') {
                                      await MediaOpen.open(path);
                                    } else if (v == 'share') {
                                      await FileShare.shareFile(
                                        filePath: path,
                                        subject: m.title,
                                      );
                                    } else if (v == 'edit') {
                                      await _editMeta(m);
                                    } else if (v == 'delete') {
                                      final ok =
                                          await showCupertinoDialog<bool>(
                                        context: context,
                                        builder: (ctx) => CupertinoAlertDialog(
                                          title: const Text('删除材料？'),
                                          content: Text(m.title),
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
                                        await ctrl.deleteTitleMaterial(m.id);
                                      }
                                    }
                                  },
                                  itemBuilder: (_) => const [
                                    PopupMenuItem(
                                        value: 'open', child: Text('打开')),
                                    PopupMenuItem(
                                        value: 'share', child: Text('分享')),
                                    PopupMenuItem(
                                        value: 'edit', child: Text('编辑')),
                                    PopupMenuItem(
                                        value: 'delete', child: Text('删除')),
                                  ],
                                ),
                                onTap: () async {
                                  final path = await ctrl.titleMaterialPath(m);
                                  await MediaOpen.open(path);
                                },
                              ),
                            ),
                          ),
                      ],
                    ],
                    const SizedBox(height: 12),
                  ],
                );
              },
            ),
    );
  }
}
