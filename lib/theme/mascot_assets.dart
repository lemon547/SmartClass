/// 懒羊羊立绘素材（贴纸皮肤用）
abstract final class MascotAssets {
  static const sleepy = 'assets/mascots/paddi0.png';
  /// 透明底跳跃姿
  static const wave = 'assets/mascots/paddi1.png';
  static const emote = 'assets/mascots/paddi_emote.png';
  static const classic = 'assets/mascots/paddi_old.png';

  /// AI 入口可选形象
  static const fabHug = 'assets/mascots/paddi_fab_hug.gif';
  static const fabTied = 'assets/mascots/paddi_fab_tied.gif';
  static const fabLaugh = 'assets/mascots/paddi_fab_laugh.gif';
  static const fabStand = 'assets/mascots/paddi_fab_stand.gif';
  static const fabJump = 'assets/mascots/paddi_fab_jump.gif';
  static const fabHat = 'assets/mascots/paddi_fab_hat.gif';
  static const fabHugDogs = 'assets/mascots/paddi_fab_hug_dogs.jpg';

  static const fabOptions = <FabMascotOption>[
    FabMascotOption(
      id: 'hug',
      label: '拥抱',
      asset: fabHug,
      animated: true,
    ),
    FabMascotOption(
      id: 'laugh',
      label: '大笑',
      asset: fabLaugh,
      animated: true,
    ),
    FabMascotOption(
      id: 'stand',
      label: '站立',
      asset: fabStand,
      animated: true,
    ),
    FabMascotOption(
      id: 'tied',
      label: '被绑住',
      asset: fabTied,
      animated: true,
    ),
    FabMascotOption(
      id: 'jump',
      label: '跳跃',
      asset: fabJump,
      animated: true,
    ),
    FabMascotOption(
      id: 'hat',
      label: '小黄帽',
      asset: fabHat,
      animated: true,
    ),
    FabMascotOption(
      id: 'hugDogs',
      label: '抱抱',
      asset: fabHugDogs,
      animated: false,
    ),
  ];

  static const defaultFabId = 'hug';

  static FabMascotOption optionById(String? id) {
    for (final o in fabOptions) {
      if (o.id == id) return o;
    }
    return fabOptions.first;
  }

  static String assetForId(String? id) => optionById(id).asset;
}

class FabMascotOption {
  const FabMascotOption({
    required this.id,
    required this.label,
    required this.asset,
    required this.animated,
  });

  final String id;
  final String label;
  final String asset;
  final bool animated;
}
