class Student {
  final String id;
  final String name;
  final String studentNo;
  final String gender;
  final String phone;
  final String note;
  final String groupName;
  /// 班委角色：班长 / 组长 等，空为普通学生（参考 smart-roll-call）
  final String role;
  /// 生日，格式 MM-dd（参考班主任管理大师生日提醒）
  final String birthday;
  final int points;
  final int? seatRow;
  final int? seatCol;
  final DateTime createdAt;

  const Student({
    required this.id,
    required this.name,
    this.studentNo = '',
    this.gender = '未知',
    this.phone = '',
    this.note = '',
    this.groupName = '',
    this.role = '',
    this.birthday = '',
    this.points = 0,
    this.seatRow,
    this.seatCol,
    required this.createdAt,
  });

  Student copyWith({
    String? id,
    String? name,
    String? studentNo,
    String? gender,
    String? phone,
    String? note,
    String? groupName,
    String? role,
    String? birthday,
    int? points,
    int? seatRow,
    int? seatCol,
    bool clearSeat = false,
    DateTime? createdAt,
  }) {
    return Student(
      id: id ?? this.id,
      name: name ?? this.name,
      studentNo: studentNo ?? this.studentNo,
      gender: gender ?? this.gender,
      phone: phone ?? this.phone,
      note: note ?? this.note,
      groupName: groupName ?? this.groupName,
      role: role ?? this.role,
      birthday: birthday ?? this.birthday,
      points: points ?? this.points,
      seatRow: clearSeat ? null : (seatRow ?? this.seatRow),
      seatCol: clearSeat ? null : (seatCol ?? this.seatCol),
      createdAt: createdAt ?? this.createdAt,
    );
  }

  Map<String, Object?> toMap() => {
        'id': id,
        'name': name,
        'student_no': studentNo,
        'gender': gender,
        'phone': phone,
        'note': note,
        'group_name': groupName,
        'role': role,
        'birthday': birthday,
        'points': points,
        'seat_row': seatRow,
        'seat_col': seatCol,
        'created_at': createdAt.toIso8601String(),
      };

  factory Student.fromMap(Map<String, Object?> map) => Student(
        id: map['id']! as String,
        name: map['name']! as String,
        studentNo: (map['student_no'] as String?) ?? '',
        gender: (map['gender'] as String?) ?? '未知',
        phone: (map['phone'] as String?) ?? '',
        note: (map['note'] as String?) ?? '',
        groupName: (map['group_name'] as String?) ?? '',
        role: (map['role'] as String?) ?? '',
        birthday: (map['birthday'] as String?) ?? '',
        points: (map['points'] as int?) ?? 0,
        seatRow: map['seat_row'] as int?,
        seatCol: map['seat_col'] as int?,
        createdAt: DateTime.parse(map['created_at']! as String),
      );

  /// 今天是否生日（按月-日）
  bool get isBirthdayToday {
    final md = _monthDay;
    if (md == null) return false;
    final n = DateTime.now();
    return md.$1 == n.month && md.$2 == n.day;
  }

  /// 距下次生日的天数；无生日返回 null
  int? get daysUntilBirthday {
    final md = _monthDay;
    if (md == null) return null;
    final n = DateTime.now();
    var next = DateTime(n.year, md.$1, md.$2);
    if (next.isBefore(DateTime(n.year, n.month, n.day))) {
      next = DateTime(n.year + 1, md.$1, md.$2);
    }
    return next.difference(DateTime(n.year, n.month, n.day)).inDays;
  }

  (int, int)? get _monthDay {
    final t = birthday.trim();
    if (t.isEmpty) return null;
    final parts = t.split('-');
    if (parts.length == 2) {
      final m = int.tryParse(parts[0]);
      final d = int.tryParse(parts[1]);
      if (m != null && d != null) return (m, d);
    }
    if (parts.length == 3) {
      final m = int.tryParse(parts[1]);
      final d = int.tryParse(parts[2]);
      if (m != null && d != null) return (m, d);
    }
    return null;
  }
}

enum AttendanceStatus { present, late, leave, absent }

extension AttendanceStatusX on AttendanceStatus {
  String get label => switch (this) {
        AttendanceStatus.present => '出勤',
        AttendanceStatus.late => '迟到',
        AttendanceStatus.leave => '请假',
        AttendanceStatus.absent => '缺勤',
      };

  static AttendanceStatus fromName(String name) =>
      AttendanceStatus.values.firstWhere(
        (e) => e.name == name,
        orElse: () => AttendanceStatus.present,
      );
}

class AttendanceRecord {
  final String id;
  final String studentId;
  final String date;
  final AttendanceStatus status;
  final String remark;

  const AttendanceRecord({
    required this.id,
    required this.studentId,
    required this.date,
    required this.status,
    this.remark = '',
  });

  Map<String, Object?> toMap() => {
        'id': id,
        'student_id': studentId,
        'date': date,
        'status': status.name,
        'remark': remark,
      };

  factory AttendanceRecord.fromMap(Map<String, Object?> map) =>
      AttendanceRecord(
        id: map['id']! as String,
        studentId: map['student_id']! as String,
        date: map['date']! as String,
        status: AttendanceStatusX.fromName(map['status']! as String),
        remark: (map['remark'] as String?) ?? '',
      );
}

class PointRecord {
  final String id;
  final String studentId;
  final int delta;
  final String reason;
  final DateTime createdAt;

  const PointRecord({
    required this.id,
    required this.studentId,
    required this.delta,
    required this.reason,
    required this.createdAt,
  });

  Map<String, Object?> toMap() => {
        'id': id,
        'student_id': studentId,
        'delta': delta,
        'reason': reason,
        'created_at': createdAt.toIso8601String(),
      };

  factory PointRecord.fromMap(Map<String, Object?> map) => PointRecord(
        id: map['id']! as String,
        studentId: map['student_id']! as String,
        delta: map['delta']! as int,
        reason: map['reason']! as String,
        createdAt: DateTime.parse(map['created_at']! as String),
      );
}

class DutyAssignment {
  final String id;
  final int weekday;
  final String studentId;
  final String task;

  const DutyAssignment({
    required this.id,
    required this.weekday,
    required this.studentId,
    this.task = '值日',
  });

  Map<String, Object?> toMap() => {
        'id': id,
        'weekday': weekday,
        'student_id': studentId,
        'task': task,
      };

  factory DutyAssignment.fromMap(Map<String, Object?> map) => DutyAssignment(
        id: map['id']! as String,
        weekday: map['weekday']! as int,
        studentId: map['student_id']! as String,
        task: (map['task'] as String?) ?? '值日',
      );
}

class ClassProfile {
  final String name;
  final String grade;
  final int seatRows;
  final int seatCols;

  const ClassProfile({
    this.name = '高一（1）班',
    this.grade = '高一',
    this.seatRows = 6,
    this.seatCols = 8,
  });

  ClassProfile copyWith({
    String? name,
    String? grade,
    int? seatRows,
    int? seatCols,
  }) {
    return ClassProfile(
      name: name ?? this.name,
      grade: grade ?? this.grade,
      seatRows: seatRows ?? this.seatRows,
      seatCols: seatCols ?? this.seatCols,
    );
  }
}

class ClassNote {
  final String id;
  final String title;
  final String content;
  final DateTime createdAt;

  const ClassNote({
    required this.id,
    required this.title,
    required this.content,
    required this.createdAt,
  });

  Map<String, Object?> toMap() => {
        'id': id,
        'title': title,
        'content': content,
        'created_at': createdAt.toIso8601String(),
      };

  factory ClassNote.fromMap(Map<String, Object?> map) => ClassNote(
        id: map['id']! as String,
        title: map['title']! as String,
        content: (map['content'] as String?) ?? '',
        createdAt: DateTime.parse(map['created_at']! as String),
      );
}

class HomeworkItem {
  final String id;
  final String title;
  final String date;
  final String doneIds; // comma-separated student ids

  const HomeworkItem({
    required this.id,
    required this.title,
    required this.date,
    this.doneIds = '',
  });

  Set<String> get doneSet =>
      doneIds.isEmpty ? <String>{} : doneIds.split(',').toSet();

  Map<String, Object?> toMap() => {
        'id': id,
        'title': title,
        'date': date,
        'done_ids': doneIds,
      };

  factory HomeworkItem.fromMap(Map<String, Object?> map) => HomeworkItem(
        id: map['id']! as String,
        title: map['title']! as String,
        date: map['date']! as String,
        doneIds: (map['done_ids'] as String?) ?? '',
      );
}

class RewardItem {
  final String id;
  final String name;
  final int cost;
  final int stock;

  const RewardItem({
    required this.id,
    required this.name,
    required this.cost,
    this.stock = 99,
  });

  Map<String, Object?> toMap() => {
        'id': id,
        'name': name,
        'cost': cost,
        'stock': stock,
      };

  factory RewardItem.fromMap(Map<String, Object?> map) => RewardItem(
        id: map['id']! as String,
        name: map['name']! as String,
        cost: map['cost']! as int,
        stock: (map['stock'] as int?) ?? 99,
      );
}

class TimetableSlot {
  final String id;
  final int weekday; // 1-7
  final int period; // 1-8
  final String subject;

  const TimetableSlot({
    required this.id,
    required this.weekday,
    required this.period,
    required this.subject,
  });

  Map<String, Object?> toMap() => {
        'id': id,
        'weekday': weekday,
        'period': period,
        'subject': subject,
      };

  factory TimetableSlot.fromMap(Map<String, Object?> map) => TimetableSlot(
        id: map['id']! as String,
        weekday: map['weekday']! as int,
        period: map['period']! as int,
        subject: (map['subject'] as String?) ?? '',
      );
}

class PointReasonPreset {
  final String reason;
  final int delta;

  const PointReasonPreset({required this.reason, required this.delta});

  Map<String, dynamic> toJson() => {'reason': reason, 'delta': delta};

  factory PointReasonPreset.fromJson(Map<String, dynamic> json) =>
      PointReasonPreset(
        reason: json['reason'] as String? ?? '',
        delta: (json['delta'] as num?)?.toInt() ?? 1,
      );
}

class Settlement {
  final String id;
  final String name;
  final DateTime createdAt;
  final String snapshot; // JSON

  const Settlement({
    required this.id,
    required this.name,
    required this.createdAt,
    required this.snapshot,
  });

  Map<String, Object?> toMap() => {
        'id': id,
        'name': name,
        'created_at': createdAt.toIso8601String(),
        'snapshot': snapshot,
      };

  factory Settlement.fromMap(Map<String, Object?> map) => Settlement(
        id: map['id']! as String,
        name: map['name']! as String,
        createdAt: DateTime.parse(map['created_at']! as String),
        snapshot: map['snapshot']! as String,
      );
}

/// 参考 classMaster 段位：按累计积分显示称号
String rankTitle(int points) {
  if (points >= 200) return '传奇';
  if (points >= 150) return '钻石';
  if (points >= 100) return '铂金';
  if (points >= 70) return '黄金';
  if (points >= 40) return '白银';
  if (points >= 20) return '青铜';
  return '新芽';
}

/// 倒数日（参考班小二等班主任工具）
class CountdownItem {
  final String id;
  final String title;
  final String targetDate; // yyyy-MM-dd
  final DateTime createdAt;

  const CountdownItem({
    required this.id,
    required this.title,
    required this.targetDate,
    required this.createdAt,
  });

  int get daysLeft {
    final t = DateTime.tryParse(targetDate);
    if (t == null) return 0;
    final n = DateTime.now();
    final today = DateTime(n.year, n.month, n.day);
    final target = DateTime(t.year, t.month, t.day);
    return target.difference(today).inDays;
  }

  Map<String, Object?> toMap() => {
        'id': id,
        'title': title,
        'target_date': targetDate,
        'created_at': createdAt.toIso8601String(),
      };

  factory CountdownItem.fromMap(Map<String, Object?> map) => CountdownItem(
        id: map['id']! as String,
        title: map['title']! as String,
        targetDate: map['target_date']! as String,
        createdAt: DateTime.parse(map['created_at']! as String),
      );
}

/// 班费收支（参考班主任管理大师）
class FundRecord {
  final String id;
  final String title;
  final int amount; // 正=收入，负=支出，单位分或元按整数记
  final String date; // yyyy-MM-dd
  final String note;
  final DateTime createdAt;

  const FundRecord({
    required this.id,
    required this.title,
    required this.amount,
    required this.date,
    this.note = '',
    required this.createdAt,
  });

  Map<String, Object?> toMap() => {
        'id': id,
        'title': title,
        'amount': amount,
        'date': date,
        'note': note,
        'created_at': createdAt.toIso8601String(),
      };

  factory FundRecord.fromMap(Map<String, Object?> map) => FundRecord(
        id: map['id']! as String,
        title: map['title']! as String,
        amount: map['amount']! as int,
        date: map['date']! as String,
        note: (map['note'] as String?) ?? '',
        createdAt: DateTime.parse(map['created_at']! as String),
      );
}
