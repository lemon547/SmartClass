import 'package:flutter/cupertino.dart';
import 'package:smart_class/theme/app_icons.dart';
import 'package:flutter/material.dart';

import 'package:provider/provider.dart';
import 'package:smart_class/models/models.dart';
import 'package:smart_class/providers/class_controller.dart';
import 'package:smart_class/theme/app_theme.dart';
import 'package:smart_class/widgets/apple_widgets.dart';

class SeatingScreen extends StatelessWidget {
  const SeatingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final ctrl = context.watch<ClassController>();
    final rows = ctrl.profile.seatRows;
    final cols = ctrl.profile.seatCols;

    Student? at(int r, int c) {
      for (final s in ctrl.students) {
        if (s.seatRow == r && s.seatCol == c) return s;
      }
      return null;
    }

    return Scaffold(
      appBar: PageAppBar(
        title: const Text('座位表'),
        actions: [
          TextButton(
            onPressed: () async {
              final ok = await showCupertinoDialog<bool>(
                context: context,
                builder: (ctx) => CupertinoAlertDialog(
                  title: const Text('一键排座？'),
                  content: const Text('按花名册顺序自动填入座位，超出行列的学生将清空座位。'),
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
            child: const Text('自动排座'),
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
            padding: EdgeInsets.fromLTRB(16, 4, 16, 12),
            child: Text(
              '点击空位分配学生 · 长按座位清空',
              style: TextStyle(color: AppTheme.secondaryLabel, fontSize: 13),
            ),
          ),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 24),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Column(
                  children: [
                    for (var r = 0; r < rows; r++)
                      Row(
                        children: [
                          for (var c = 0; c < cols; c++)
                            _SeatCell(
                              student: at(r, c),
                              onTap: () => _assign(context, r, c),
                              onLongPress: () {
                                final s = at(r, c);
                                if (s != null) ctrl.clearSeat(s.id);
                              },
                            ),
                        ],
                      ),
                  ],
                ),
              ),
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
                child: Text('选择学生',
                    style:
                        TextStyle(fontSize: 17, fontWeight: FontWeight.w600)),
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
    required this.onLongPress,
  });

  final Student? student;
  final VoidCallback onTap;
  final VoidCallback onLongPress;

  @override
  Widget build(BuildContext context) {
    final filled = student != null;
    return Padding(
      padding: const EdgeInsets.all(4),
      child: Material(
        color: filled ? AppTheme.blue.withValues(alpha: 0.12) : AppTheme.surface,
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
