import 'package:intl/intl.dart';
import 'package:smart_class/models/models.dart';
import 'package:smart_class/providers/class_controller.dart';

/// 快照侧重点：按问题只塞相关块，150 人班也能少烧 token。
enum AiSnapshotFocus {
  all,
  timetable,
  grades,
  attendance,
  points,
  logs,
  todos,
}

/// 把本机班级数据压成文本快照，供懒羊羊机器人问答。
abstract final class AiClassContext {
  static const _weekLabels = ['一', '二', '三', '四', '五', '六', '日'];

  static AiSnapshotFocus focusForQuestion(String? question) {
    final q = (question ?? '').trim();
    if (q.isEmpty) return AiSnapshotFocus.all;

    bool any(List<String> keys) => keys.any(q.contains);

    if (any(['课表', '课程', '有哪些课', '今天有', '这周', '本周', '第几节'])) {
      return AiSnapshotFocus.timetable;
    }
    if (any(['成绩', '分数', '考试', '总分', '进步', '退步', '排名', '语文', '数学', '英语', '物理', '化学', '生物', '历史', '地理', '政治'])) {
      return AiSnapshotFocus.grades;
    }
    if (any(['考勤', '请假', '迟到', '缺勤', '到校'])) {
      return AiSnapshotFocus.attendance;
    }
    if (any(['积分', '加分', '扣分'])) {
      return AiSnapshotFocus.points;
    }
    if (any(['班会', '主题班会', '班会课', '班会议程', '班会提纲'])) {
      return AiSnapshotFocus.grades;
    }
    if (any(['留痕', '家访', '家长会', '谈话'])) {
      return AiSnapshotFocus.logs;
    }
    if (any(['待办', '要做', '提醒'])) {
      return AiSnapshotFocus.todos;
    }
    // 「谁/学生」等泛问：给全量（已截断）
    return AiSnapshotFocus.all;
  }

  /// 单场考试精简素材：供 AI 成绩解读 / 生成班会（控制 token）。
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

    // 各科后进几名，方便班会「帮扶」环节（不点名羞辱，AI 提示里再约束语气）
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

  static Future<String> buildSnapshot(
    ClassController ctrl, {
    String? question,
    AiSnapshotFocus? focus,
  }) async {
    await ctrl.ensureAllExamScores();
    final f = focus ?? focusForQuestion(question);
    final buf = StringBuffer();
    final cls = ctrl.currentClass;
    buf.writeln('当前班级：${cls?.displayTitle ?? '未选班级'}');
    buf.writeln('生成时间：${DateFormat('yyyy-MM-dd HH:mm').format(DateTime.now())}');
    buf.writeln('今日星期：周${_weekLabels[DateTime.now().weekday - 1]}');
    buf.writeln('快照范围：${_focusLabel(f)}');
    buf.writeln();

    // 名单精简版几乎总要（匹配人名）；全量仅在 all / points / grades 相关
    _students(buf, ctrl, compact: f == AiSnapshotFocus.timetable ||
        f == AiSnapshotFocus.logs ||
        f == AiSnapshotFocus.todos);

    if (f == AiSnapshotFocus.all || f == AiSnapshotFocus.points) {
      _points(buf, ctrl);
    }
    if (f == AiSnapshotFocus.all || f == AiSnapshotFocus.attendance) {
      _attendance(buf, ctrl);
    }
    if (f == AiSnapshotFocus.all || f == AiSnapshotFocus.timetable) {
      _timetable(buf, ctrl);
    }
    if (f == AiSnapshotFocus.all || f == AiSnapshotFocus.grades) {
      await _exams(buf, ctrl);
    }
    if (f == AiSnapshotFocus.all || f == AiSnapshotFocus.logs) {
      _workLogs(buf, ctrl);
    }
    if (f == AiSnapshotFocus.all || f == AiSnapshotFocus.todos) {
      _todos(buf, ctrl);
    }

    var text = buf.toString();
    // 控制 token：过长则截断尾部（150 人全量时更易触顶）
    final maxChars = f == AiSnapshotFocus.all ? 22000 : 16000;
    if (text.length > maxChars) {
      text = '${text.substring(0, maxChars)}\n…（数据过长已截断）';
    }
    return text;
  }

  static String _focusLabel(AiSnapshotFocus f) => switch (f) {
        AiSnapshotFocus.all => '综合',
        AiSnapshotFocus.timetable => '课表',
        AiSnapshotFocus.grades => '成绩',
        AiSnapshotFocus.attendance => '考勤',
        AiSnapshotFocus.points => '积分',
        AiSnapshotFocus.logs => '工作留痕',
        AiSnapshotFocus.todos => '待办',
      };

  static void _students(
    StringBuffer buf,
    ClassController ctrl, {
    required bool compact,
  }) {
    buf.writeln('【学生名单】共 ${ctrl.students.length} 人');
    if (compact) {
      // 只要姓名，方便课表/留痕类问题对上号
      final names = ctrl.students.map((s) => s.name).join('、');
      buf.writeln(names);
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

  static Future<void> _exams(StringBuffer buf, ClassController ctrl) async {
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
      // 单科分（便于「语文进步」类问题：给出最近两场对比素材）
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

    // 最近两场同科进步（若科目交集存在）
    if (sorted.length >= 2) {
      final newer = sorted[0];
      final older = sorted[1];
      final common = newer.subjects.where(older.subjects.contains).toList();
      if (common.isNotEmpty) {
        buf.writeln(
          '【成绩进步参考：${older.title} → ${newer.title}】',
        );
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
