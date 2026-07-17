/// 应用展示信息（与 pubspec version 保持同步）
abstract final class AppInfo {
  static const name = '班主任助手';
  static const tagline = '学生 · 点名 · 积分 · 考勤，本地离线可用';
  static const version = '1.0.0';
  static const versionLabel = 'v$version';
  static const logoAsset = 'assets/icons/app_logo.png';
  /// 桌面/启动器图标（带底色）；界面内用 [logoAsset]
  static const launcherIconAsset = 'assets/icons/app_icon.png';

  /// 法务联系占位（上架或对外发布时可替换为真实邮箱）
  static const contactEmail = 'support@example.com';
}
