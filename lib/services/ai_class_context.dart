import 'package:intl/intl.dart';
import 'package:smart_class/models/models.dart';
import 'package:smart_class/providers/class_controller.dart';

/// 班级/全库数据包（目录先描述 → AI 选型 → 再加载正文，省 token）。
/// 覆盖软件业务与数据库各表能力；目录必须齐全，加载按需。
enum AiDataPackId {
  students,
  studentsCompact,
  points,
  pointsHistory,
  attendance,
  leave,
  discipline,
  timetable,
  gradesOverview,
  examBrief,
  workLogs,
  todos,
  duty,
  homework,
  notes,
  funds,
  countdowns,
  rewards,
  settlements,
  seating,
  honors,
  lessons,
  semesters,
  rollHistory,
  titleMaterials,
  salary,
  classProfile,
}

extension AiDataPackIdX on AiDataPackId {
  String get wire => switch (this) {
        AiDataPackId.students => 'students',
        AiDataPackId.studentsCompact => 'students_compact',
        AiDataPackId.points => 'points',
        AiDataPackId.pointsHistory => 'points_history',
        AiDataPackId.attendance => 'attendance',
        AiDataPackId.leave => 'leave',
        AiDataPackId.discipline => 'discipline',
        AiDataPackId.timetable => 'timetable',
        AiDataPackId.gradesOverview => 'grades_overview',
        AiDataPackId.examBrief => 'exam_brief',
        AiDataPackId.workLogs => 'work_logs',
        AiDataPackId.todos => 'todos',
        AiDataPackId.duty => 'duty',
        AiDataPackId.homework => 'homework',
        AiDataPackId.notes => 'notes',
        AiDataPackId.funds => 'funds',
        AiDataPackId.countdowns => 'countdowns',
        AiDataPackId.rewards => 'rewards',
        AiDataPackId.settlements => 'settlements',
        AiDataPackId.seating => 'seating',
        AiDataPackId.honors => 'honors',
        AiDataPackId.lessons => 'lessons',
        AiDataPackId.semesters => 'semesters',
        AiDataPackId.rollHistory => 'roll_history',
        AiDataPackId.titleMaterials => 'title_materials',
        AiDataPackId.salary => 'salary',
        AiDataPackId.classProfile => 'class_profile',
      };

  String get shortLabel => switch (this) {
        AiDataPackId.students || AiDataPackId.studentsCompact => '名单',
        AiDataPackId.points || AiDataPackId.pointsHistory => '积分',
        AiDataPackId.attendance => '考勤',
        AiDataPackId.leave => '请假',
        AiDataPackId.discipline => '违纪',
        AiDataPackId.timetable => '课表',
        AiDataPackId.gradesOverview => '成绩摘要',
        AiDataPackId.examBrief => '考试简报',
        AiDataPackId.workLogs => '留痕',
        AiDataPackId.todos => '待办',
        AiDataPackId.duty => '值日',
        AiDataPackId.homework => '作业',
        AiDataPackId.notes => '班级备忘',
        AiDataPackId.funds => '班费',
        AiDataPackId.countdowns => '倒数日',
        AiDataPackId.rewards => '兑换',
        AiDataPackId.settlements => '积分结算',
        AiDataPackId.seating => '座位',
        AiDataPackId.honors => '荣誉',
        AiDataPackId.lessons => '教案进度',
        AiDataPackId.semesters => '学期',
        AiDataPackId.rollHistory => '点名',
        AiDataPackId.titleMaterials => '称号素材',
        AiDataPackId.salary => '工资台账',
        AiDataPackId.classProfile => '班级档案',
      };

  static AiDataPackId? tryParse(String raw) {
    final t = raw.trim().toLowerCase();
    for (final id in AiDataPackId.values) {
      if (id.wire == t) return id;
    }
    return null;
  }
}

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

/// 本机数据：轻量目录 → Agent 选型 → 按需加载。
abstract final class AiClassContext {
  static const _weekLabels = ['一', '二', '三', '四', '五', '六', '日'];
  static const maxPacks = 6;
  static const maxSnapshotChars = 22000;

  /// Skill 式目录：id / 描述 / 体积摘要，不含明细。
  /// [scopeClassIds] 为助手选中的班级范围（1 个、多个或全部）。
  static Future<String> buildCatalog(
    ClassController ctrl, {
    List<String>? scopeClassIds,
  }) async {
    final scope = _resolveScope(ctrl, scopeClassIds);
    final buf = StringBuffer();
    buf.writeln(
      '时间：${DateFormat('yyyy-MM-dd HH:mm').format(DateTime.now())} · '
      '周${_weekLabels[DateTime.now().weekday - 1]}',
    );
    buf.writeln('数据范围班级数：${scope.length}');
    buf.writeln('【班级索引 classes_index】（只读目录，不是数据包）');
    for (final c in ctrl.classes) {
      final mark = scope.contains(c.id) ? '✓范围内' : '○未选';
      buf.writeln(
        '- ${c.id}|${c.displayTitle}|${c.teacherRole.label}|'
        '${c.subject.isEmpty ? '—' : c.subject}|$mark',
      );
    }
    buf.writeln();

    // 目录摘要：单班用内存计数；多班只写能力说明（避免为摘要再切班）
    final single = scope.length == 1 ? scope.first : null;
    if (single != null && single == ctrl.currentClass?.id) {
      await ctrl.ensureAllExamScores();
      _writeCatalogLines(buf, ctrl, detailed: true);
    } else if (single != null) {
      await ctrl.withClassContext(single, () async {
        await ctrl.ensureAllExamScores();
        _writeCatalogLines(buf, ctrl, detailed: true);
      });
    } else {
      buf.writeln('说明：多班范围内，下列数据包会对「每个范围内班级」分别加载摘要。');
      _writeCatalogLines(buf, ctrl, detailed: false);
    }

    return buf.toString();
  }

  static void _writeCatalogLines(
    StringBuffer buf,
    ClassController ctrl, {
    required bool detailed,
  }) {
    buf.writeln('可用数据包（先选再加载；宁少勿多，最多 $maxPacks 个）：');

    void line(AiDataPackId id, String description, String summary) {
      buf.writeln('- ${id.wire}');
      buf.writeln('  description: $description');
      buf.writeln('  summary: $summary');
    }

    final nStu = detailed ? '${ctrl.students.length} 人' : '各班人数见加载后';
    line(
      AiDataPackId.students,
      '完整学生档案（学号/性别/积分/组/职务/电话/生日/备注/座位）。问具体学生时用。',
      nStu,
    );
    line(
      AiDataPackId.studentsCompact,
      '仅姓名列表，体积小。对号入座/课表点名时用。',
      nStu,
    );
    line(
      AiDataPackId.points,
      '积分 TOP10 + 加减分规则。问积分排行或设计规则时用。',
      detailed
          ? 'TOP10 · 规则${ctrl.pointPresets.length}条'
          : '各班排行+规则',
    );
    line(
      AiDataPackId.pointsHistory,
      '近期积分流水（加减分记录）。问谁加分/扣分明细时用。',
      detailed ? '${ctrl.pointRecords.length} 条' : '各班流水',
    );
    line(
      AiDataPackId.attendance,
      '今日考勤汇总。问到校/迟到/缺勤时用。',
      detailed ? ctrl.selectedDate : '各班今日',
    );
    line(
      AiDataPackId.leave,
      '请假台账（起止、状态、事由）。问请假/销假时用。',
      detailed ? '${ctrl.leaveRecords.length} 条' : '各班请假',
    );
    line(
      AiDataPackId.discipline,
      '违纪记录。问违纪/处分时用。',
      detailed ? '${ctrl.disciplineRecords.length} 条' : '各班违纪',
    );
    line(
      AiDataPackId.timetable,
      '本周班级课表、今日课、我的授课。问课表时用。',
      detailed
          ? '班级${ctrl.weekClassLessons.length}节 · 本人${ctrl.weekMyLessons.length}节'
          : '各班课表',
    );

    final exams = [...ctrl.exams]
      ..sort((a, b) => b.examDate.compareTo(a.examDate));
    line(
      AiDataPackId.gradesOverview,
      '近几场考试摘要、总分前几、单科 Top、进步对比。',
      detailed ? '${exams.length} 场' : '各班考试',
    );

    final examLines = <String>[];
    for (final e in exams.take(8)) {
      final n = ctrl.rankedScores(e.id).length;
      examLines.add('${e.id}|${e.title}|${e.category}|${e.examDate}|已录$n人');
    }
    line(
      AiDataPackId.examBrief,
      '单场完整简报。家长会/班会/深度解读时用；须填精确 examId。',
      examLines.isEmpty ? '无考试' : examLines.join(' ; '),
    );
    line(
      AiDataPackId.workLogs,
      '工作留痕（家访、谈话、家校沟通）。',
      detailed ? '${ctrl.workLogs.length} 条' : '各班留痕',
    );
    line(
      AiDataPackId.todos,
      '教师待办（未完成）。问今天做什么时用。',
      detailed
          ? '${ctrl.todos.where((t) => !t.done).length} 条未完成'
          : '各班待办',
    );
    line(
      AiDataPackId.duty,
      '值日安排。',
      detailed ? '${ctrl.dutyList.length} 条' : '各班值日',
    );
    line(
      AiDataPackId.homework,
      '当日/近期作业。',
      detailed ? '${ctrl.homework.length} 条' : '各班作业',
    );
    line(
      AiDataPackId.notes,
      '班级备忘/便签。',
      detailed ? '${ctrl.notes.length} 条' : '各班备忘',
    );
    line(
      AiDataPackId.funds,
      '班费收支。',
      detailed ? '${ctrl.fundRecords.length} 条' : '各班班费',
    );
    line(
      AiDataPackId.countdowns,
      '倒数日/重要日程。',
      detailed ? '${ctrl.countdowns.length} 条' : '各班倒数日',
    );
    line(
      AiDataPackId.rewards,
      '积分兑换奖品。',
      detailed ? '${ctrl.rewards.length} 项' : '各班兑换',
    );
    line(
      AiDataPackId.settlements,
      '积分结算历史。',
      detailed ? '${ctrl.settlements.length} 次' : '各班结算',
    );
    line(
      AiDataPackId.seating,
      '座位表（行列与学生）。问座位/排座时用。',
      detailed
          ? '${ctrl.profile.seatRows}x${ctrl.profile.seatCols}'
          : '各班座位',
    );
    line(
      AiDataPackId.honors,
      '学生荣誉摘要。',
      detailed ? '按学生拉取' : '各班荣誉',
    );
    line(
      AiDataPackId.lessons,
      '教案/课题进度与单元。',
      detailed ? '${ctrl.lessonUnits.length} 单元' : '各班教案',
    );
    line(
      AiDataPackId.semesters,
      '学期列表与当前学期。',
      detailed ? '${ctrl.semesters.length} 个' : '各班学期',
    );
    line(
      AiDataPackId.rollHistory,
      '随机点名历史。',
      detailed ? '${ctrl.rollHistory.length} 条' : '各班点名',
    );
    line(
      AiDataPackId.titleMaterials,
      '称号/头衔素材库。',
      detailed ? '${ctrl.titleMaterials.length} 项' : '各班素材',
    );
    line(
      AiDataPackId.salary,
      '教师工资台账（个人，不按班拆分）。',
      detailed ? '${ctrl.salaryRecords.length} 条' : '个人台账',
    );
    line(
      AiDataPackId.classProfile,
      '班级档案：校名年级座位尺寸角色科目功能开关。',
      detailed ? (ctrl.currentClass?.displayTitle ?? '—') : '范围内各班档案',
    );
  }

  static List<String> _resolveScope(
    ClassController ctrl,
    List<String>? scopeClassIds,
  ) {
    if (scopeClassIds != null && scopeClassIds.isNotEmpty) {
      final known = {for (final c in ctrl.classes) c.id};
      return [
        for (final id in scopeClassIds)
          if (known.contains(id)) id,
      ];
    }
    final cur = ctrl.currentClass?.id;
    if (cur != null && cur.isNotEmpty) return [cur];
    return [for (final c in ctrl.classes) c.id];
  }

  /// 对范围内每个班加载选型正文并拼接。
  static Future<String> loadPacks(
    ClassController ctrl,
    AiPackSelection selection, {
    List<String>? scopeClassIds,
  }) async {
    if (selection.isEmpty) return '';
    final scope = _resolveScope(ctrl, scopeClassIds);
    if (scope.isEmpty) return '';

    final parts = <String>[];
    for (final classId in scope) {
      final chunk = await ctrl.withClassContext(classId, () async {
        return _loadPacksForCurrent(ctrl, selection);
      });
      if (chunk.trim().isEmpty) continue;
      var title = classId;
      for (final c in ctrl.classes) {
        if (c.id == classId) {
          title = c.displayTitle;
          break;
        }
      }
      parts.add('======== 班级：$title ($classId) ========\n$chunk');
    }

    // salary 是个人级：只附一次
    if (selection.packs.contains(AiDataPackId.salary)) {
      final buf = StringBuffer();
      _salary(buf, ctrl);
      parts.add(buf.toString());
    }

    var text = parts.join('\n');
    if (text.length > maxSnapshotChars) {
      text = '${text.substring(0, maxSnapshotChars)}\n…（数据过长已截断）';
    }
    return text;
  }

  static Future<String> _loadPacksForCurrent(
    ClassController ctrl,
    AiPackSelection selection,
  ) async {
    await ctrl.ensureAllExamScores();
    if (ctrl.titleMaterials.isEmpty) {
      await ctrl.refreshTitleMaterials();
    }

    final packs = [...selection.packs]
      ..remove(AiDataPackId.salary); // 个人级外置
    final hasNamePack = packs.contains(AiDataPackId.students) ||
        packs.contains(AiDataPackId.studentsCompact);
    if (!hasNamePack && packs.isNotEmpty) {
      packs.insert(0, AiDataPackId.studentsCompact);
    }
    if (packs.contains(AiDataPackId.students) &&
        packs.contains(AiDataPackId.studentsCompact)) {
      packs.remove(AiDataPackId.studentsCompact);
    }

    final buf = StringBuffer();
    final cls = ctrl.currentClass;
    buf.writeln('班级：${cls?.displayTitle ?? '未选班级'}');
    buf.writeln('已加载：${packs.map((p) => p.wire).join(', ')}');
    buf.writeln();

    for (final id in packs) {
      switch (id) {
        case AiDataPackId.students:
          _students(buf, ctrl, compact: false);
        case AiDataPackId.studentsCompact:
          _students(buf, ctrl, compact: true);
        case AiDataPackId.points:
          _points(buf, ctrl);
        case AiDataPackId.pointsHistory:
          _pointsHistory(buf, ctrl);
        case AiDataPackId.attendance:
          _attendance(buf, ctrl);
        case AiDataPackId.leave:
          _leave(buf, ctrl);
        case AiDataPackId.discipline:
          _discipline(buf, ctrl);
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
        case AiDataPackId.duty:
          _duty(buf, ctrl);
        case AiDataPackId.homework:
          _homework(buf, ctrl);
        case AiDataPackId.notes:
          _notes(buf, ctrl);
        case AiDataPackId.funds:
          _funds(buf, ctrl);
        case AiDataPackId.countdowns:
          _countdowns(buf, ctrl);
        case AiDataPackId.rewards:
          _rewards(buf, ctrl);
        case AiDataPackId.settlements:
          _settlements(buf, ctrl);
        case AiDataPackId.seating:
          _seating(buf, ctrl);
        case AiDataPackId.honors:
          await _honors(buf, ctrl);
        case AiDataPackId.lessons:
          _lessons(buf, ctrl);
        case AiDataPackId.semesters:
          _semesters(buf, ctrl);
        case AiDataPackId.rollHistory:
          _rollHistory(buf, ctrl);
        case AiDataPackId.titleMaterials:
          _titleMaterials(buf, ctrl);
        case AiDataPackId.classProfile:
          _classProfile(buf, ctrl);
        case AiDataPackId.salary:
          break;
      }
    }
    return buf.toString();
  }

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
    if (!packs.contains(AiDataPackId.gradesOverview)) {
      packs.add(AiDataPackId.gradesOverview);
    }
    return AiPackSelection(packs: packs.take(maxPacks).toList());
  }

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
    if (text.length > 12000) {
      text = '${text.substring(0, 12000)}\n…（已截断）';
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
        if (s.phone.isNotEmpty) '电话:${s.phone}',
        if (s.birthday.isNotEmpty) '生日:${s.birthday}',
        if (s.seatRow != null &&
            s.seatCol != null &&
            s.seatRow! > 0 &&
            s.seatCol! > 0)
          '座位:${s.seatRow}排${s.seatCol}列',
        if (s.note.isNotEmpty) '备注:${s.note}',
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

  static void _pointsHistory(StringBuffer buf, ClassController ctrl) {
    final rows = [...ctrl.pointRecords]
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    buf.writeln('【积分流水】最近 ${rows.length > 30 ? 30 : rows.length} 条');
    for (final r in rows.take(30)) {
      final name = ctrl.studentById(r.studentId)?.name ?? '?';
      final sign = r.delta > 0 ? '+' : '';
      buf.writeln(
        '- ${DateFormat('MM-dd HH:mm').format(r.createdAt)} $name '
        '$sign${r.delta}（${r.reason}）',
      );
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

  static void _leave(StringBuffer buf, ClassController ctrl) {
    final rows = [...ctrl.leaveRecords]
      ..sort((a, b) => b.startAt.compareTo(a.startAt));
    buf.writeln('【请假】共 ${rows.length} 条（最近 20）');
    for (final r in rows.take(20)) {
      final name = ctrl.studentById(r.studentId)?.name ?? '?';
      buf.writeln(
        '- $name ${r.status.label} ${r.startAt}~${r.endAt} ${r.reason}',
      );
    }
    buf.writeln();
  }

  static void _discipline(StringBuffer buf, ClassController ctrl) {
    final rows = [...ctrl.disciplineRecords]
      ..sort((a, b) => b.date.compareTo(a.date));
    buf.writeln('【违纪】共 ${rows.length} 条（最近 20）');
    for (final r in rows.take(20)) {
      final name = ctrl.studentById(r.studentId)?.name ?? '?';
      buf.writeln('- ${r.date} $name ${r.title} ${r.action}');
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

  static void _workLogs(StringBuffer buf, ClassController ctrl) {
    final logs = [...ctrl.workLogs]..sort((a, b) => b.date.compareTo(a.date));
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

  static void _duty(StringBuffer buf, ClassController ctrl) {
    buf.writeln('【值日】${ctrl.dutyList.length} 条');
    for (final d in ctrl.dutyList.take(40)) {
      final name = ctrl.studentById(d.studentId)?.name ?? '?';
      buf.writeln('- 周${_weekLabels[(d.weekday - 1).clamp(0, 6)]} $name ${d.task}');
    }
    buf.writeln();
  }

  static void _homework(StringBuffer buf, ClassController ctrl) {
    buf.writeln('【作业】${ctrl.homework.length} 条（日期 ${ctrl.selectedDate}）');
    for (final h in ctrl.homework.take(20)) {
      buf.writeln('- ${h.date} ${h.title}');
    }
    buf.writeln();
  }

  static void _notes(StringBuffer buf, ClassController ctrl) {
    buf.writeln('【班级备忘】${ctrl.notes.length} 条');
    for (final n in ctrl.notes.take(15)) {
      final c = n.content.trim().replaceAll('\n', ' ');
      final brief = c.length > 80 ? '${c.substring(0, 80)}…' : c;
      buf.writeln('- ${n.title} $brief');
    }
    buf.writeln();
  }

  static void _funds(StringBuffer buf, ClassController ctrl) {
    buf.writeln('【班费】${ctrl.fundRecords.length} 条（最近 20）');
    for (final f in ctrl.fundRecords.take(20)) {
      final sign = f.amount >= 0 ? '+' : '';
      buf.writeln('- ${f.date} $sign${f.amount} ${f.title} ${f.note}');
    }
    buf.writeln();
  }

  static void _countdowns(StringBuffer buf, ClassController ctrl) {
    buf.writeln('【倒数日】${ctrl.countdowns.length} 条');
    for (final c in ctrl.countdowns.take(15)) {
      buf.writeln('- ${c.title} ${c.targetDate}（剩${c.daysLeft}天）');
    }
    buf.writeln();
  }

  static void _rewards(StringBuffer buf, ClassController ctrl) {
    buf.writeln('【兑换奖品】${ctrl.rewards.length} 项');
    for (final r in ctrl.rewards.take(20)) {
      buf.writeln('- ${r.name} 需${r.cost}分 库存${r.stock}');
    }
    buf.writeln();
  }

  static void _settlements(StringBuffer buf, ClassController ctrl) {
    buf.writeln('【积分结算】${ctrl.settlements.length} 次');
    for (final s in ctrl.settlements.take(10)) {
      buf.writeln('- ${s.createdAt} ${s.name}');
    }
    buf.writeln();
  }

  static void _seating(StringBuffer buf, ClassController ctrl) {
    final rows = ctrl.profile.seatRows;
    final cols = ctrl.profile.seatCols;
    buf.writeln('【座位表】$rows行×$cols列');
    final seated = ctrl.students
        .where((s) {
          final r = s.seatRow;
          final c = s.seatCol;
          return r != null && c != null && r > 0 && c > 0;
        })
        .toList()
      ..sort((a, b) {
        final c = a.seatRow!.compareTo(b.seatRow!);
        return c != 0 ? c : a.seatCol!.compareTo(b.seatCol!);
      });
    for (final s in seated.take(80)) {
      buf.writeln('- ${s.seatRow}排${s.seatCol}列 ${s.name}');
    }
    final unset = ctrl.students
        .where((s) => s.seatRow == null || s.seatRow! <= 0)
        .length;
    if (unset > 0) buf.writeln('- 未排座 $unset 人');
    buf.writeln();
  }

  static Future<void> _honors(StringBuffer buf, ClassController ctrl) async {
    buf.writeln('【荣誉】摘要（每生最多 3 条）');
    var n = 0;
    for (final s in ctrl.students.take(40)) {
      final list = await ctrl.honorsOf(s.id);
      if (list.isEmpty) continue;
      n++;
      buf.writeln(
        '- ${s.name}: ${list.take(3).map((h) => '${h.title}(${h.date})').join('、')}',
      );
      if (n >= 25) break;
    }
    if (n == 0) buf.writeln('- 暂无荣誉记录');
    buf.writeln();
  }

  static void _lessons(StringBuffer buf, ClassController ctrl) {
    buf.writeln('【教案/课题】${ctrl.lessonUnits.length} 单元');
    for (final u in ctrl.lessonUnits.take(20)) {
      buf.writeln('- ${u.subject} ${u.title} ${u.progressNote}');
    }
    buf.writeln();
  }

  static void _semesters(StringBuffer buf, ClassController ctrl) {
    buf.writeln('【学期】${ctrl.semesters.length} 个');
    for (final s in ctrl.semesters) {
      final mark = s.id == ctrl.activeSemester?.id ? '（当前）' : '';
      buf.writeln('- ${s.title} ${s.startDate}~${s.endDate}$mark');
    }
    buf.writeln();
  }

  static void _rollHistory(StringBuffer buf, ClassController ctrl) {
    buf.writeln('【点名历史】${ctrl.rollHistory.length} 条（最近 15）');
    for (final r in ctrl.rollHistory.take(15)) {
      buf.writeln('- $r');
    }
    buf.writeln();
  }

  static void _titleMaterials(StringBuffer buf, ClassController ctrl) {
    buf.writeln('【称号素材】${ctrl.titleMaterials.length} 项');
    for (final t in ctrl.titleMaterials.take(20)) {
      buf.writeln('- ${t.title} ${t.category}');
    }
    buf.writeln();
  }

  static void _salary(StringBuffer buf, ClassController ctrl) {
    buf.writeln('【工资台账·个人】${ctrl.salaryRecords.length} 条（最近 12）');
    for (final s in ctrl.salaryRecords.take(12)) {
      buf.writeln('- ${s.yearMonth} 实发${s.netAmount} ${s.note}');
    }
    buf.writeln();
  }

  static void _classProfile(StringBuffer buf, ClassController ctrl) {
    final c = ctrl.currentClass;
    buf.writeln('【班级档案】');
    if (c == null) {
      buf.writeln('- 未选班级');
    } else {
      buf.writeln('- 名称：${c.displayTitle}');
      buf.writeln('- 学校：${c.school.isEmpty ? '—' : c.school}');
      buf.writeln('- 角色：${c.teacherRole.label}');
      buf.writeln('- 任教：${c.subject.isEmpty ? '—' : c.subject}');
      buf.writeln('- 座位：${c.seatRows}x${c.seatCols}');
      buf.writeln('- 功能开关：${c.featureFlags}');
    }
    buf.writeln();
  }

  static String _fmt(double v) =>
      v == v.roundToDouble() ? '${v.round()}' : v.toStringAsFixed(1);
}
