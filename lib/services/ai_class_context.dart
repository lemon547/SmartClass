import 'package:intl/intl.dart';
import 'package:smart_class/models/models.dart';
import 'package:smart_class/providers/class_controller.dart';

/// 班级数据包（类似 Cursor Skill：先看目录描述，再按需加载正文）。
enum AiDataPackId {
  students,
  studentsCompact,
  points,
  attendance,
  timetable,
  gradesOverview,
  examBrief,
  workLogs,
  todos,
}

extension AiDataPackIdX on AiDataPackId {
  String get wire => switch (this) {
        AiDataPackId.students => 'students',
        AiDataPackId.studentsCompact => 'students_compact',
        AiDataPackId.points => 'points',
        AiDataPackId.attendance => 'attendance',
        AiDataPackId.timetable => 'timetable',
        AiDataPackId.gradesOverview => 'grades_overview',
        AiDataPackId.examBrief => 'exam_brief',
        AiDataPackId.workLogs => 'work_logs',
        AiDataPackId.todos => 'todos',
      };

  /// 界面上「已查本班」短标签。
  String get shortLabel => switch (this) {
        AiDataPackId.students => '名单',
        AiDataPackId.studentsCompact => '名单',
        AiDataPackId.points => '积分',
        AiDataPackId.attendance => '考勤',
        AiDataPackId.timetable => '课表',
        AiDataPackId.gradesOverview => '成绩摘要',
        AiDataPackId.examBrief => '考试简报',
        AiDataPackId.workLogs => '留痕',
        AiDataPackId.todos => '待办',
      };

  static AiDataPackId? tryParse(String raw) {
    final t = raw.trim().toLowerCase();
    for (final id in AiDataPackId.values) {
      if (id.wire == t) return id;
    }
    return null;
  }
}

/// Agent 选型结果：要加载哪些包、考试简报用哪一场。
class AiPackSelection {
  const AiPackSelection({
    this.packs = const [],
    this.examId,
  });

  final List<AiDataPackId> packs;
  final String? examId;

  bool get isEmpty => packs.isEmpty;

  String get shortLabels {
    final seen = <String>{};
    final labels = <String>[];
    for (final p in packs) {
      if (seen.add(p.shortLabel)) labels.add(p.shortLabel);
    }
    return labels.join('、');
  }
}

/// 选型解析结果：区分「合法空包」与「解析失败」（行业：勿把失败当成空结果再瞎兜底）。
class AiPackSelectResult {
  const AiPackSelectResult._({
    required this.parsed,
    required this.selection,
  });

  final bool parsed;
  final AiPackSelection selection;

  factory AiPackSelectResult.ok(AiPackSelection selection) =>
      AiPackSelectResult._(parsed: true, selection: selection);

  factory AiPackSelectResult.invalid() => const AiPackSelectResult._(
        parsed: false,
        selection: AiPackSelection(),
      );
}

/// 本机班级数据：轻量目录 → Agent 选型 → 按需加载（省 token）。
abstract final class AiClassContext {
  static const _weekLabels = ['一', '二', '三', '四', '五', '六', '日'];

  /// Skill 式目录：只有 id / 描述 / 体积摘要，不含明细。
  static Future<String> buildCatalog(ClassController ctrl) async {
    await ctrl.ensureAllExamScores();
    final buf = StringBuffer();
    final cls = ctrl.currentClass;
    buf.writeln('班级：${cls?.displayTitle ?? '未选班级'}');
    buf.writeln(
      '时间：${DateFormat('yyyy-MM-dd HH:mm').format(DateTime.now())} · '
      '周${_weekLabels[DateTime.now().weekday - 1]}',
    );
    buf.writeln();
    buf.writeln('可用数据包（先选再加载；宁少勿多，最多 4 个）：');

    void line(AiDataPackId id, String description, String summary) {
      buf.writeln('- ${id.wire}');
      buf.writeln('  description: $description');
      buf.writeln('  summary: $summary');
    }

    final nStu = ctrl.students.length;
    line(
      AiDataPackId.students,
      '完整学生名单（学号/性别/积分/组/职务）。问具体学生档案时用。',
      '$nStu 人',
    );
    line(
      AiDataPackId.studentsCompact,
      '仅姓名列表，体积小。课表/留痕/对号入座时用。',
      '$nStu 人',
    );
    line(
      AiDataPackId.points,
      '积分 TOP10 + 现有加减分规则。问积分、或设计/整理加减分规则时用。',
      'TOP10 · 规则${ctrl.pointPresets.length}条',
    );
    line(
      AiDataPackId.attendance,
      '今日考勤汇总。问请假/迟到/缺勤/到校时用。',
      ctrl.selectedDate,
    );
    line(
      AiDataPackId.timetable,
      '本周班级课表摘要、今日课、我的授课。问课表/今天有哪些课时用。',
      '班级${ctrl.weekClassLessons.length}节 · 本人${ctrl.weekMyLessons.length}节',
    );

    final exams = [...ctrl.exams]
      ..sort((a, b) => b.examDate.compareTo(a.examDate));
    line(
      AiDataPackId.gradesOverview,
      '近几场考试摘要、总分前几、单科 Top、两场进步。问谁最高/进步/对比时用。',
      '${exams.length} 场',
    );

    final examLines = <String>[];
    for (final e in exams.take(8)) {
      final n = ctrl.rankedScores(e.id).length;
      examLines.add('${e.id}|${e.title}|${e.category}|${e.examDate}|已录$n人');
    }
    line(
      AiDataPackId.examBrief,
      '单场完整简报（统计+各科+前后名+偏低参考）。家长会/班会/深度解读时用；须同时选 examId。',
      examLines.isEmpty ? '无考试' : examLines.join(' ; '),
    );
    line(
      AiDataPackId.workLogs,
      '近期工作留痕。家长会家校沟通、家访、谈话素材时用。',
      '${ctrl.workLogs.length} 条',
    );
    line(
      AiDataPackId.todos,
      '未完成待办。问要做什么/提醒时用。',
      '${ctrl.todos.where((t) => !t.done).length} 条未完成',
    );

    return buf.toString();
  }

  /// 按选型加载正文。空选型返回空串。
  static Future<String> loadPacks(
    ClassController ctrl,
    AiPackSelection selection,
  ) async {
    if (selection.isEmpty) return '';
    await ctrl.ensureAllExamScores();

    final packs = [...selection.packs];
    // exam_brief 已够用时不必再塞完整名单；否则默认带 compact 姓名便于对号
    final hasNamePack = packs.contains(AiDataPackId.students) ||
        packs.contains(AiDataPackId.studentsCompact);
    if (!hasNamePack) {
      packs.insert(0, AiDataPackId.studentsCompact);
    }
    // 两个名单包同时选时只保留完整版
    if (packs.contains(AiDataPackId.students) &&
        packs.contains(AiDataPackId.studentsCompact)) {
      packs.remove(AiDataPackId.studentsCompact);
    }

    final buf = StringBuffer();
    final cls = ctrl.currentClass;
    buf.writeln('当前班级：${cls?.displayTitle ?? '未选班级'}');
    buf.writeln(
      '已加载：${packs.map((p) => p.wire).join(', ')}',
    );
    buf.writeln();

    for (final id in packs) {
      switch (id) {
        case AiDataPackId.students:
          _students(buf, ctrl, compact: false);
        case AiDataPackId.studentsCompact:
          _students(buf, ctrl, compact: true);
        case AiDataPackId.points:
          _points(buf, ctrl);
        case AiDataPackId.attendance:
          _attendance(buf, ctrl);
        case AiDataPackId.timetable:
          _timetable(buf, ctrl);
        case AiDataPackId.gradesOverview:
          await _gradesOverview(buf, ctrl);
        case AiDataPackId.examBrief:
          await _examBriefPack(buf, ctrl, selection.examId);
        case AiDataPackId.workLogs:
          _workLogs(buf, ctrl);
        case AiDataPackId.todos:
          _todos(buf, ctrl);
      }
    }

    var text = buf.toString();
    const maxChars = 18000;
    if (text.length > maxChars) {
      text = '${text.substring(0, maxChars)}\n…（数据过长已截断）';
    }
    return text;
  }

  /// 校验 exam_brief 的 examId：仅接受精确 id 或精确标题；对不上则去掉 exam_brief，避免误塞「最近一场」。
  static AiPackSelection resolveExamIdStrict(
    ClassController ctrl,
    AiPackSelection selection,
  ) {
    if (!selection.packs.contains(AiDataPackId.examBrief)) {
      return selection;
    }
    final exams = ctrl.exams;
    if (exams.isEmpty) {
      return AiPackSelection(
        packs: [
          for (final p in selection.packs)
            if (p != AiDataPackId.examBrief) p,
        ],
      );
    }

    final raw = selection.examId?.trim();
    if (raw == null || raw.isEmpty) {
      return _withoutExamBrief(selection);
    }
    if (ctrl.examById(raw) != null) return selection;
    for (final e in exams) {
      if (e.title == raw) {
        return AiPackSelection(packs: selection.packs, examId: e.id);
      }
    }
    return _withoutExamBrief(selection);
  }

  static AiPackSelection _withoutExamBrief(AiPackSelection selection) {
    final packs = [
      for (final p in selection.packs)
        if (p != AiDataPackId.examBrief) p,
    ];
    // 原想要单场简报但对不上时，改给成绩摘要（若尚未选）
    if (!packs.contains(AiDataPackId.gradesOverview)) {
      packs.add(AiDataPackId.gradesOverview);
    }
    return AiPackSelection(packs: packs.take(4).toList());
  }

  /// 单场考试精简素材（成绩页「AI 班会」等仍可直接调用）。
  static Future<String> buildExamBrief(
    ClassController ctrl,
    String examId,
  ) async {
    await ctrl.ensureExamScores(examId);
    final exam = ctrl.examById(examId);
    if (exam == null) return '（考试不存在）';

    final buf = StringBuffer();
    final cls = ctrl.currentClass;
    buf.writeln('班级：${cls?.displayTitle ?? '未选班级'}');
    buf.writeln('考试：${exam.title}');
    buf.writeln('类别：${exam.category} · 日期：${exam.examDate}');
    buf.writeln(
      '满分单科 ${exam.fullScore} · 及格线 ${exam.passScore} · 科目：${exam.subjects.join('、')}',
    );
    if (exam.note.isNotEmpty) buf.writeln('备注：${exam.note}');
    buf.writeln();

    final ranked = ctrl.rankedScores(examId);
    final stats = ctrl.analyzeExam(examId);
    buf.writeln('【统计】已录 ${ranked.length} 人');
    for (final s in stats) {
      if (s.count == 0) continue;
      buf.writeln(
        '- ${s.label}: 均分${_fmt(s.average)} 最高${_fmt(s.max)} 最低${_fmt(s.min)} '
        '及格率${(s.passRate * 100).toStringAsFixed(0)}%（${s.passCount}/${s.count}）',
      );
    }
    buf.writeln();

    buf.writeln('【总分前8】');
    for (var i = 0; i < ranked.length && i < 8; i++) {
      final sc = ranked[i];
      final name = ctrl.studentById(sc.studentId)?.name ?? '?';
      final detail = exam.subjects
          .map((sub) {
            final v = sc.scoreOf(sub);
            return v == null ? null : '$sub${_fmt(v)}';
          })
          .whereType<String>()
          .join(' ');
      buf.writeln('${i + 1}. $name 总分${_fmt(sc.total)} $detail');
    }
    buf.writeln();

    if (ranked.length > 8) {
      buf.writeln('【总分后5】');
      final tail = ranked.reversed.take(5).toList().reversed.toList();
      for (final sc in tail) {
        final name = ctrl.studentById(sc.studentId)?.name ?? '?';
        buf.writeln('- $name 总分${_fmt(sc.total)}');
      }
      buf.writeln();
    }

    for (final sub in exam.subjects.take(8)) {
      final pairs = <(String, double)>[];
      for (final sc in ranked) {
        final v = sc.scoreOf(sub);
        if (v == null) continue;
        final stu = ctrl.studentById(sc.studentId);
        if (stu == null) continue;
        pairs.add((stu.name, v));
      }
      if (pairs.length < 3) continue;
      pairs.sort((a, b) => a.$2.compareTo(b.$2));
      buf.writeln(
        '$sub 偏低参考: ${pairs.take(3).map((e) => '${e.$1}${_fmt(e.$2)}').join('、')}',
      );
    }

    var text = buf.toString();
    const maxChars = 12000;
    if (text.length > maxChars) {
      text = '${text.substring(0, maxChars)}\n…（已截断）';
    }
    return text;
  }

  static Future<void> _examBriefPack(
    StringBuffer buf,
    ClassController ctrl,
    String? examId,
  ) async {
    final sorted = [...ctrl.exams]
      ..sort((a, b) => b.examDate.compareTo(a.examDate));
    if (sorted.isEmpty) {
      buf.writeln('【考试简报】暂无考试数据。');
      buf.writeln();
      return;
    }

    Exam? pick;
    final raw = examId?.trim();
    if (raw == null || raw.isEmpty) {
      buf.writeln('【考试简报】未指定考试，无法生成单场简报。请说明考试名称后再问。');
      buf.writeln();
      return;
    }
    pick = ctrl.examById(raw);
    if (pick == null) {
      for (final e in sorted) {
        if (e.title == raw) {
          pick = e;
          break;
        }
      }
    }
    if (pick == null) {
      buf.writeln('【考试简报】找不到考试「$raw」。请核对名称或改用成绩摘要。');
      buf.writeln();
      return;
    }

    buf.writeln('【考试简报】');
    buf.writeln(await buildExamBrief(ctrl, pick.id));
  }

  static Future<void> _gradesOverview(
    StringBuffer buf,
    ClassController ctrl,
  ) async {
    buf.writeln('【考试与成绩】共 ${ctrl.exams.length} 场');
    final sorted = [...ctrl.exams]
      ..sort((a, b) => b.examDate.compareTo(a.examDate));
    for (final exam in sorted.take(5)) {
      buf.writeln('— ${exam.title}（${exam.category} ${exam.examDate}）');
      buf.writeln('  科目: ${exam.subjects.join('、')}');
      final ranked = ctrl.rankedScores(exam.id);
      if (ranked.isEmpty) {
        buf.writeln('  成绩: 未录入');
        continue;
      }
      buf.writeln('  已录 ${ranked.length} 人；总分前5:');
      for (final sc in ranked.take(5)) {
        final stu = ctrl.studentById(sc.studentId);
        final name = stu?.name ?? sc.studentId;
        final detail = exam.subjects
            .map((sub) {
              final v = sc.scoreOf(sub);
              return v == null ? null : '$sub${_fmt(v)}';
            })
            .whereType<String>()
            .join(' ');
        buf.writeln('  · $name 总分${_fmt(sc.total)} $detail');
      }
      for (final sub in exam.subjects.take(6)) {
        final pairs = <(String, double)>[];
        for (final sc in ranked) {
          final v = sc.scoreOf(sub);
          if (v == null) continue;
          final stu = ctrl.studentById(sc.studentId);
          if (stu == null) continue;
          pairs.add((stu.name, v));
        }
        pairs.sort((a, b) => b.$2.compareTo(a.$2));
        if (pairs.isEmpty) continue;
        buf.write('  $sub Top3: ');
        buf.writeln(
          pairs.take(3).map((e) => '${e.$1}${_fmt(e.$2)}').join('、'),
        );
      }
    }

    if (sorted.length >= 2) {
      final newer = sorted[0];
      final older = sorted[1];
      final common = newer.subjects.where(older.subjects.contains).toList();
      if (common.isNotEmpty) {
        buf.writeln('【成绩进步参考：${older.title} → ${newer.title}】');
        for (final sub in common.take(5)) {
          final deltas = <(String, double, double, double)>[];
          for (final s in ctrl.students) {
            final a = _score(ctrl, older.id, s.id, sub);
            final b = _score(ctrl, newer.id, s.id, sub);
            if (a == null || b == null) continue;
            deltas.add((s.name, a, b, b - a));
          }
          deltas.sort((x, y) => y.$4.compareTo(x.$4));
          if (deltas.isEmpty) continue;
          buf.writeln('$sub 进步最大 Top5:');
          for (final d in deltas.take(5)) {
            buf.writeln(
              '  · ${d.$1}: ${_fmt(d.$2)}→${_fmt(d.$3)}（${d.$4 >= 0 ? '+' : ''}${_fmt(d.$4)}）',
            );
          }
        }
      }
    }
    buf.writeln();
  }

  static void _students(
    StringBuffer buf,
    ClassController ctrl, {
    required bool compact,
  }) {
    buf.writeln('【学生名单】共 ${ctrl.students.length} 人');
    if (compact) {
      buf.writeln(ctrl.students.map((s) => s.name).join('、'));
      buf.writeln();
      return;
    }
    for (final s in ctrl.students) {
      final parts = <String>[
        s.name,
        if (s.studentNo.isNotEmpty) '学号${s.studentNo}',
        if (s.gender.isNotEmpty) s.gender,
        '积分${s.points}',
        if (s.groupName.isNotEmpty) '组:${s.groupName}',
        if (s.role.isNotEmpty) '职务:${s.role}',
      ];
      buf.writeln('- ${parts.join(' · ')}');
    }
    buf.writeln();
  }

  static void _points(StringBuffer buf, ClassController ctrl) {
    final top = [...ctrl.students]..sort((a, b) => b.points.compareTo(a.points));
    buf.writeln('【积分排行 TOP10】');
    for (final s in top.take(10)) {
      buf.writeln('- ${s.name}: ${s.points}');
    }
    buf.writeln('【现有加减分规则】共 ${ctrl.pointPresets.length} 条');
    if (ctrl.pointPresets.isEmpty) {
      buf.writeln('- （暂无自定义规则）');
    } else {
      for (final p in ctrl.pointPresets) {
        final sign = p.delta > 0 ? '+' : '';
        buf.writeln('- ${p.reason}: $sign${p.delta}');
      }
    }
    buf.writeln();
  }

  static void _attendance(StringBuffer buf, ClassController ctrl) {
    buf.writeln('【今日考勤 ${ctrl.selectedDate}】');
    final map = ctrl.attendanceMap;
    if (map.isEmpty) {
      buf.writeln('- 暂无记录');
    } else {
      final byStatus = <String, List<String>>{};
      for (final s in ctrl.students) {
        final st = map[s.id];
        if (st == null) continue;
        byStatus.putIfAbsent(st.label, () => []).add(s.name);
      }
      for (final e in byStatus.entries) {
        buf.writeln('- ${e.key}: ${e.value.join('、')}');
      }
    }
    buf.writeln();
  }

  static void _timetable(StringBuffer buf, ClassController ctrl) {
    final today = DateTime.now().weekday;
    buf.writeln('【本周班级课表摘要】');
    final classLessons = ctrl.weekClassLessons;
    if (classLessons.isEmpty) {
      buf.writeln('- 暂无班级课表');
    } else {
      for (final l in classLessons.take(80)) {
        buf.writeln(
          '- 周${_weekLabels[l.weekday - 1]} 第${l.period}节 ${l.subject}'
          '${l.classTitle.isEmpty ? '' : '（${l.classTitle}）'}',
        );
      }
    }
    buf.writeln('【今日班级课】');
    final todayClass = classLessons.where((l) => l.weekday == today).toList();
    if (todayClass.isEmpty) {
      buf.writeln('- 今日无课或未录入');
    } else {
      for (final l in todayClass) {
        buf.writeln('- 第${l.period}节 ${l.subject} ${l.timeRange}');
      }
    }
    buf.writeln('【本周我的授课】');
    final mine = ctrl.weekMyLessons;
    if (mine.isEmpty) {
      buf.writeln('- 暂无');
    } else {
      for (final l in mine.take(60)) {
        buf.writeln(
          '- 周${_weekLabels[l.weekday - 1]} 第${l.period}节 ${l.subject} @${l.classTitle}',
        );
      }
    }
    buf.writeln();
  }

  static double? _score(
    ClassController ctrl,
    String examId,
    String studentId,
    String subject,
  ) {
    for (final sc in ctrl.scoresOfExam(examId)) {
      if (sc.studentId == studentId) return sc.scoreOf(subject);
    }
    return null;
  }

  static void _workLogs(StringBuffer buf, ClassController ctrl) {
    final logs = [...ctrl.workLogs]
      ..sort((a, b) => b.date.compareTo(a.date));
    buf.writeln('【近期工作留痕】最近 ${logs.length > 8 ? 8 : logs.length} 条');
    for (final w in logs.take(8)) {
      final c = w.content.trim().replaceAll('\n', ' ');
      final brief = c.length > 60 ? '${c.substring(0, 60)}…' : c;
      buf.writeln('- ${w.date} [${w.category.label}] ${w.title} $brief');
    }
    buf.writeln();
  }

  static void _todos(StringBuffer buf, ClassController ctrl) {
    final open = ctrl.todos.where((t) => !t.done).toList();
    buf.writeln('【待办】未完成 ${open.length} 条');
    for (final t in open.take(20)) {
      buf.writeln('- ${t.title}');
    }
    buf.writeln();
  }

  static String _fmt(double v) =>
      v == v.roundToDouble() ? '${v.round()}' : v.toStringAsFixed(1);
}
