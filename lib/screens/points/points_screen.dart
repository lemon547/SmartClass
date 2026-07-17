import 'package:smart_class/theme/app_icons.dart';
import 'package:flutter/material.dart';

import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:smart_class/models/models.dart';
import 'package:smart_class/providers/class_controller.dart';
import 'package:smart_class/screens/points/point_rules_screen.dart';
import 'package:smart_class/theme/app_theme.dart';
import 'package:smart_class/theme/mascot_assets.dart';
import 'package:smart_class/widgets/apple_widgets.dart';
import 'package:smart_class/widgets/data_charts.dart';
import 'package:smart_class/widgets/excel_import_sheet.dart';
import 'package:smart_class/widgets/paddi_mascot.dart';

class PointsScreen extends StatefulWidget {
  const PointsScreen({super.key});

  @override
  State<PointsScreen> createState() => _PointsScreenState();
}

class _PointsScreenState extends State<PointsScreen> {
  final _search = TextEditingController();
  String _query = '';

  static const _periods = [
    ('today', '今日'),
    ('week', '本周'),
    ('month', '本月'),
    ('total', '累计'),
  ];

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ctrl = context.watch<ClassController>();
    final ranked = ctrl.rankedByPoints
        .where((s) =>
            _query.isEmpty ||
            s.name.contains(_query) ||
            s.studentNo.contains(_query) ||
            s.groupName.contains(_query))
        .toList();

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            LargeTitle(
              '积分',
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    tooltip: 'Excel 批量加减分',
                    onPressed: () => showExcelImportActions(
                      context: context,
                      title: '积分',
                      downloadTemplate: () =>
                          context.read<ClassController>().exportPointTemplateFile(),
                      importBytes: (bytes, _) =>
                          context.read<ClassController>().importPointsFromBytes(bytes),
                    ),
                    icon: const Icon(Icons.table_chart_outlined),
                  ),
                  IconButton(
                    tooltip: '积分规则',
                    onPressed: () => Navigator.of(context).push(
                      MaterialPageRoute(
                          builder: (_) => const PointRulesScreen()),
                    ),
                    icon: Icon(AppIcons.sliders, color: AppTheme.blue),
                  ),
                  IconButton(
                    tooltip: '撤销上一次',
                    onPressed: () => _undo(context),
                    icon: Icon(AppIcons.undo, color: AppTheme.blue),
                  ),
                ],
              ),
            ),
            SearchField(
              controller: _search,
              hint: '搜索学生',
              onChanged: (v) => setState(() => _query = v),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
              child: Row(
                children: [
                  for (final (key, label) in _periods) ...[
                    Expanded(
                      child: GestureDetector(
                        onTap: () => ctrl.setRankPeriod(key),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: ctrl.rankPeriod == key
                                ? AppTheme.blue.withValues(alpha: 0.12)
                                : Colors.transparent,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            label,
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: ctrl.rankPeriod == key
                                  ? FontWeight.w600
                                  : FontWeight.w400,
                              color: ctrl.rankPeriod == key
                                  ? AppTheme.blue
                                  : AppTheme.secondaryLabel,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.only(bottom: 28),
                children: [
                  if (_query.isEmpty && ranked.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    ChartCard(
                      title: '积分排行 Top 10',
                      height: ranked.take(10).length * 28.0 + 8,
                      child: HorizontalRankChart(
                        items: [
                          for (final s in ranked.take(10))
                            ChartBarItem(
                              label: s.name,
                              value: ctrl.scoreForRank(s).toDouble(),
                            ),
                        ],
                      ),
                    ),
                  ],
                  GroupedSection(
                    header: '排行',
                    children: [
                      if (ranked.isEmpty)
                        const Padding(
                          padding: EdgeInsets.all(18),
                          child: Center(
                            child: PaddiEmptyHint(
                              message: '暂无学生',
                              asset: MascotAssets.sleepy,
                            ),
                          ),
                        )
                      else
                        for (var i = 0; i < ranked.length; i++)
                          GroupedTile(
                            title: '${i + 1}.  ${ranked[i].name}',
                            subtitle: _subtitle(ranked[i], ctrl),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  '${ctrl.scoreForRank(ranked[i])}',
                                  style: const TextStyle(fontSize: 17),
                                ),
                                IconButton(
                                  visualDensity: VisualDensity.compact,
                                  onPressed: () => _adjust(
                                      context, ranked[i].id, ranked[i].name, true),
                                  icon: Icon(AppIcons.plus,
                                      size: 20, color: AppTheme.blue),
                                ),
                                IconButton(
                                  visualDensity: VisualDensity.compact,
                                  onPressed: () => _adjust(
                                      context, ranked[i].id, ranked[i].name, false),
                                  icon: Icon(AppIcons.minus,
                                      size: 20, color: AppTheme.blue),
                                ),
                              ],
                            ),
                          ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  GroupedSection(
                    header: '最近记录',
                    children: [
                      if (ctrl.pointRecords.isEmpty)
                        const Padding(
                          padding: EdgeInsets.all(18),
                          child: Center(
                            child: PaddiEmptyHint(
                              message: '暂无记录',
                              asset: MascotAssets.classic,
                            ),
                          ),
                        )
                      else
                        for (final r in ctrl.pointRecords.take(30))
                          GroupedTile(
                            title:
                                '${ctrl.studentById(r.studentId)?.name ?? '未知'} · ${r.reason}',
                            subtitle:
                                DateFormat('M/d HH:mm').format(r.createdAt),
                            trailing: Text(
                              '${r.delta > 0 ? '+' : ''}${r.delta}',
                              style: const TextStyle(fontSize: 17),
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

  String? _subtitle(Student s, ClassController ctrl) {
    final parts = <String>[];
    if (ctrl.rankPeriod == 'total') {
      parts.add(rankTitle(s.points));
    }
    if (s.groupName.isNotEmpty) parts.add(s.groupName);
    if (ctrl.rankPeriod != 'total') {
      parts.add('累计 ${s.points}');
    }
    return parts.isEmpty ? null : parts.join(' · ');
  }

  Future<void> _undo(BuildContext context) async {
    final ctrl = context.read<ClassController>();
    final record = await ctrl.undoLastPoint();
    if (!context.mounted) return;
    if (record == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('没有可撤销的记录')),
      );
      return;
    }
    final name = ctrl.studentById(record.studentId)?.name ?? '未知';
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          '已撤销：$name ${record.delta > 0 ? '+' : ''}${record.delta}（${record.reason}）',
        ),
      ),
    );
  }

  Future<void> _adjust(
    BuildContext context,
    String studentId,
    String name,
    bool positive,
  ) async {
    final ctrl = context.read<ClassController>();
    final presets = ctrl.pointPresets
        .where((p) => positive ? p.delta >= 0 : p.delta < 0)
        .toList();
    final fallback = positive
        ? const PointReasonPreset(reason: '表扬', delta: 2)
        : const PointReasonPreset(reason: '提醒', delta: -1);
    final list = presets.isEmpty ? [fallback] : presets;
    var selected = list.first;
    var amount = selected.delta.abs().clamp(1, 99);

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setState) {
            return Padding(
              padding: EdgeInsets.only(
                left: 20,
                right: 20,
                top: 16,
                bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text('$name · ${positive ? '加分' : '扣分'}',
                      style: Theme.of(ctx).textTheme.titleLarge),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final p in list)
                        ChoiceChip(
                          label: Text(
                            '${p.reason} ${p.delta > 0 ? '+' : ''}${p.delta}',
                          ),
                          selected: selected.reason == p.reason,
                          onSelected: (_) => setState(() {
                            selected = p;
                            amount = p.delta.abs().clamp(1, 99);
                          }),
                        ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      const Text('分值'),
                      const Spacer(),
                      IconButton(
                        onPressed: () => setState(() {
                          if (amount > 1) amount--;
                        }),
                        icon: const Icon(AppIcons.circleMinus),
                      ),
                      Text('$amount',
                          style: const TextStyle(
                              fontSize: 22, fontWeight: FontWeight.w600)),
                      IconButton(
                        onPressed: () => setState(() => amount++),
                        icon: const Icon(AppIcons.circlePlus),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  FilledButton(
                    onPressed: () async {
                      await ctrl.adjustPoints(
                        studentId: studentId,
                        delta: positive ? amount : -amount,
                        reason: selected.reason,
                      );
                      if (ctx.mounted) Navigator.pop(ctx);
                    },
                    child: const Text('确认'),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}
