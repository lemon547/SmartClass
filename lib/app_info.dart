/// 应用展示信息（与 pubspec version 保持同步）
abstract final class AppInfo {
  static const name = 'Smart Class';
  static const tagline = '再忙也要记得休息呀';
  static const version = '1.0.0';
  static const versionLabel = 'v$version';
  static const logoAsset = 'assets/mascots/sunny_logo.gif';

  /// 法务联系占位（上架或对外发布时可替换为真实邮箱）
  static const contactEmail = 'support@example.com';
}
