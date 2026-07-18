import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:smart_class/models/models.dart';
import 'package:smart_class/providers/class_controller.dart';
import 'package:smart_class/theme/app_icons.dart';
import 'package:smart_class/theme/app_theme.dart';

/// 成绩册：左冻结姓名、中滑科目、右冻结总分/班内名次；可选显示导入名次
class ExamScoresheet extends StatefulWidget {
  const ExamScoresheet({
    super.key,
    required this.exam,
    required this.onImport,
    required this.onExport,
  });

  final Exam exam;
  final VoidCallback onImport;
  final VoidCallback onExport;

  static String fmt(double v) =>
      v == v.roundToDouble() ? '${v.round()}' : v.toStringAsFixed(1);

  @override
  State<ExamScoresheet> createState() => _ExamScoresheetState();
}

class _ExamScoresheetState extends State<ExamScoresheet> {
  static const _nameW = 76.0;
  static const _cellW = 56.0;
  static const _rankW = 40.0;
  static const _totalW = 48.0;
  static const _rowH = 44.0;
  static const _headerH = 40.0;

  final _hBody = ScrollController();
  final _hHead = ScrollController();
  final _vLeft = ScrollController();
  final _vMid = ScrollController();
  final _vRight = ScrollController();

  bool _syncingH = false;
  bool _syncingV = false;

  @override
  void initState() {
    super.initState();
    _hBody.addListener(_onHBody);
    _hHead.addListener(_onHHead);
    _vLeft.addListener(_onVLeft);
    _vMid.addListener(_onVMid);
    _vRight.addListener(_onVRight);
  }

  @override
  void dispose() {
    _hBody.removeListener(_onHBody);
    _hHead.removeListener(_onHHead);
    _vLeft.removeListener(_onVLeft);
    _vMid.removeListener(_onVMid);
    _vRight.removeListener(_onVRight);
    _hBody.dispose();
    _hHead.dispose();
    _vLeft.dispose();
    _vMid.dispose();
    _vRight.dispose();
    super.dispose();
  }

  void _linkH(ScrollController from, ScrollController to) {
    if (_syncingH || !to.hasClients) return;
    _syncingH = true;
    if (to.offset != from.offset) to.jumpTo(from.offset);
    _syncingH = false;
  }

  void _linkV(ScrollController from, ScrollController to) {
    if (_syncingV || !to.hasClients) return;
    _syncingV = true;
    if (to.offset != from.offset) to.jumpTo(from.offset);
    _syncingV = false;
  }

  void _onHBody() => _linkH(_hBody, _hHead);
  void _onHHead() => _linkH(_hHead, _hBody);
  void _onVLeft() {
    _linkV(_vLeft, _vMid);
    _linkV(_vLeft, _vRight);
  }

  void _onVMid() {
    _linkV(_vMid, _vLeft);
    _linkV(_vMid, _vRight);
  }

  void _onVRight() {
    _linkV(_vRight, _vLeft);
    _linkV(_vRight, _vMid);
  }

  @override
  Widget build(BuildContext context) {
    final ctrl = context.watch<ClassController>();
    final exam = widget.exam;
    final students = ctrl.students;
    final byStudent = <String, ExamScore>{
      for (final s in ctrl.scoresOfExam(exam.id)) s.studentId: s,
    };
    final classRanks = ctrl.classRankByTotal(exam.id);
    final recorded = byStudent.values.where((s) => s.scores.isNotEmpty).length;
    final showConverted = byStudent.values.any((s) => s.convertedRank != null);
    final showGrade = byStudent.values.any((s) => s.gradeRank != null);

    if (students.isEmpty) {
      return const _SheetEmpty(message: '请先添加本班学生花名册');
    }
    if (exam.subjects.isEmpty) {
      return const _SheetEmpty(message: '请先在编辑考试中设置科目');
    }

    final midW = exam.subjects.length * _cellW;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 8, 6),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  '已录 $recorded / ${students.length} · 左右滑科目 · 点格改分',
                  style: TextStyle(fontSize: 12, color: AppTheme.tertiaryLabel),
                ),
              ),
              TextButton(
                onPressed: widget.onExport,
                child: const Text('导出'),
              ),
              TextButton.icon(
                onPressed: widget.onImport,
                icon: const Icon(AppIcons.download, size: 16),
                label: const Text('导入'),
              ),
            ],
          ),
        ),
        // 表头
        SizedBox(
          height: _headerH,
          child: Row(
            children: [
              _HeaderCell(width: _nameW, label: '姓名', align: TextAlign.left),
              Expanded(
                child: SingleChildScrollView(
                  controller: _hHead,
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      for (final s in exam.subjects)
                        _HeaderCell(
                          width: _cellW,
                          label: s,
                          align: TextAlign.center,
                        ),
                    ],
                  ),
                ),
              ),
              _HeaderCell(width: _totalW, label: '总分'),
              _HeaderCell(width: _rankW, label: '班名'),
              if (showConverted) _HeaderCell(width: _rankW, label: '折算'),
              if (showGrade) _HeaderCell(width: _rankW, label: '年级'),
            ],
          ),
        ),
        Divider(height: 1, color: AppTheme.separator),
        Expanded(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // 左：姓名
              SizedBox(
                width: _nameW,
                child: ListView.builder(
                  controller: _vLeft,
                  itemExtent: _rowH,
                  itemCount: students.length,
                  itemBuilder: (_, i) {
                    final stu = students[i];
                    return _NameCell(
                      name: stu.name,
                      studentNo: stu.studentNo,
                      stripe: i.isEven,
                    );
                  },
                ),
              ),
              // 中：科目
              Expanded(
                child: SingleChildScrollView(
                  controller: _hBody,
                  scrollDirection: Axis.horizontal,
                  child: SizedBox(
                    width: midW,
                    child: ListView.builder(
                      controller: _vMid,
                      itemExtent: _rowH,
                      itemCount: students.length,
                      itemBuilder: (_, i) {
                        final stu = students[i];
                        final score = byStudent[stu.id];
                        return Container(
                          height: _rowH,
                          color: i.isEven ? AppTheme.bg : AppTheme.surface,
                          child: Row(
                            children: [
                              for (final sub in exam.subjects)
                                _ScoreTapCell(
                                  width: _cellW,
                                  value: score?.scoreOf(sub),
                                  onTap: () => _editCell(
                                    context,
                                    exam: exam,
                                    student: stu,
                                    subject: sub,
                                    existing: score,
                                  ),
                                ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                ),
              ),
              // 右：总分 + 名次
              SizedBox(
                width: _totalW +
                    _rankW +
                    (showConverted ? _rankW : 0) +
                    (showGrade ? _rankW : 0),
                child: ListView.builder(
                  controller: _vRight,
                  itemExtent: _rowH,
                  itemCount: students.length,
                  itemBuilder: (_, i) {
                    final stu = students[i];
                    final score = byStudent[stu.id];
                    final has = score != null && score.scores.isNotEmpty;
                    return Container(
                      height: _rowH,
                      color: i.isEven ? AppTheme.bg : AppTheme.surface,
                      child: Row(
                        children: [
                          SizedBox(
                            width: _totalW,
                            child: Center(
                              child: Text(
                                has ? ExamScoresheet.fmt(score.total) : '—',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  fontFeatures: const [
                                    FontFeature.tabularFigures()
                                  ],
                                  color: has
                                      ? AppTheme.label
                                      : AppTheme.quaternaryLabel,
                                ),
                              ),
                            ),
                          ),
                          SizedBox(
                            width: _rankW,
                            child: Center(
                              child: Text(
                                classRanks[stu.id]?.toString() ?? '—',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: AppTheme.secondaryLabel,
                                  fontFeatures: const [
                                    FontFeature.tabularFigures()
                                  ],
                                ),
                              ),
                            ),
                          ),
                          if (showConverted)
                            SizedBox(
                              width: _rankW,
                              child: Center(
                                child: Text(
                                  score?.convertedRank?.toString() ?? '—',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: AppTheme.tertiaryLabel,
                                  ),
                                ),
                              ),
                            ),
                          if (showGrade)
                            SizedBox(
                              width: _rankW,
                              child: Center(
                                child: Text(
                                  score?.gradeRank?.toString() ?? '—',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: AppTheme.tertiaryLabel,
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Future<void> _editCell(
    BuildContext context, {
    required Exam exam,
    required Student student,
    required String subject,
    required ExamScore? existing,
  }) async {
    final value = existing?.scoreOf(subject);
    final text = TextEditingController(
      text: value == null ? '' : ExamScoresheet.fmt(value),
    );
    final focus = FocusNode();

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (ctx) {
        return Padding(
          padding: EdgeInsets.only(
            left: 20,
            right: 20,
            bottom: MediaQuery.viewInsetsOf(ctx).bottom + 20,
            top: 4,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                '${student.name} · $subject',
                style: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: text,
                focusNode: focus,
                autofocus: true,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
                ],
                decoration: InputDecoration(
                  labelText: '分数',
                  hintText: '0 – ${ExamScoresheet.fmt(exam.fullScore)}，留空清空',
                ),
                onSubmitted: (_) => _saveCell(
                  ctx,
                  exam: exam,
                  student: student,
                  subject: subject,
                  existing: existing,
                  raw: text.text.trim(),
                ),
              ),
              const SizedBox(height: 12),
              FilledButton(
                onPressed: () => _saveCell(
                  ctx,
                  exam: exam,
                  student: student,
                  subject: subject,
                  existing: existing,
                  raw: text.text.trim(),
                ),
                child: const Text('保存'),
              ),
            ],
          ),
        );
      },
    );
    text.dispose();
    focus.dispose();
  }

  Future<void> _saveCell(
    BuildContext ctx, {
    required Exam exam,
    required Student student,
    required String subject,
    required ExamScore? existing,
    required String raw,
  }) async {
    final ctrl = context.read<ClassController>();
    final scores = Map<String, double>.from(existing?.scores ?? {});
    if (raw.isEmpty) {
      scores.remove(subject);
      if (scores.isEmpty) {
        if (existing != null) {
          await ctrl.deleteExamScore(examId: exam.id, scoreId: existing.id);
        }
        if (ctx.mounted) Navigator.pop(ctx);
        return;
      }
    } else {
      final v = double.tryParse(raw);
      if (v == null || v < 0 || v > exam.fullScore) {
        ScaffoldMessenger.of(ctx).showSnackBar(
          SnackBar(
            content: Text(
              '分数应在 0–${ExamScoresheet.fmt(exam.fullScore)} 之间',
            ),
          ),
        );
        return;
      }
      scores[subject] = v;
    }
    await ctrl.saveExamScore(
      examId: exam.id,
      studentId: student.id,
      scores: scores,
      remark: existing?.remark ?? '',
      id: existing?.id,
    );
    if (ctx.mounted) Navigator.pop(ctx);
  }
}

class _SheetEmpty extends StatelessWidget {
  const _SheetEmpty({required this.message});
  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Text(message, style: TextStyle(color: AppTheme.tertiaryLabel)),
      ),
    );
  }
}

class _HeaderCell extends StatelessWidget {
  const _HeaderCell({
    required this.width,
    required this.label,
    this.align = TextAlign.center,
  });

  final double width;
  final String label;
  final TextAlign align;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: 40,
      alignment: align == TextAlign.left
          ? Alignment.centerLeft
          : Alignment.center,
      padding: EdgeInsets.only(left: align == TextAlign.left ? 10 : 0),
      color: AppTheme.surface,
      child: Text(
        label,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        textAlign: align,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: AppTheme.tertiaryLabel,
          height: 1.15,
        ),
      ),
    );
  }
}

class _NameCell extends StatelessWidget {
  const _NameCell({
    required this.name,
    required this.studentNo,
    required this.stripe,
  });

  final String name;
  final String studentNo;
  final bool stripe;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 44,
      padding: const EdgeInsets.only(left: 10, right: 4),
      alignment: Alignment.centerLeft,
      color: stripe ? AppTheme.bg : AppTheme.surface,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
          ),
          if (studentNo.isNotEmpty)
            Text(
              studentNo,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 10, color: AppTheme.quaternaryLabel),
            ),
        ],
      ),
    );
  }
}

class _ScoreTapCell extends StatelessWidget {
  const _ScoreTapCell({
    required this.width,
    required this.value,
    required this.onTap,
  });

  final double width;
  final double? value;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: SizedBox(
        width: width,
        height: 44,
        child: Center(
          child: Text(
            value == null ? '—' : ExamScoresheet.fmt(value!),
            style: TextStyle(
              fontSize: 13,
              fontFeatures: const [FontFeature.tabularFigures()],
              color:
                  value == null ? AppTheme.quaternaryLabel : AppTheme.label,
            ),
          ),
        ),
      ),
    );
  }
}
