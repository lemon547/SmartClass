import 'package:smart_class/models/models.dart';

/// 功能 id（首页常用工具 /「班级」入口共用）
abstract final class ClassFeatureIds {
  static const students = 'students';
  static const rollCall = 'rollCall';
  static const attendance = 'attendance';
  static const grades = 'grades';
  static const timetable = 'timetable';
  static const seating = 'seating';
  static const homework = 'homework';
  static const points = 'points';
  static const duty = 'duty';
  static const workLogs = 'workLogs';
  static const fund = 'fund';
  static const notes = 'notes';
  static const groups = 'groups';
  static const rewards = 'rewards';
  static const countdowns = 'countdowns';
  static const weeklyReport = 'weeklyReport';
  static const settlements = 'settlements';
  static const semesters = 'semesters';
  static const lessonProgress = 'lessonProgress';
  static const leave = 'leave';
}

enum ClassFeatureGroup { teaching, homeroom }

class ClassFeatureDef {
  const ClassFeatureDef({
    required this.id,
    required this.title,
    required this.group,
    required this.defaultHomeroom,
    required this.defaultSubject,
    this.homeShortcut = false,
  });

  final String id;
  final String title;
  final ClassFeatureGroup group;
  final bool defaultHomeroom;
  final bool defaultSubject;
  final bool homeShortcut;

  bool defaultFor(TeacherRole role) =>
      role == TeacherRole.homeroom ? defaultHomeroom : defaultSubject;
}

/// 可配置功能注册表
abstract final class ClassFeatures {
  static const List<ClassFeatureDef> all = [
    ClassFeatureDef(
      id: ClassFeatureIds.students,
      title: '学生花名册',
      group: ClassFeatureGroup.teaching,
      defaultHomeroom: true,
      defaultSubject: true,
    ),
    ClassFeatureDef(
      id: ClassFeatureIds.rollCall,
      title: '随机点名',
      group: ClassFeatureGroup.teaching,
      defaultHomeroom: true,
      defaultSubject: true,
      homeShortcut: true,
    ),
    ClassFeatureDef(
      id: ClassFeatureIds.attendance,
      title: '考勤',
      group: ClassFeatureGroup.teaching,
      defaultHomeroom: true,
      defaultSubject: true,
      homeShortcut: true,
    ),
    ClassFeatureDef(
      id: ClassFeatureIds.grades,
      title: '成绩',
      group: ClassFeatureGroup.teaching,
      defaultHomeroom: true,
      defaultSubject: true,
      homeShortcut: true,
    ),
    ClassFeatureDef(
      id: ClassFeatureIds.timetable,
      title: '班级课表',
      group: ClassFeatureGroup.teaching,
      defaultHomeroom: true,
      defaultSubject: true,
    ),
    ClassFeatureDef(
      id: ClassFeatureIds.seating,
      title: '座位表',
      group: ClassFeatureGroup.teaching,
      defaultHomeroom: true,
      defaultSubject: true,
    ),
    ClassFeatureDef(
      id: ClassFeatureIds.homework,
      title: '作业检查',
      group: ClassFeatureGroup.teaching,
      defaultHomeroom: true,
      defaultSubject: true,
    ),
    ClassFeatureDef(
      id: ClassFeatureIds.lessonProgress,
      title: '授课进度',
      group: ClassFeatureGroup.teaching,
      defaultHomeroom: true,
      defaultSubject: true,
    ),
    ClassFeatureDef(
      id: ClassFeatureIds.leave,
      title: '请假管理',
      group: ClassFeatureGroup.homeroom,
      defaultHomeroom: true,
      defaultSubject: false,
      homeShortcut: true,
    ),
    ClassFeatureDef(
      id: ClassFeatureIds.points,
      title: '积分',
      group: ClassFeatureGroup.homeroom,
      defaultHomeroom: true,
      defaultSubject: false,
      homeShortcut: true,
    ),
    ClassFeatureDef(
      id: ClassFeatureIds.duty,
      title: '值日安排',
      group: ClassFeatureGroup.homeroom,
      defaultHomeroom: true,
      defaultSubject: false,
    ),
    ClassFeatureDef(
      id: ClassFeatureIds.workLogs,
      title: '工作留痕',
      group: ClassFeatureGroup.homeroom,
      defaultHomeroom: true,
      defaultSubject: false,
    ),
    ClassFeatureDef(
      id: ClassFeatureIds.fund,
      title: '班费',
      group: ClassFeatureGroup.homeroom,
      defaultHomeroom: true,
      defaultSubject: false,
    ),
    ClassFeatureDef(
      id: ClassFeatureIds.notes,
      title: '班级记事',
      group: ClassFeatureGroup.homeroom,
      defaultHomeroom: true,
      defaultSubject: false,
    ),
    ClassFeatureDef(
      id: ClassFeatureIds.groups,
      title: '小组',
      group: ClassFeatureGroup.homeroom,
      defaultHomeroom: true,
      defaultSubject: false,
    ),
    ClassFeatureDef(
      id: ClassFeatureIds.rewards,
      title: '积分兑换',
      group: ClassFeatureGroup.homeroom,
      defaultHomeroom: true,
      defaultSubject: false,
    ),
    ClassFeatureDef(
      id: ClassFeatureIds.countdowns,
      title: '倒数日',
      group: ClassFeatureGroup.homeroom,
      defaultHomeroom: true,
      defaultSubject: false,
    ),
    ClassFeatureDef(
      id: ClassFeatureIds.weeklyReport,
      title: '本周概况',
      group: ClassFeatureGroup.homeroom,
      defaultHomeroom: true,
      defaultSubject: false,
    ),
    ClassFeatureDef(
      id: ClassFeatureIds.settlements,
      title: '积分结算',
      group: ClassFeatureGroup.homeroom,
      defaultHomeroom: true,
      defaultSubject: false,
    ),
    ClassFeatureDef(
      id: ClassFeatureIds.semesters,
      title: '学期存档',
      group: ClassFeatureGroup.homeroom,
      defaultHomeroom: true,
      defaultSubject: false,
    ),
  ];

  static ClassFeatureDef? byId(String id) {
    for (final f in all) {
      if (f.id == id) return f;
    }
    return null;
  }

  static List<ClassFeatureDef> homeShortcuts() =>
      all.where((f) => f.homeShortcut).toList();

  /// 用户覆盖优先，否则角色默认
  static bool isVisible({
    required String featureId,
    required TeacherRole role,
    required Map<String, bool> overrides,
  }) {
    if (overrides.containsKey(featureId)) return overrides[featureId]!;
    final def = byId(featureId);
    if (def == null) return true;
    return def.defaultFor(role);
  }
}
