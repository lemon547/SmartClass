/// 界面装饰用静态图 + 固定 AI 助手身份（不再维护多形象切换）。
abstract final class MascotAssets {
  static const sleepy = 'assets/mascots/paddi0.png';
  /// 透明底跳跃姿
  static const wave = 'assets/mascots/paddi1.png';
  static const emote = 'assets/mascots/paddi_emote.png';
  static const classic = 'assets/mascots/paddi_old.png';

  /// FAB / 聊天头像固定形象
  static const fab = 'assets/mascots/paddi_fab_hug.gif';

  static const assistantName = 'Smart Class';
  static const assistantTitle = 'Smart Class 助手';
  static const assistantPersona =
      '专业稳妥、条理清晰，用简洁中文帮班主任查数据、出主意；亲切但不卖萌抢戏';

  static const assistant = FabMascotOption(
    id: 'smart_class',
    name: assistantName,
    persona: assistantPersona,
    greeting: '你好，我是 Smart Class 助手。',
    asset: fab,
  );

  /// 兼容旧调用：始终返回固定助手
  static FabMascotOption optionById(String? id) => assistant;

  static String assetForId(String? id) => fab;
}

class FabMascotOption {
  const FabMascotOption({
    required this.id,
    required this.name,
    required this.persona,
    required this.greeting,
    required this.asset,
  });

  final String id;
  final String name;
  final String persona;
  final String greeting;
  final String asset;

  String get assistantTitle => MascotAssets.assistantTitle;

  String welcomeText() =>
      '$greeting\n'
      '你可以问课表、成绩、积分、考勤，我会按上方所选班级查询。'
      '也可以让我帮你整理待办、拟定加减分规则——先给你看草稿，你点确认后才会保存。\n'
      '需要更细致的分析时，可打开右上角「详细」。';
}
