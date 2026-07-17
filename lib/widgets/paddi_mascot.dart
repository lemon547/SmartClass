import 'package:flutter/material.dart';
import 'package:smart_class/theme/app_theme.dart';
import 'package:smart_class/theme/mascot_assets.dart';

/// 仅在「懒羊羊皮肤」下显示；不改全局颜色。
class PaddiMascot extends StatelessWidget {
  const PaddiMascot({
    super.key,
    this.asset = MascotAssets.icon,
    this.height = 72,
    this.force = false,
  });

  final String asset;
  final double height;
  /// 主题选择预览等场景强制显示
  final bool force;

  @override
  Widget build(BuildContext context) {
    if (!force && !AppTheme.showMascot) return const SizedBox.shrink();
    return Image.asset(
      asset,
      height: height,
      fit: BoxFit.contain,
      filterQuality: FilterQuality.high,
      errorBuilder: (_, __, ___) => const SizedBox.shrink(),
    );
  }
}

/// 首页顶部横幅：右侧贴纸，不占满屏
class PaddiHomeBanner extends StatelessWidget {
  const PaddiHomeBanner({super.key});

  @override
  Widget build(BuildContext context) {
    if (!AppTheme.showMascot) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      child: SizedBox(
        height: 88,
        child: Stack(
          alignment: Alignment.centerLeft,
          children: [
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: AppTheme.surface,
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(left: 18, right: 100),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '小羊贴纸皮肤',
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.label,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '界面还是白天配色，只多了懒羊羊立绘',
                    style: TextStyle(
                      fontSize: 13,
                      color: AppTheme.tertiaryLabel,
                    ),
                  ),
                ],
              ),
            ),
            Positioned(
              right: 4,
              bottom: 0,
              child: PaddiMascot(asset: MascotAssets.pose, height: 86),
            ),
          ],
        ),
      ),
    );
  }
}
