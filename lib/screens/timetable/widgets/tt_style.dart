import 'package:flutter/material.dart';

/// 教师端课表视觉：低饱和、教务系统风格
class TtStyle {
  static const accent = Color(0xFF1677FF);
  static const accentSoft = Color(0xFFE6F0FF);
  static const title = Color(0xFF333333);
  static const secondary = Color(0xFF666666);
  static const muted = Color(0xFF888888);
  static const line = Color(0xFFEEEEEE);
  static const weekendCol = Color(0xFFFAFAFB);
  static const courseBg = Color(0xFFE8F3FF);
  static const courseFg = Color(0xFF1A5FB4);
  static const pageBg = Color(0xFFFFFFFF);
  static const emptyHint = Color(0xFFB0B0B0);
  static const todoDot = Color(0xFFFF3B30);
  static const cardBorder = Color(0xFFE8E8E8);

  static const periodW = 46.0;
  static const cellH = 84.0;
  static const dayMinW = 60.0;
  static const tabH = 40.0;
  static const toolbarH = 56.0;
  static const gridLine = Color(0xFFF0F0F0);
}

/// 科目固定浅色：辅助识别，不高饱和
(Color bg, Color fg) subjectTint(String subject) {
  final s = subject.trim();
  if (s.contains('语文')) {
    return (const Color(0xFFE8F3FF), const Color(0xFF1A5FB4));
  }
  if (s.contains('数学')) {
    return (const Color(0xFFF0EBFF), const Color(0xFF5B45B0));
  }
  if (s.contains('英语') || s.contains('外语')) {
    return (const Color(0xFFE6F7EF), const Color(0xFF1F7A55));
  }
  if (s.contains('物理')) {
    return (const Color(0xFFFFF0E6), const Color(0xFFB85C1A));
  }
  if (s.contains('化学')) {
    return (const Color(0xFFFFEBF1), const Color(0xFFA33D64));
  }
  if (s.contains('生物')) {
    return (const Color(0xFFE6F6FA), const Color(0xFF1C7388));
  }
  if (s.contains('历史')) {
    return (const Color(0xFFFFF6DB), const Color(0xFF8A6A00));
  }
  if (s.contains('地理')) {
    return (const Color(0xFFE8F5E9), const Color(0xFF2E7D4F));
  }
  if (s.contains('政治') || s.contains('道德') || s.contains('思政')) {
    return (const Color(0xFFFFEBEE), const Color(0xFFC62828));
  }
  if (s.contains('体育') || s.contains('运动')) {
    return (const Color(0xFFE8F5E9), const Color(0xFF388E3C));
  }
  if (s.contains('音乐')) {
    return (const Color(0xFFF3E5F5), const Color(0xFF7B1FA2));
  }
  if (s.contains('美术') || s.contains('艺术')) {
    return (const Color(0xFFFFF3E0), const Color(0xFFE65100));
  }
  if (s.contains('班会') || s.contains('自习')) {
    return (const Color(0xFFF0F1F3), const Color(0xFF5A6270));
  }
  // 未知科目：统一浅灰蓝，避免 hash 彩虹色
  return (TtStyle.courseBg, TtStyle.courseFg);
}

/// 按星期区分浅色（周一=1 … 周日=7），低饱和便于扫读
(Color bg, Color fg) weekdayTint(int weekday) {
  return switch (weekday) {
    1 => (const Color(0xFFE8F3FF), const Color(0xFF1A5FB4)), // 蓝
    2 => (const Color(0xFFE6F7EF), const Color(0xFF1F7A55)), // 绿
    3 => (const Color(0xFFFFF0E6), const Color(0xFFB85C1A)), // 橙
    4 => (const Color(0xFFF0EBFF), const Color(0xFF5B45B0)), // 紫
    5 => (const Color(0xFFFFEBF1), const Color(0xFFA33D64)), // 粉
    6 => (const Color(0xFFE6F6FA), const Color(0xFF1C7388)), // 青
    7 => (const Color(0xFFFFF6DB), const Color(0xFF8A6A00)), // 黄
    _ => (TtStyle.courseBg, TtStyle.courseFg),
  };
}
