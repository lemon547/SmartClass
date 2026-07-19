import 'package:flutter/material.dart';
import 'package:smart_class/app_info.dart';
import 'package:smart_class/theme/app_theme.dart';

/// 品牌标：笑脸太阳 GIF（透明底；素材内已留边，避免光芒被裁切）
class AppBrandMark extends StatelessWidget {
  const AppBrandMark({super.key, this.size = 120});

  final double size;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: Image.asset(
        AppInfo.logoAsset,
        width: size,
        height: size,
        fit: BoxFit.contain,
        alignment: Alignment.center,
        filterQuality: FilterQuality.high,
        gaplessPlayback: true,
        excludeFromSemantics: true,
      ),
    );
  }
}

/// 首页顶部：logo + 名称 + 简介 + 版本
class AppBrandHeader extends StatelessWidget {
  const AppBrandHeader({super.key, this.trailing});

  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          const AppBrandMark(size: 96),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  AppInfo.name,
                  style: Theme.of(context).textTheme.displayLarge?.copyWith(
                        fontSize: 28,
                        height: 1.15,
                      ),
                ),
                const SizedBox(height: 4),
                Text(
                  AppInfo.tagline,
                  style: TextStyle(
                    fontSize: 13,
                    height: 1.25,
                    color: AppTheme.tertiaryLabel,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  AppInfo.versionLabel,
                  style: TextStyle(
                    fontSize: 12,
                    color: AppTheme.quaternaryLabel,
                  ),
                ),
              ],
            ),
          ),
          if (trailing != null) trailing!,
        ],
      ),
    );
  }
}
