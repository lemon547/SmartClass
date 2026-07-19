import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:smart_class/models/models.dart';
import 'package:smart_class/providers/class_controller.dart';
import 'package:smart_class/services/smart_seating.dart';
import 'package:smart_class/theme/app_icons.dart';
import 'package:smart_class/theme/app_theme.dart';
import 'package:smart_class/widgets/apple_widgets.dart';

class SeatingScreen extends StatefulWidget {
  const SeatingScreen({super.key});

  @override
  State<SeatingScreen> createState() => _SeatingScreenState();
}

class _SeatingScreenState extends State<SeatingScreen> {
  bool _swapMode = false;
  String? _swapFromId;

  Student? _at(ClassController ctrl, int r, int c) {
    for (final s in ctrl.students) {
      if (s.seatRow == r && s.seatCol == c) return s;
    }
    return null;
  }

  Future<void> _smartArrange(BuildContext context) async {
    final rules = <SeatingRule>{
      SeatingRule.genderAlternate,
      SeatingRule.studentNoOrder,
    };
    var useScore = false;

    final confirmed = await showModalBottomSheet<bool>(
      context: context,
      showDragHandle: true,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setLocal) {
            return Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text(
                    '智能排座',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '勾选规则后生成座位；若有冲突会先提示说明。',
                    style: TextStyle(
                      color: AppTheme.secondaryLabel,
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(height: 8),
                  CheckboxListTile(
                    value: rules.contains(SeatingRule.genderAlternate),
                    title: Text(SeatingRule.genderAlternate.label),
                    controlAffinity: ListTileControlAffinity.leading,
                    contentPadding: EdgeInsets.zero,
                    onChanged: (v) => setLocal(() {
                      if (v == true) {
                        rules.add(SeatingRule.genderAlternate);
                      } else {
                        rules.remove(SeatingRule.genderAlternate);
                      }
                    }),
                  ),
                  CheckboxListTile(
                    value: rules.contains(SeatingRule.studentNoOrder),
                    title: Text(SeatingRule.studentNoOrder.label),
                    controlAffinity: ListTileControlAffinity.leading,
                    contentPadding: EdgeInsets.zero,
                    onChanged: (v) => setLocal(() {
                      if (v == true) {
                        rules.add(SeatingRule.studentNoOrder);
                      } else {
                        rules.remove(SeatingRule.studentNoOrder);
                      }
                    }),
                  ),
                  CheckboxListTile(
                    value: useScore,
                    title: Text(SeatingRule.scoreBackHigh.label),
                    controlAffinity: ListTileControlAffinity.leading,
                    contentPadding: EdgeInsets.zero,
                    onChanged: (v) => setLocal(() {
                      useScore = v == true;
                      if (useScore) {
                        rules.add(SeatingRule.scoreBackHigh);
                      } else {
                        rules.remove(SeatingRule.scoreBackHigh);
                      }
                    }),
                  ),
                  const SizedBox(height: 8),
                  FilledButton(
                    onPressed: () => Navigator.pop(ctx, true),
                    child: const Text('生成并应用'),
                  ),
                  TextButton(
                    onPressed: () => Navigator.pop(ctx, false),
                    child: const Text('取消'),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
    if (confirmed != true || !context.mounted) return;

    final ctrl = context.read<ClassController>();
    Map<String, double>? totals;
    if (rules.contains(SeatingRule.scoreBackHigh)) {
      await ctrl.ensureAllExamScores();
      if (ctrl.exams.isNotEmpty) {
        final latest = ctrl.exams.first;
        final scores = ctrl.examScoresByExam[latest.id] ?? [];
        totals = {
          for (final s in scores) s.studentId: s.total,
        };
      }
    }

    final result = SmartSeating.arrange(
      students: ctrl.students,
      rows: ctrl.profile.seatRows,
      cols: ctrl.profile.seatCols,
      rules: rules,
      latestTotals: totals,
    );

    if (result.conflictNotes.isNotEmpty && context.mounted) {
      final go = await showCupertinoDialog<bool>(
        context: context,
        builder: (ctx) => CupertinoAlertDialog(
          title: const Text('排座说明'),
          content: Text(result.conflictNotes.join('\n')),
          actions: [
            CupertinoDialogAction(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('取消'),
            ),
            CupertinoDialogAction(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('仍然应用'),
            ),
          ],
        ),
      );
      if (go != true) return;
    }

    await ctrl.applySmartSeats(result.seats);
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('已应用智能排座')),
      );
    }
  }

  Future<void> _share(BuildContext context) async {
    final ctrl = context.read<ClassController>();
    final text = SmartSeating.seatingChartText(
      students: ctrl.students,
      rows: ctrl.profile.seatRows,
      cols: ctrl.profile.seatCols,
      className: ctrl.currentClass?.displayTitle ?? ctrl.profile.displayTitle,
    );
    await Share.share(text);
  }

  Future<void> _onSeatTap(
    BuildContext context,
    ClassController ctrl,
    int r,
    int c,
  ) async {
    final seated = _at(ctrl, r, c);
    if (_swapMode) {
      if (seated == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('请选择有人的座位进行对调')),
        );
        return;
      }
      if (_swapFromId == null) {
        setState(() => _swapFromId = seated.id);
        return;
      }
      if (_swapFromId == seated.id) {
        setState(() => _swapFromId = null);
        return;
      }
      await ctrl.swapStudentSeats(_swapFromId!, seated.id);
      setState(() {
        _swapFromId = null;
        _swapMode = false;
      });
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('已对调座位')),
        );
      }
      return;
    }

    if (seated != null) return;
    await _assign(context, r, c);
  }

  @override
  Widget build(BuildContext context) {
    final ctrl = context.watch<ClassController>();
    final rows = ctrl.profile.seatRows;
    final cols = ctrl.profile.seatCols;

    return Scaffold(
      appBar: PageAppBar(
        title: const Text('座位表'),
        actions: [
          IconButton(
            tooltip: '分享座位表',
            onPressed: () => _share(context),
            icon: const Icon(AppIcons.share),
          ),
          TextButton(
            onPressed: () => _smartArrange(context),
            child: const Text('智能排座'),
          ),
          IconButton(
            onPressed: () => _editGrid(context),
            icon: const Icon(AppIcons.sliders),
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
            child: Text(
              _swapMode
                  ? (_swapFromId == null
                      ? '对调模式：先点第一位学生，再点第二位'
                      : '已选中一位，再点另一位完成对调')
                  : '点击空位分配 · 长按清空 · 可开启对调',
              style: TextStyle(color: AppTheme.secondaryLabel, fontSize: 13),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: Row(
              children: [
                FilterChip(
                  label: const Text('对调座位'),
                  selected: _swapMode,
                  onSelected: (v) => setState(() {
                    _swapMode = v;
                    _swapFromId = null;
                  }),
                ),
                const SizedBox(width: 8),
                TextButton(
                  onPressed: () async {
                    final ok = await showCupertinoDialog<bool>(
                      context: context,
                      builder: (ctx) => CupertinoAlertDialog(
                        title: const Text('一键排座？'),
                        content: const Text(
                          '按花名册顺序自动填入座位，超出行列的学生将清空座位。',
                        ),
                        actions: [
                          CupertinoDialogAction(
                            onPressed: () => Navigator.pop(ctx, false),
                            child: const Text('取消'),
                          ),
                          CupertinoDialogAction(
                            onPressed: () => Navigator.pop(ctx, true),
                            child: const Text('排座'),
                          ),
                        ],
                      ),
                    );
                    if (ok == true) await ctrl.autoArrangeSeats();
                  },
                  child: const Text('按名册顺序'),
                ),
              ],
            ),
          ),
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) {
                return SingleChildScrollView(
                  child: ConstrainedBox(
                    constraints:
                        BoxConstraints(minHeight: constraints.maxHeight),
                    child: Center(
                      child: SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              for (var r = 0; r < rows; r++)
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    for (var c = 0; c < cols; c++)
                                      _SeatCell(
                                        student: _at(ctrl, r, c),
                                        highlighted: _swapFromId != null &&
                                            _at(ctrl, r, c)?.id ==
                                                _swapFromId,
                                        onTap: () =>
                                            _onSeatTap(context, ctrl, r, c),
                                        onLongPress: _swapMode
                                            ? null
                                            : () {
                                                final s = _at(ctrl, r, c);
                                                if (s != null) {
                                                  ctrl.clearSeat(s.id);
                                                }
                                              },
                                      ),
                                  ],
                                ),
                            ],
                          ),
                        ),
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

  Future<void> _editGrid(BuildContext context) async {
    final ctrl = context.read<ClassController>();
    var rows = ctrl.profile.seatRows;
    var cols = ctrl.profile.seatCols;
    await showModalBottomSheet<void>(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setState) {
            return Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('座位行列', style: Theme.of(ctx).textTheme.titleLarge),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      const Text('行'),
                      Expanded(
                        child: Slider(
                          value: rows.toDouble(),
                          min: 3,
                          max: 10,
                          divisions: 7,
                          label: '$rows',
                          onChanged: (v) => setState(() => rows = v.round()),
                        ),
                      ),
                      Text('$rows'),
                    ],
                  ),
                  Row(
                    children: [
                      const Text('列'),
                      Expanded(
                        child: Slider(
                          value: cols.toDouble(),
                          min: 4,
                          max: 10,
                          divisions: 6,
                          label: '$cols',
                          onChanged: (v) => setState(() => cols = v.round()),
                        ),
                      ),
                      Text('$cols'),
                    ],
                  ),
                  FilledButton(
                    onPressed: () async {
                      await ctrl.updateProfile(
                        ctrl.profile.copyWith(seatRows: rows, seatCols: cols),
                      );
                      if (ctx.mounted) Navigator.pop(ctx);
                    },
                    child: const Text('保存'),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _assign(BuildContext context, int row, int col) async {
    final ctrl = context.read<ClassController>();
    final existing = ctrl.students
        .where((s) => s.seatRow == row && s.seatCol == col)
        .toList();
    if (existing.isNotEmpty) return;

    final unseated =
        ctrl.students.where((s) => s.seatRow == null || s.seatCol == null);
    final candidates = [
      ...unseated,
      ...ctrl.students.where((s) => s.seatRow != null),
    ];
    if (candidates.isEmpty) return;

    await showModalBottomSheet<void>(
      context: context,
      builder: (ctx) {
        return SafeArea(
          child: ListView(
            shrinkWrap: true,
            children: [
              const Padding(
                padding: EdgeInsets.all(16),
                child: Text(
                  '选择学生',
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
                ),
              ),
              for (final s in candidates)
                ListTile(
                  leading: StudentAvatar(name: s.name, size: 36),
                  title: Text(s.name),
                  subtitle: s.seatRow == null
                      ? const Text('未排座')
                      : Text('当前 ${s.seatRow! + 1}排${s.seatCol! + 1}列'),
                  onTap: () async {
                    await ctrl.placeStudent(s.id, row, col);
                    if (ctx.mounted) Navigator.pop(ctx);
                  },
                ),
            ],
          ),
        );
      },
    );
  }
}

class _SeatCell extends StatelessWidget {
  const _SeatCell({
    required this.student,
    required this.onTap,
    this.onLongPress,
    this.highlighted = false,
  });

  final Student? student;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;
  final bool highlighted;

  @override
  Widget build(BuildContext context) {
    final filled = student != null;
    return Padding(
      padding: const EdgeInsets.all(4),
      child: Material(
        color: highlighted
            ? AppTheme.blue.withValues(alpha: 0.28)
            : filled
                ? AppTheme.blue.withValues(alpha: 0.12)
                : AppTheme.surface,
        borderRadius: BorderRadius.circular(10),
        child: InkWell(
          onTap: onTap,
          onLongPress: onLongPress,
          borderRadius: BorderRadius.circular(10),
          child: SizedBox(
            width: 64,
            height: 56,
            child: Center(
              child: Text(
                student?.name ?? '',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: filled ? AppTheme.blue : AppTheme.tertiaryLabel,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
