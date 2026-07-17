import 'package:flutter/material.dart';
import 'package:smart_class/app_info.dart';
import 'package:smart_class/theme/app_icons.dart';
import 'package:smart_class/theme/app_theme.dart';

/// 透明学士帽 logo（无灰底）
class AppLogo extends StatelessWidget {
  const AppLogo({super.key, this.size = 72});

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
        filterQuality: FilterQuality.high,
        color: AppTheme.label,
        colorBlendMode: BlendMode.srcIn,
        errorBuilder: (_, __, ___) => Icon(
          AppIcons.logo,
          size: size * 0.72,
          color: AppTheme.label,
        ),
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
      padding: const EdgeInsets.fromLTRB(20, 8, 16, 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.only(top: 2),
            child: AppLogo(size: 44),
          ),
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
