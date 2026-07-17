import 'package:flutter/material.dart';
import 'package:smart_class/theme/app_theme.dart';
import 'package:smart_class/theme/mascot_assets.dart';

/// 懒羊羊皮肤：少量贴纸点缀，不替代功能图标。
class PaddiMascot extends StatelessWidget {
  const PaddiMascot({
    super.key,
    this.asset = MascotAssets.emote,
    this.height = 40,
    this.width,
    this.force = false,
  });

  final String asset;
  final double height;
  final double? width;
  final bool force;

  @override
  Widget build(BuildContext context) {
    if (!force && !AppTheme.showMascot) return const SizedBox.shrink();
    return Image.asset(
      asset,
      height: height,
      width: width,
      fit: BoxFit.contain,
      filterQuality: FilterQuality.high,
      errorBuilder: (_, __, ___) => const SizedBox.shrink(),
    );
  }
}

/// 首页顶栏淡色氛围 + 角落两只小贴纸（参考皮肤页：空位点缀）
class PaddiHomeAccent extends StatelessWidget {
  const PaddiHomeAccent({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (!AppTheme.showMascot) return child;
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Color(0xFFFFF6DF),
            Color(0x00FFF6DF),
          ],
          stops: [0.0, 1.0],
        ),
      ),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          child,
          // 角落空位小贴，不挡标题/日期
          const Positioned(
            right: 14,
            bottom: 4,
            child: PaddiMascot(asset: MascotAssets.emote, height: 32),
          ),
        ],
      ),
    );
  }
}

/// 常用入口：圆底图标（参考支付宝/微信服务宫格：浅色底 + 语义色图标）
class HomeShortcut extends StatelessWidget {
  const HomeShortcut({
    super.key,
    required this.icon,
    required this.label,
    required this.onTap,
    this.tint,
    this.sticker,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final Color? tint;
  final String? sticker;

  @override
  Widget build(BuildContext context) {
    final color = tint ?? AppTheme.blue;
    final showSticker = AppTheme.showMascot && sticker != null;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 2),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 52,
              height: 52,
              child: Stack(
                clipBehavior: Clip.none,
                alignment: Alignment.center,
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Icon(icon, size: 24, color: color),
                  ),
                  if (showSticker)
                    Positioned(
                      right: -2,
                      top: -4,
                      child: PaddiMascot(asset: sticker!, height: 18),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 6),
            Text(
              label,
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: AppTheme.label,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 空状态：小贴纸即可
class PaddiEmptyHint extends StatelessWidget {
  const PaddiEmptyHint({
    super.key,
    required this.message,
    this.asset = MascotAssets.sleepy,
  });

  final String message;
  final String asset;

  @override
  Widget build(BuildContext context) {
    if (!AppTheme.showMascot) {
      return Text(message, style: TextStyle(color: AppTheme.tertiaryLabel));
    }
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        PaddiMascot(asset: asset, height: 52),
        const SizedBox(height: 8),
        Text(
          message,
          textAlign: TextAlign.center,
          style: TextStyle(color: AppTheme.tertiaryLabel, fontSize: 15),
        ),
      ],
    );
  }
}

/// 主题列表预览
class PaddiThemePreview extends StatelessWidget {
  const PaddiThemePreview({super.key});

  @override
  Widget build(BuildContext context) {
    return const PaddiMascot(
      asset: MascotAssets.emote,
      height: 32,
      force: true,
    );
  }
}
