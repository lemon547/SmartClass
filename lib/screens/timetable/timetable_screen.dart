import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:smart_class/providers/class_controller.dart';
import 'package:smart_class/theme/app_theme.dart';

class TimetableScreen extends StatelessWidget {
  const TimetableScreen({super.key});

  static const _days = ['一', '二', '三', '四', '五', '六', '日'];

  @override
  Widget build(BuildContext context) {
    final ctrl = context.watch<ClassController>();

    return Scaffold(
      appBar: AppBar(title: const Text('课程表')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(12),
        scrollDirection: Axis.horizontal,
        child: SingleChildScrollView(
          child: DataTable(
            headingRowHeight: 36,
            dataRowMinHeight: 44,
            dataRowMaxHeight: 52,
            columnSpacing: 10,
            headingTextStyle: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: AppTheme.tertiaryLabel,
            ),
            columns: [
              const DataColumn(label: Text('节')),
              for (final d in _days) DataColumn(label: Text(d)),
            ],
            rows: [
              for (var period = 1; period <= 8; period++)
                DataRow(
                  cells: [
                    DataCell(Text('$period',
                        style: TextStyle(color: AppTheme.tertiaryLabel))),
                    for (var weekday = 1; weekday <= 7; weekday++)
                      DataCell(
                        InkWell(
                          onTap: () => _edit(context, weekday, period),
                          child: SizedBox(
                            width: 56,
                            child: Text(
                              ctrl.subjectAt(weekday, period) ?? '·',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 13,
                                color: ctrl.subjectAt(weekday, period) == null
                                    ? AppTheme.quaternaryLabel
                                    : AppTheme.label,
                              ),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _edit(BuildContext context, int weekday, int period) async {
    final ctrl = context.read<ClassController>();
    final text = TextEditingController(
      text: ctrl.subjectAt(weekday, period) ?? '',
    );
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) {
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
              Text('周${_days[weekday - 1]} 第$period 节',
                  style: Theme.of(ctx).textTheme.titleLarge),
              const SizedBox(height: 12),
              TextField(
                controller: text,
                decoration: const InputDecoration(hintText: '科目，留空清除'),
                autofocus: true,
              ),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: () async {
                  await ctrl.setTimetableSlot(
                    weekday: weekday,
                    period: period,
                    subject: text.text,
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
  }
}
