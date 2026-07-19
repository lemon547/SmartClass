import 'package:smart_class/models/models.dart';

/// 智能排座规则
enum SeatingRule {
  genderAlternate,
  studentNoOrder,
  scoreBackHigh,
}

extension SeatingRuleX on SeatingRule {
  String get label => switch (this) {
        SeatingRule.genderAlternate => '男女交叉（左右尽量异性）',
        SeatingRule.studentNoOrder => '按学号顺序填空',
        SeatingRule.scoreBackHigh => '最近考试高分靠后排',
      };
}

class SmartSeatingResult {
  const SmartSeatingResult({
    required this.seats,
    required this.conflictNotes,
  });

  final Map<String, (int row, int col)> seats;
  final List<String> conflictNotes;
}

/// 本地规则排座引擎（无身高字段）
abstract final class SmartSeating {
  static SmartSeatingResult arrange({
    required List<Student> students,
    required int rows,
    required int cols,
    required Set<SeatingRule> rules,
    Map<String, double>? latestTotals,
  }) {
    final notes = <String>[];
    if (students.isEmpty) {
      return const SmartSeatingResult(seats: {}, conflictNotes: ['没有学生可排座']);
    }
    final capacity = rows * cols;
    if (students.length > capacity) {
      notes.add('学生 ${students.length} 人超过座位 $capacity 个，超出部分不安排座位');
    }

    var ordered = List<Student>.from(students);

    if (rules.contains(SeatingRule.studentNoOrder)) {
      ordered.sort((a, b) {
        final an = a.studentNo;
        final bn = b.studentNo;
        if (an.isEmpty && bn.isEmpty) return a.name.compareTo(b.name);
        if (an.isEmpty) return 1;
        if (bn.isEmpty) return -1;
        final c = an.compareTo(bn);
        return c != 0 ? c : a.name.compareTo(b.name);
      });
    } else if (rules.contains(SeatingRule.scoreBackHigh) &&
        latestTotals != null &&
        latestTotals.isNotEmpty) {
      ordered.sort((a, b) {
        final at = latestTotals[a.id] ?? -1;
        final bt = latestTotals[b.id] ?? -1;
        final c = at.compareTo(bt); // 低分在前 → 填完后高分在后排
        return c != 0 ? c : a.name.compareTo(b.name);
      });
    } else {
      ordered.sort((a, b) => a.name.compareTo(b.name));
    }

    if (rules.contains(SeatingRule.scoreBackHigh) &&
        (latestTotals == null || latestTotals.isEmpty)) {
      notes.add('暂无考试成绩，已跳过「高分靠后排」');
    }

    if (rules.contains(SeatingRule.genderAlternate)) {
      final boys = ordered.where((s) => s.gender == '男').toList();
      final girls = ordered.where((s) => s.gender == '女').toList();
      final unknown =
          ordered.where((s) => s.gender != '男' && s.gender != '女').toList();
      if (boys.isEmpty || girls.isEmpty) {
        notes.add('男女比例失衡或性别未填，无法严格交叉，已按现有顺序排座');
      } else {
        ordered = _interleave(boys, girls)..addAll(unknown);
        // 检查同行相邻是否仍有同性（容量不够时）
        var sameAdj = 0;
        for (var i = 0; i < ordered.length && i < capacity - 1; i++) {
          if (i % cols == cols - 1) continue;
          final a = ordered[i].gender;
          final b = ordered[i + 1].gender;
          if ((a == '男' || a == '女') && a == b) sameAdj++;
        }
        if (sameAdj > 0) {
          notes.add('有 $sameAdj 处左右仍为同性（人数比限制），已尽量交叉');
        }
      }
    }

    final seats = <String, (int, int)>{};
    final n = ordered.length < capacity ? ordered.length : capacity;
    for (var i = 0; i < n; i++) {
      seats[ordered[i].id] = (i ~/ cols, i % cols);
    }
    return SmartSeatingResult(seats: seats, conflictNotes: notes);
  }

  static List<Student> _interleave(List<Student> a, List<Student> b) {
    final major = a.length >= b.length ? a : b;
    final minor = a.length >= b.length ? b : a;
    final out = <Student>[];
    var i = 0;
    var j = 0;
    while (i < major.length || j < minor.length) {
      if (i < major.length) out.add(major[i++]);
      if (j < minor.length) out.add(minor[j++]);
    }
    return out;
  }

  static String seatingChartText({
    required List<Student> students,
    required int rows,
    required int cols,
    String className = '',
  }) {
    Student? at(int r, int c) {
      for (final s in students) {
        if (s.seatRow == r && s.seatCol == c) return s;
      }
      return null;
    }

    final buf = StringBuffer();
    if (className.isNotEmpty) buf.writeln('$className 座位表');
    buf.writeln('（讲台朝向此方向）');
    buf.writeln('');
    for (var r = 0; r < rows; r++) {
      final cells = <String>[];
      for (var c = 0; c < cols; c++) {
        final s = at(r, c);
        cells.add(s?.name ?? '空');
      }
      buf.writeln(cells.join('\t'));
    }
    return buf.toString();
  }
}
