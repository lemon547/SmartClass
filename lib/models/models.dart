import 'dart:convert';

class Student {
  final String id;
  final String name;
  final String studentNo;
  final String gender;
  final String phone;
  final String note;
  final String groupName;
  /// 班委角色，多个用顿号连接，如「班长、学习委员」；空为普通学生
  final String role;
  /// 生日，格式 MM-dd（参考班主任管理大师生日提醒）
  final String birthday;
  /// 家庭住址
  final String address;
  final int points;
  final int? seatRow;
  final int? seatCol;
  final DateTime createdAt;

  const Student({
    required this.id,
    required this.name,
    this.studentNo = '',
    this.gender = '',
    this.phone = '',
    this.note = '',
    this.groupName = '',
    this.role = '',
    this.birthday = '',
    this.address = '',
    this.points = 0,
    this.seatRow,
    this.seatCol,
    required this.createdAt,
  });

  static List<String> splitRoles(String raw) {
    if (raw.trim().isEmpty) return [];
    return raw
        .split(RegExp(r'[,，、/|]'))
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();
  }

  static String joinRoles(Iterable<String> roles) {
    final seen = <String>{};
    final out = <String>[];
    for (final r in roles) {
      final t = r.trim();
      if (t.isEmpty || seen.contains(t)) continue;
      seen.add(t);
      out.add(t);
    }
    return out.join('、');
  }

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
    String? address,
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
      address: address ?? this.address,
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
        'address': address,
        'points': points,
        'seat_row': seatRow,
        'seat_col': seatCol,
        'created_at': createdAt.toIso8601String(),
      };

  factory Student.fromMap(Map<String, Object?> map) => Student(
        id: map['id']! as String,
        name: map['name']! as String,
        studentNo: (map['student_no'] as String?) ?? '',
        gender: (map['gender'] as String?) ?? '',
        phone: (map['phone'] as String?) ?? '',
        note: (map['note'] as String?) ?? '',
        groupName: (map['group_name'] as String?) ?? '',
        role: (map['role'] as String?) ?? '',
        birthday: (map['birthday'] as String?) ?? '',
        address: (map['address'] as String?) ?? '',
        points: (map['points'] as num?)?.toInt() ?? 0,
        seatRow: (map['seat_row'] as num?)?.toInt(),
        seatCol: (map['seat_col'] as num?)?.toInt(),
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
        delta: (map['delta'] as num?)?.toInt() ?? 0,
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

  /// 展示用标题：班级名已含年级时不再重复拼接
  String get displayTitle {
    final n = name.trim();
    final g = grade.trim();
    if (g.isEmpty) return n;
    if (n.isEmpty) return g;
    if (n.contains(g)) return n;
    return '$g · $n';
  }

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

enum TeacherRole { homeroom, subject }

extension TeacherRoleX on TeacherRole {
  String get label => switch (this) {
        TeacherRole.homeroom => '班主任',
        TeacherRole.subject => '科任',
      };

  String get storage => name;

  static TeacherRole fromStorage(String? raw) {
    if (raw == 'subject') return TeacherRole.subject;
    return TeacherRole.homeroom;
  }
}

/// 可管理的班级（多班级）
class ManagedClass {
  final String id;
  final String name;
  /// 所属学校，档案按学校归类
  final String school;
  final String grade;
  /// 列表次级分组，如「高一」「任教」
  final String groupName;
  final int seatRows;
  final int seatCols;
  final TeacherRole teacherRole;
  /// 任教科目，如「语文」「数学」（科任必填体验）
  final String subject;
  /// 用户覆盖的功能显隐；未出现的键走角色默认
  final Map<String, bool> featureFlags;
  final int sortOrder;
  final DateTime createdAt;

  const ManagedClass({
    required this.id,
    required this.name,
    this.school = '',
    this.grade = '',
    this.groupName = '',
    this.seatRows = 6,
    this.seatCols = 8,
    this.teacherRole = TeacherRole.homeroom,
    this.subject = '',
    this.featureFlags = const {},
    this.sortOrder = 0,
    required this.createdAt,
  });

  ClassProfile get asProfile => ClassProfile(
        name: name,
        grade: grade,
        seatRows: seatRows,
        seatCols: seatCols,
      );

  String get displayTitle => asProfile.displayTitle;

  String get schoolLabel {
    final s = school.trim();
    return s.isEmpty ? '未填写学校' : s;
  }

  /// 如「班主任 · 语文老师」「数学老师」
  String get roleLabel {
    final tags = roleTags;
    return tags.join(' · ');
  }

  /// 身份标签：班主任也是授课老师，两项分开展示
  List<String> get roleTags {
    final s = subject.trim();
    if (teacherRole == TeacherRole.homeroom) {
      if (s.isEmpty) return const ['班主任'];
      return ['班主任', '$s老师'];
    }
    if (s.isEmpty) return const ['科任老师'];
    return ['$s老师'];
  }

  ManagedClass copyWith({
    String? id,
    String? name,
    String? school,
    String? grade,
    String? groupName,
    int? seatRows,
    int? seatCols,
    TeacherRole? teacherRole,
    String? subject,
    Map<String, bool>? featureFlags,
    int? sortOrder,
    DateTime? createdAt,
  }) {
    return ManagedClass(
      id: id ?? this.id,
      name: name ?? this.name,
      school: school ?? this.school,
      grade: grade ?? this.grade,
      groupName: groupName ?? this.groupName,
      seatRows: seatRows ?? this.seatRows,
      seatCols: seatCols ?? this.seatCols,
      teacherRole: teacherRole ?? this.teacherRole,
      subject: subject ?? this.subject,
      featureFlags: featureFlags ?? this.featureFlags,
      sortOrder: sortOrder ?? this.sortOrder,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  Map<String, Object?> toMap() => {
        'id': id,
        'name': name,
        'school': school,
        'grade': grade,
        'group_name': groupName,
        'seat_rows': seatRows,
        'seat_cols': seatCols,
        'teacher_role': teacherRole.storage,
        'subject': subject,
        'feature_flags':
            featureFlags.isEmpty ? null : jsonEncode(featureFlags),
        'sort_order': sortOrder,
        'created_at': createdAt.toIso8601String(),
      };

  factory ManagedClass.fromMap(Map<String, Object?> map) {
    Map<String, bool> flags = {};
    final raw = map['feature_flags'] as String?;
    if (raw != null && raw.trim().isNotEmpty) {
      try {
        final decoded = jsonDecode(raw);
        if (decoded is Map) {
          flags = decoded.map(
            (k, v) => MapEntry(k.toString(), v == true || v == 1),
          );
        }
      } catch (_) {}
    }
    return ManagedClass(
      id: map['id']! as String,
      name: map['name']! as String,
      school: (map['school'] as String?) ?? '',
      grade: (map['grade'] as String?) ?? '',
      groupName: (map['group_name'] as String?) ?? '',
      seatRows: (map['seat_rows'] as int?) ?? 6,
      seatCols: (map['seat_cols'] as int?) ?? 8,
      teacherRole: TeacherRoleX.fromStorage(map['teacher_role'] as String?),
      subject: (map['subject'] as String?) ?? '',
      featureFlags: flags,
      sortOrder: (map['sort_order'] as int?) ?? 0,
      createdAt: DateTime.parse(map['created_at']! as String),
    );
  }
}

/// 每月工资（个人级，不按班级）
class SalaryRecord {
  final String id;
  final String yearMonth; // yyyy-MM
  final String title;
  final double baseAmount;
  final double allowance;
  final double deduction;
  final double netAmount;
  final String paidAt; // yyyy-MM-dd 可空
  final String note;
  final DateTime createdAt;

  const SalaryRecord({
    required this.id,
    required this.yearMonth,
    this.title = '',
    this.baseAmount = 0,
    this.allowance = 0,
    this.deduction = 0,
    this.netAmount = 0,
    this.paidAt = '',
    this.note = '',
    required this.createdAt,
  });

  static double computeNet({
    required double base,
    required double allowance,
    required double deduction,
  }) =>
      base + allowance - deduction;

  SalaryRecord copyWith({
    String? id,
    String? yearMonth,
    String? title,
    double? baseAmount,
    double? allowance,
    double? deduction,
    double? netAmount,
    String? paidAt,
    String? note,
    DateTime? createdAt,
  }) {
    return SalaryRecord(
      id: id ?? this.id,
      yearMonth: yearMonth ?? this.yearMonth,
      title: title ?? this.title,
      baseAmount: baseAmount ?? this.baseAmount,
      allowance: allowance ?? this.allowance,
      deduction: deduction ?? this.deduction,
      netAmount: netAmount ?? this.netAmount,
      paidAt: paidAt ?? this.paidAt,
      note: note ?? this.note,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  Map<String, Object?> toMap() => {
        'id': id,
        'year_month': yearMonth,
        'title': title,
        'base_amount': baseAmount,
        'allowance': allowance,
        'deduction': deduction,
        'net_amount': netAmount,
        'paid_at': paidAt,
        'note': note,
        'created_at': createdAt.toIso8601String(),
      };

  factory SalaryRecord.fromMap(Map<String, Object?> map) => SalaryRecord(
        id: map['id']! as String,
        yearMonth: map['year_month']! as String,
        title: (map['title'] as String?) ?? '',
        baseAmount: (map['base_amount'] as num?)?.toDouble() ?? 0,
        allowance: (map['allowance'] as num?)?.toDouble() ?? 0,
        deduction: (map['deduction'] as num?)?.toDouble() ?? 0,
        netAmount: (map['net_amount'] as num?)?.toDouble() ?? 0,
        paidAt: (map['paid_at'] as String?) ?? '',
        note: (map['note'] as String?) ?? '',
        createdAt: DateTime.parse(map['created_at']! as String),
      );
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

/// 教师个人待办（今日页）
class TeacherTodo {
  final String id;
  final String title;
  final bool done;
  final int sortOrder;
  final DateTime createdAt;

  const TeacherTodo({
    required this.id,
    required this.title,
    this.done = false,
    this.sortOrder = 0,
    required this.createdAt,
  });

  TeacherTodo copyWith({
    String? id,
    String? title,
    bool? done,
    int? sortOrder,
    DateTime? createdAt,
  }) {
    return TeacherTodo(
      id: id ?? this.id,
      title: title ?? this.title,
      done: done ?? this.done,
      sortOrder: sortOrder ?? this.sortOrder,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  Map<String, Object?> toMap() => {
        'id': id,
        'title': title,
        'done': done ? 1 : 0,
        'sort_order': sortOrder,
        'created_at': createdAt.toIso8601String(),
      };

  factory TeacherTodo.fromMap(Map<String, Object?> map) => TeacherTodo(
        id: map['id']! as String,
        title: map['title']! as String,
        done: (map['done'] as int?) == 1,
        sortOrder: (map['sort_order'] as int?) ?? 0,
        createdAt: DateTime.parse(map['created_at']! as String),
      );

  bool isSameDay(DateTime day) {
    return createdAt.year == day.year &&
        createdAt.month == day.month &&
        createdAt.day == day.day;
  }

  bool get isCreatedToday => isSameDay(DateTime.now());
}

/// 工作留痕类别（班主任常见台账）
enum WorkLogCategory {
  safetyEdu,
  classMeeting,
  studentTalk,
  mentalCare,
  parentComm,
  homeVisit;

  String get label => switch (this) {
        WorkLogCategory.safetyEdu => '安全教育',
        WorkLogCategory.classMeeting => '主题班会',
        WorkLogCategory.studentTalk => '学生谈话',
        WorkLogCategory.mentalCare => '心理关注',
        WorkLogCategory.parentComm => '家长沟通',
        WorkLogCategory.homeVisit => '家访',
      };

  String get hint => switch (this) {
        WorkLogCategory.safetyEdu => '活动主题、参与对象、要点',
        WorkLogCategory.classMeeting => '班会主题、内容与效果',
        WorkLogCategory.studentTalk => '谈话对象、事由与跟进',
        WorkLogCategory.mentalCare => '关注对象、情况与措施',
        WorkLogCategory.parentComm => '沟通对象、方式与共识',
        WorkLogCategory.homeVisit => '家访对象、时间与情况',
      };

  static WorkLogCategory fromStorage(String raw) {
    for (final c in WorkLogCategory.values) {
      if (c.name == raw) return c;
    }
    return WorkLogCategory.classMeeting;
  }
}

class WorkLog {
  final String id;
  final WorkLogCategory category;
  final String title;
  final String content;
  final String date; // yyyy-MM-dd
  final String studentIds; // comma-separated
  final DateTime createdAt;
  final DateTime updatedAt;

  const WorkLog({
    required this.id,
    required this.category,
    required this.title,
    required this.content,
    required this.date,
    this.studentIds = '',
    required this.createdAt,
    required this.updatedAt,
  });

  List<String> get studentIdList => studentIds
      .split(',')
      .map((e) => e.trim())
      .where((e) => e.isNotEmpty)
      .toList();

  Map<String, Object?> toMap() => {
        'id': id,
        'category': category.name,
        'title': title,
        'content': content,
        'date': date,
        'student_ids': studentIds,
        'created_at': createdAt.toIso8601String(),
        'updated_at': updatedAt.toIso8601String(),
      };

  factory WorkLog.fromMap(Map<String, Object?> map) => WorkLog(
        id: map['id']! as String,
        category: WorkLogCategory.fromStorage(map['category']! as String),
        title: map['title']! as String,
        content: (map['content'] as String?) ?? '',
        date: map['date']! as String,
        studentIds: (map['student_ids'] as String?) ?? '',
        createdAt: DateTime.parse(map['created_at']! as String),
        updatedAt: DateTime.parse(map['updated_at']! as String),
      );
}

/// 工作留痕附件类型
enum WorkLogMediaKind {
  photo,
  audio,
  video,
  file;

  String get label => switch (this) {
        WorkLogMediaKind.photo => '照片',
        WorkLogMediaKind.audio => '语音',
        WorkLogMediaKind.video => '视频',
        WorkLogMediaKind.file => '文件',
      };

  static WorkLogMediaKind fromStorage(String raw) {
    for (final k in WorkLogMediaKind.values) {
      if (k.name == raw) return k;
    }
    return WorkLogMediaKind.file;
  }

  static WorkLogMediaKind? fromFileName(String name) {
    final i = name.lastIndexOf('.');
    if (i < 0 || i == name.length - 1) return WorkLogMediaKind.file;
    final ext = name.substring(i + 1).toLowerCase();
    if (const {
      'jpg',
      'jpeg',
      'png',
      'gif',
      'webp',
      'heic',
      'bmp',
    }.contains(ext)) {
      return WorkLogMediaKind.photo;
    }
    if (const {
      'mp3',
      'm4a',
      'aac',
      'wav',
      'ogg',
      'amr',
      'flac',
    }.contains(ext)) {
      return WorkLogMediaKind.audio;
    }
    if (const {
      'mp4',
      'mov',
      'm4v',
      'avi',
      'mkv',
      '3gp',
      'webm',
    }.contains(ext)) {
      return WorkLogMediaKind.video;
    }
    return WorkLogMediaKind.file;
  }
}

/// 工作留痕本地附件（照片 / 语音 / 视频 / 文件）
class WorkLogAttachment {
  final String id;
  final String workLogId;
  final WorkLogMediaKind kind;
  final String fileName;
  final String storedName;
  final String mimeHint;
  final int sizeBytes;
  final DateTime createdAt;

  const WorkLogAttachment({
    required this.id,
    required this.workLogId,
    required this.kind,
    required this.fileName,
    required this.storedName,
    this.mimeHint = '',
    this.sizeBytes = 0,
    required this.createdAt,
  });

  Map<String, Object?> toMap() => {
        'id': id,
        'work_log_id': workLogId,
        'kind': kind.name,
        'file_name': fileName,
        'stored_name': storedName,
        'mime_hint': mimeHint,
        'size_bytes': sizeBytes,
        'created_at': createdAt.toIso8601String(),
      };

  factory WorkLogAttachment.fromMap(Map<String, Object?> map) =>
      WorkLogAttachment(
        id: map['id']! as String,
        workLogId: map['work_log_id']! as String,
        kind: WorkLogMediaKind.fromStorage(map['kind']! as String),
        fileName: map['file_name']! as String,
        storedName: map['stored_name']! as String,
        mimeHint: (map['mime_hint'] as String?) ?? '',
        sizeBytes: (map['size_bytes'] as int?) ?? 0,
        createdAt: DateTime.parse(map['created_at']! as String),
      );
}

/// 请假记录
class LeaveRecord {
  final String id;
  final String studentId;
  final String date;
  final String reason;
  final String pickup;
  final DateTime createdAt;

  const LeaveRecord({
    required this.id,
    required this.studentId,
    required this.date,
    this.reason = '',
    this.pickup = '',
    required this.createdAt,
  });

  Map<String, Object?> toMap() => {
        'id': id,
        'student_id': studentId,
        'date': date,
        'reason': reason,
        'pickup': pickup,
        'created_at': createdAt.toIso8601String(),
      };

  factory LeaveRecord.fromMap(Map<String, Object?> map) => LeaveRecord(
        id: map['id']! as String,
        studentId: map['student_id']! as String,
        date: map['date']! as String,
        reason: (map['reason'] as String?) ?? '',
        pickup: (map['pickup'] as String?) ?? '',
        createdAt: DateTime.parse(map['created_at']! as String),
      );
}

/// 违纪处理记录
class DisciplineRecord {
  final String id;
  final String studentId;
  final String date;
  final String title;
  final String action;
  final int pointsDelta;
  final DateTime createdAt;

  const DisciplineRecord({
    required this.id,
    required this.studentId,
    required this.date,
    required this.title,
    this.action = '',
    this.pointsDelta = 0,
    required this.createdAt,
  });

  Map<String, Object?> toMap() => {
        'id': id,
        'student_id': studentId,
        'date': date,
        'title': title,
        'action': action,
        'points_delta': pointsDelta,
        'created_at': createdAt.toIso8601String(),
      };

  factory DisciplineRecord.fromMap(Map<String, Object?> map) =>
      DisciplineRecord(
        id: map['id']! as String,
        studentId: map['student_id']! as String,
        date: map['date']! as String,
        title: map['title']! as String,
        action: (map['action'] as String?) ?? '',
        pointsDelta: (map['points_delta'] as int?) ?? 0,
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

/// 课程表行：节次名称与上课时间（按班级配置）
class TimetablePeriod {
  final int period;
  final String label;
  final String startTime;
  final String endTime;

  const TimetablePeriod({
    required this.period,
    this.label = '',
    this.startTime = '',
    this.endTime = '',
  });

  String get displayLabel =>
      label.trim().isNotEmpty ? label.trim() : '第$period节';

  String get timeRange {
    if (startTime.isEmpty && endTime.isEmpty) return '';
    if (endTime.isEmpty) return startTime;
    if (startTime.isEmpty) return endTime;
    return '$startTime-$endTime';
  }

  TimetablePeriod copyWith({
    int? period,
    String? label,
    String? startTime,
    String? endTime,
  }) {
    return TimetablePeriod(
      period: period ?? this.period,
      label: label ?? this.label,
      startTime: startTime ?? this.startTime,
      endTime: endTime ?? this.endTime,
    );
  }

  static List<TimetablePeriod> defaults() {
    const times = [
      ('08:00', '08:45'),
      ('08:55', '09:40'),
      ('10:00', '10:45'),
      ('10:55', '11:40'),
      ('14:00', '14:45'),
      ('14:55', '15:40'),
      ('16:00', '16:45'),
      ('16:55', '17:40'),
    ];
    return [
      for (var i = 0; i < times.length; i++)
        TimetablePeriod(
          period: i + 1,
          label: '第${i + 1}节',
          startTime: times[i].$1,
          endTime: times[i].$2,
        ),
    ];
  }
}

/// 今日某一节课（含节次与时间）
class TodayTeachingLesson {
  final String subject;
  final String periodLabel;
  final String timeRange;
  final String startTime;
  final String endTime;
  /// 所属班级展示名，如「高二 3 班」
  final String classTitle;
  final String classId;
  final int weekday;
  final int period;
  final String location;

  const TodayTeachingLesson({
    required this.subject,
    required this.periodLabel,
    this.timeRange = '',
    this.startTime = '',
    this.endTime = '',
    this.classTitle = '',
    this.classId = '',
    this.weekday = 0,
    this.period = 0,
    this.location = '',
  });

  /// 如「第1节 · 08:00-08:45」
  String get scheduleLabel {
    if (timeRange.isEmpty) return periodLabel;
    return '$periodLabel · $timeRange';
  }

  /// 如「语文 · 高二 3 班」
  String get detailLabel {
    if (classTitle.isEmpty) return subject;
    return '$subject · $classTitle';
  }

  String get classLocationLabel {
    final parts = <String>[
      if (classTitle.isNotEmpty) classTitle,
      if (location.trim().isNotEmpty) location.trim(),
    ];
    return parts.join(' · ');
  }

  DateTime? get _todayStart {
    final t = _parseClock(startTime.isNotEmpty
        ? startTime
        : (timeRange.contains('-') ? timeRange.split('-').first.trim() : ''));
    return t;
  }

  DateTime? get _todayEnd {
    final raw = endTime.isNotEmpty
        ? endTime
        : (timeRange.contains('-') ? timeRange.split('-').last.trim() : '');
    return _parseClock(raw);
  }

  DateTime? _parseClock(String raw) {
    final parts = raw.split(':');
    if (parts.length < 2) return null;
    final h = int.tryParse(parts[0]);
    final m = int.tryParse(parts[1]);
    if (h == null || m == null) return null;
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day, h.clamp(0, 23), m.clamp(0, 59));
  }

  bool get isFinished {
    final end = _todayEnd;
    if (end == null) return false;
    return DateTime.now().isAfter(end);
  }

  bool get isInProgress {
    final start = _todayStart;
    final end = _todayEnd;
    if (start == null || end == null) return false;
    final now = DateTime.now();
    return !now.isBefore(start) && !now.isAfter(end);
  }

  String get statusLabel {
    if (isFinished) return '已上完';
    if (isInProgress) return '进行中';
    return '待上课';
  }
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

/// 一次考试存档（期末 / 半期 / 月考等，类别可自由编辑）
class Exam {
  final String id;
  final String title;
  final String category;
  final String examDate; // yyyy-MM-dd
  final List<String> subjects;
  final double fullScore;
  final double passScore;
  final String note;
  final DateTime createdAt;
  final DateTime updatedAt;

  const Exam({
    required this.id,
    required this.title,
    required this.category,
    required this.examDate,
    required this.subjects,
    this.fullScore = 100,
    this.passScore = 60,
    this.note = '',
    required this.createdAt,
    required this.updatedAt,
  });

  Exam copyWith({
    String? id,
    String? title,
    String? category,
    String? examDate,
    List<String>? subjects,
    double? fullScore,
    double? passScore,
    String? note,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Exam(
      id: id ?? this.id,
      title: title ?? this.title,
      category: category ?? this.category,
      examDate: examDate ?? this.examDate,
      subjects: subjects ?? this.subjects,
      fullScore: fullScore ?? this.fullScore,
      passScore: passScore ?? this.passScore,
      note: note ?? this.note,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, Object?> toMap() => {
        'id': id,
        'title': title,
        'category': category,
        'exam_date': examDate,
        'subjects': subjects.join(','),
        'full_score': fullScore,
        'pass_score': passScore,
        'note': note,
        'created_at': createdAt.toIso8601String(),
        'updated_at': updatedAt.toIso8601String(),
      };

  factory Exam.fromMap(Map<String, Object?> map) {
    final raw = (map['subjects'] as String?) ?? '';
    final subjects = raw
        .split(RegExp(r'[,，、]'))
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();
    return Exam(
      id: map['id']! as String,
      title: map['title']! as String,
      category: (map['category'] as String?) ?? '月考',
      examDate: map['exam_date']! as String,
      subjects: subjects,
      fullScore: (map['full_score'] as num?)?.toDouble() ?? 100,
      passScore: (map['pass_score'] as num?)?.toDouble() ?? 60,
      note: (map['note'] as String?) ?? '',
      createdAt: DateTime.parse(map['created_at']! as String),
      updatedAt: DateTime.parse(map['updated_at']! as String),
    );
  }
}

/// 某次考试中一名学生的各科成绩
class ExamScore {
  final String id;
  final String examId;
  final String studentId;
  final Map<String, double> scores;
  final String remark;

  /// 折算/赋分排名（仅导入，App 无法计算）
  final int? convertedRank;

  /// 年级/校级排名（仅导入）
  final int? gradeRank;

  /// 官方单科位次（仅导入），key=科目名
  final Map<String, int> subjectRanks;

  const ExamScore({
    required this.id,
    required this.examId,
    required this.studentId,
    required this.scores,
    this.remark = '',
    this.convertedRank,
    this.gradeRank,
    this.subjectRanks = const {},
  });

  double? scoreOf(String subject) => scores[subject];

  double get total {
    if (scores.isEmpty) return 0;
    return scores.values.fold(0.0, (a, b) => a + b);
  }

  ExamScore copyWith({
    String? id,
    String? examId,
    String? studentId,
    Map<String, double>? scores,
    String? remark,
    int? convertedRank,
    int? gradeRank,
    Map<String, int>? subjectRanks,
    bool clearConvertedRank = false,
    bool clearGradeRank = false,
  }) {
    return ExamScore(
      id: id ?? this.id,
      examId: examId ?? this.examId,
      studentId: studentId ?? this.studentId,
      scores: scores ?? this.scores,
      remark: remark ?? this.remark,
      convertedRank:
          clearConvertedRank ? null : (convertedRank ?? this.convertedRank),
      gradeRank: clearGradeRank ? null : (gradeRank ?? this.gradeRank),
      subjectRanks: subjectRanks ?? this.subjectRanks,
    );
  }

  Map<String, Object?> toMap() => {
        'id': id,
        'exam_id': examId,
        'student_id': studentId,
        'scores': scores.entries.map((e) => '${e.key}:${e.value}').join('|'),
        'remark': remark,
        'converted_rank': convertedRank,
        'grade_rank': gradeRank,
        'subject_ranks': subjectRanks.entries
            .map((e) => '${e.key}:${e.value}')
            .join('|'),
      };

  factory ExamScore.fromMap(Map<String, Object?> map) {
    final raw = (map['scores'] as String?) ?? '';
    final scores = <String, double>{};
    if (raw.trim().isNotEmpty) {
      for (final part in raw.split('|')) {
        final i = part.lastIndexOf(':');
        if (i <= 0) continue;
        final key = part.substring(0, i).trim();
        final val = double.tryParse(part.substring(i + 1).trim());
        if (key.isNotEmpty && val != null) scores[key] = val;
      }
    }
    final subjectRanks = <String, int>{};
    final sr = (map['subject_ranks'] as String?) ?? '';
    if (sr.trim().isNotEmpty) {
      for (final part in sr.split('|')) {
        final i = part.lastIndexOf(':');
        if (i <= 0) continue;
        final key = part.substring(0, i).trim();
        final val = int.tryParse(part.substring(i + 1).trim());
        if (key.isNotEmpty && val != null) subjectRanks[key] = val;
      }
    }
    return ExamScore(
      id: map['id']! as String,
      examId: map['exam_id']! as String,
      studentId: map['student_id']! as String,
      scores: scores,
      remark: (map['remark'] as String?) ?? '',
      convertedRank: map['converted_rank'] as int?,
      gradeRank: map['grade_rank'] as int?,
      subjectRanks: subjectRanks,
    );
  }
}

class SubjectStat {
  const SubjectStat({
    required this.label,
    required this.count,
    required this.average,
    required this.max,
    required this.min,
    required this.passCount,
    required this.passScore,
  });

  final String label;
  final int count;
  final double average;
  final double max;
  final double min;
  final int passCount;
  final double passScore;

  double get passRate => count == 0 ? 0 : passCount / count;
}

/// 学期：进行中可日常使用；结束后整学期存档，可查阅
enum SemesterStatus { active, archived }

class Semester {
  final String id;
  final String title;
  final String schoolYear;
  final String term;
  final String startDate;
  final String endDate;
  final SemesterStatus status;
  /// 存档时的 JSON 快照；进行中为空
  final String snapshot;
  final String note;
  final DateTime createdAt;
  final DateTime? archivedAt;

  const Semester({
    required this.id,
    required this.title,
    this.schoolYear = '',
    this.term = '',
    this.startDate = '',
    this.endDate = '',
    required this.status,
    this.snapshot = '',
    this.note = '',
    required this.createdAt,
    this.archivedAt,
  });

  bool get isActive => status == SemesterStatus.active;
  bool get isArchived => status == SemesterStatus.archived;

  Map<String, dynamic>? get snapshotMap {
    if (snapshot.trim().isEmpty) return null;
    try {
      return Map<String, dynamic>.from(jsonDecode(snapshot) as Map);
    } catch (_) {
      return null;
    }
  }

  Semester copyWith({
    String? id,
    String? title,
    String? schoolYear,
    String? term,
    String? startDate,
    String? endDate,
    SemesterStatus? status,
    String? snapshot,
    String? note,
    DateTime? createdAt,
    DateTime? archivedAt,
    bool clearArchivedAt = false,
  }) {
    return Semester(
      id: id ?? this.id,
      title: title ?? this.title,
      schoolYear: schoolYear ?? this.schoolYear,
      term: term ?? this.term,
      startDate: startDate ?? this.startDate,
      endDate: endDate ?? this.endDate,
      status: status ?? this.status,
      snapshot: snapshot ?? this.snapshot,
      note: note ?? this.note,
      createdAt: createdAt ?? this.createdAt,
      archivedAt: clearArchivedAt ? null : (archivedAt ?? this.archivedAt),
    );
  }

  Map<String, Object?> toMap() => {
        'id': id,
        'title': title,
        'school_year': schoolYear,
        'term': term,
        'start_date': startDate,
        'end_date': endDate,
        'status': status.name,
        'snapshot': snapshot,
        'note': note,
        'created_at': createdAt.toIso8601String(),
        'archived_at': archivedAt?.toIso8601String(),
      };

  factory Semester.fromMap(Map<String, Object?> map) {
    final statusRaw = (map['status'] as String?) ?? 'active';
    return Semester(
      id: map['id']! as String,
      title: map['title']! as String,
      schoolYear: (map['school_year'] as String?) ?? '',
      term: (map['term'] as String?) ?? '',
      startDate: (map['start_date'] as String?) ?? '',
      endDate: (map['end_date'] as String?) ?? '',
      status: statusRaw == 'archived'
          ? SemesterStatus.archived
          : SemesterStatus.active,
      snapshot: (map['snapshot'] as String?) ?? '',
      note: (map['note'] as String?) ?? '',
      createdAt: DateTime.parse(map['created_at']! as String),
      archivedAt: map['archived_at'] == null
          ? null
          : DateTime.tryParse(map['archived_at']! as String),
    );
  }

  /// 按当前日期推断默认学期名，如「2025–2026 学年 · 上学期」
  static ({String title, String schoolYear, String term}) defaultLabel(
      [DateTime? now]) {
    final n = now ?? DateTime.now();
    // 国内习惯：8–次年1月为上学期，2–7月为下学期
    late final String schoolYear;
    late final String term;
    if (n.month >= 8) {
      schoolYear = '${n.year}-${n.year + 1}';
      term = '上学期';
    } else if (n.month == 1) {
      schoolYear = '${n.year - 1}-${n.year}';
      term = '上学期';
    } else {
      schoolYear = '${n.year - 1}-${n.year}';
      term = '下学期';
    }
    return (
      title: '$schoolYear 学年 · $term',
      schoolYear: schoolYear,
      term: term,
    );
  }
}

/// 授课进度状态
enum LessonStatus { planned, teaching, done }

extension LessonStatusX on LessonStatus {
  String get label => switch (this) {
        LessonStatus.planned => '未讲',
        LessonStatus.teaching => '进行中',
        LessonStatus.done => '已讲完',
      };

  static LessonStatus fromStorage(String? raw) {
    for (final s in LessonStatus.values) {
      if (s.name == raw) return s;
    }
    return LessonStatus.planned;
  }
}

/// 一节课 / 一个教学单元的授课进度
class LessonUnit {
  final String id;
  /// 所属班级 id（读取数据库时有值）
  final String classId;
  final String subject;
  final String title;
  final String chapter;
  final String progressNote;
  final LessonStatus status;
  final String plannedDate; // yyyy-MM-dd
  final String taughtDate;
  final int sortOrder;
  final DateTime createdAt;
  final DateTime updatedAt;

  const LessonUnit({
    required this.id,
    this.classId = '',
    this.subject = '',
    required this.title,
    this.chapter = '',
    this.progressNote = '',
    this.status = LessonStatus.planned,
    this.plannedDate = '',
    this.taughtDate = '',
    this.sortOrder = 0,
    required this.createdAt,
    required this.updatedAt,
  });

  LessonUnit copyWith({
    String? id,
    String? classId,
    String? subject,
    String? title,
    String? chapter,
    String? progressNote,
    LessonStatus? status,
    String? plannedDate,
    String? taughtDate,
    int? sortOrder,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return LessonUnit(
      id: id ?? this.id,
      classId: classId ?? this.classId,
      subject: subject ?? this.subject,
      title: title ?? this.title,
      chapter: chapter ?? this.chapter,
      progressNote: progressNote ?? this.progressNote,
      status: status ?? this.status,
      plannedDate: plannedDate ?? this.plannedDate,
      taughtDate: taughtDate ?? this.taughtDate,
      sortOrder: sortOrder ?? this.sortOrder,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, Object?> toMap() => {
        'id': id,
        if (classId.isNotEmpty) 'class_id': classId,
        'subject': subject,
        'title': title,
        'chapter': chapter,
        'progress_note': progressNote,
        'status': status.name,
        'planned_date': plannedDate,
        'taught_date': taughtDate,
        'sort_order': sortOrder,
        'created_at': createdAt.toIso8601String(),
        'updated_at': updatedAt.toIso8601String(),
      };

  factory LessonUnit.fromMap(Map<String, Object?> map) => LessonUnit(
        id: map['id']! as String,
        classId: (map['class_id'] as String?) ?? '',
        subject: (map['subject'] as String?) ?? '',
        title: map['title']! as String,
        chapter: (map['chapter'] as String?) ?? '',
        progressNote: (map['progress_note'] as String?) ?? '',
        status: LessonStatusX.fromStorage(map['status'] as String?),
        plannedDate: (map['planned_date'] as String?) ?? '',
        taughtDate: (map['taught_date'] as String?) ?? '',
        sortOrder: (map['sort_order'] as int?) ?? 0,
        createdAt: DateTime.parse(map['created_at']! as String),
        updatedAt: DateTime.parse(map['updated_at']! as String),
      );
}

/// 课件 / PPT 等附件（文件本体在本地目录）
class LessonFile {
  final String id;
  final String unitId;
  final String fileName;
  final String storedName;
  final String mimeHint;
  final int sizeBytes;
  final DateTime createdAt;

  const LessonFile({
    required this.id,
    required this.unitId,
    required this.fileName,
    required this.storedName,
    this.mimeHint = '',
    this.sizeBytes = 0,
    required this.createdAt,
  });

  String get ext {
    final i = fileName.lastIndexOf('.');
    if (i < 0 || i == fileName.length - 1) return '';
    return fileName.substring(i + 1).toLowerCase();
  }

  bool get isPpt =>
      const {'ppt', 'pptx', 'pps', 'ppsx'}.contains(ext);

  Map<String, Object?> toMap() => {
        'id': id,
        'unit_id': unitId,
        'file_name': fileName,
        'stored_name': storedName,
        'mime_hint': mimeHint,
        'size_bytes': sizeBytes,
        'created_at': createdAt.toIso8601String(),
      };

  factory LessonFile.fromMap(Map<String, Object?> map) => LessonFile(
        id: map['id']! as String,
        unitId: map['unit_id']! as String,
        fileName: map['file_name']! as String,
        storedName: map['stored_name']! as String,
        mimeHint: (map['mime_hint'] as String?) ?? '',
        sizeBytes: (map['size_bytes'] as int?) ?? 0,
        createdAt: DateTime.parse(map['created_at']! as String),
      );
}

/// 考试相关资料（试卷、答题卡、分析表等，文件在本地）
class ExamFile {
  final String id;
  final String examId;
  final String fileName;
  final String storedName;
  final String mimeHint;
  final int sizeBytes;
  final String note;
  final DateTime createdAt;

  const ExamFile({
    required this.id,
    required this.examId,
    required this.fileName,
    required this.storedName,
    this.mimeHint = '',
    this.sizeBytes = 0,
    this.note = '',
    required this.createdAt,
  });

  String get ext {
    final i = fileName.lastIndexOf('.');
    if (i < 0 || i == fileName.length - 1) return '';
    return fileName.substring(i + 1).toLowerCase();
  }

  Map<String, Object?> toMap() => {
        'id': id,
        'exam_id': examId,
        'file_name': fileName,
        'stored_name': storedName,
        'mime_hint': mimeHint,
        'size_bytes': sizeBytes,
        'note': note,
        'created_at': createdAt.toIso8601String(),
      };

  factory ExamFile.fromMap(Map<String, Object?> map) => ExamFile(
        id: map['id']! as String,
        examId: map['exam_id']! as String,
        fileName: map['file_name']! as String,
        storedName: map['stored_name']! as String,
        mimeHint: (map['mime_hint'] as String?) ?? '',
        sizeBytes: (map['size_bytes'] as int?) ?? 0,
        note: (map['note'] as String?) ?? '',
        createdAt: DateTime.parse(map['created_at']! as String),
      );
}
