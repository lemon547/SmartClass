import 'package:flutter/material.dart';
import 'package:smart_class/theme/app_icons.dart';
import 'package:smart_class/theme/app_theme.dart';

/// 子页面 AppBar：可返回时自动显示返回按钮
class PageAppBar extends StatelessWidget implements PreferredSizeWidget {
  const PageAppBar({
    super.key,
    required this.title,
    this.actions,
    this.bottom,
    this.centerTitle,
  });

  final Widget title;
  final List<Widget>? actions;
  final PreferredSizeWidget? bottom;
  final bool? centerTitle;

  @override
  Size get preferredSize =>
      Size.fromHeight(kToolbarHeight + (bottom?.preferredSize.height ?? 0));

  @override
  Widget build(BuildContext context) {
    final canPop = Navigator.canPop(context);
    return AppBar(
      automaticallyImplyLeading: false,
      leading: canPop
          ? IconButton(
              icon: const Icon(AppIcons.chevronLeft),
              onPressed: () => Navigator.maybePop(context),
              tooltip: '返回',
            )
          : null,
      title: title,
      actions: actions,
      bottom: bottom,
      centerTitle: centerTitle,
    );
  }
}

class LargeTitle extends StatelessWidget {
  const LargeTitle(
    this.title, {
    super.key,
    this.trailing,
    this.showLogo = false,
    this.showBack,
  });

  final String title;
  final Widget? trailing;
  final bool showLogo;
  /// 为 null 时：能 pop 则显示返回
  final bool? showBack;

  @override
  Widget build(BuildContext context) {
    final canPop = showBack ?? Navigator.canPop(context);
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (canPop)
          Padding(
            padding: const EdgeInsets.only(left: 4, right: 12, top: 2),
            child: Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                style: TextButton.styleFrom(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                onPressed: () => Navigator.maybePop(context),
                icon: Icon(AppIcons.chevronLeft, color: AppTheme.blue, size: 22),
                label: Text(
                  '返回',
                  style: TextStyle(
                    fontSize: 17,
                    color: AppTheme.blue,
                  ),
                ),
              ),
            ),
          ),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 4, 12, 8),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              if (showLogo) ...[
                Padding(
                  padding: const EdgeInsets.only(bottom: 2, right: 10),
                  child: Icon(AppIcons.logo, size: 32, color: AppTheme.label),
                ),
              ],
              Expanded(
                child:
                    Text(title, style: Theme.of(context).textTheme.displayLarge),
              ),
              if (trailing != null) trailing!,
            ],
          ),
        ),
      ],
    );
  }
}

class GroupedSection extends StatelessWidget {
  const GroupedSection({
    super.key,
    this.header,
    this.headerTrailing,
    this.footer,
    required this.children,
    this.padding = const EdgeInsets.symmetric(horizontal: 16),
  });

  final String? header;
  final String? headerTrailing;
  final String? footer;
  final List<Widget> children;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final hairline = 1 / MediaQuery.devicePixelRatioOf(context);
    return Padding(
      padding: padding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (header != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 6, 16, 6),
              child: Row(
                children: [
                  Text(
                    header!,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w400,
                      color: AppTheme.tertiaryLabel,
                      letterSpacing: -0.08,
                    ),
                  ),
                  if (headerTrailing != null) ...[
                    const SizedBox(width: 8),
                    Text(
                      headerTrailing!,
                      style: TextStyle(
                        fontSize: 13,
                        color: AppTheme.tertiaryLabel,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          DecoratedBox(
            decoration: BoxDecoration(
              color: AppTheme.surface,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Column(
              children: [
                for (var i = 0; i < children.length; i++) ...[
                  if (i > 0)
                    Container(
                      margin: const EdgeInsets.only(left: 16),
                      height: hairline,
                      color: AppTheme.separator,
                    ),
                  children[i],
                ],
              ],
            ),
          ),
          if (footer != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 6, 16, 0),
              child: Text(
                footer!,
                style: TextStyle(
                  fontSize: 13,
                  color: AppTheme.tertiaryLabel,
                  height: 1.3,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class GroupedTile extends StatelessWidget {
  const GroupedTile({
    super.key,
    required this.title,
    this.subtitle,
    this.leading,
    this.trailing,
    this.onTap,
    this.onLongPress,
    this.titleColor,
  });

  final String title;
  final String? subtitle;
  final Widget? leading;
  final Widget? trailing;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final Color? titleColor;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        onLongPress: onLongPress,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
          child: Row(
            children: [
              if (leading != null) ...[
                leading!,
                const SizedBox(width: 12),
              ],
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 17,
                        letterSpacing: -0.41,
                        color: titleColor ?? AppTheme.label,
                      ),
                    ),
                    if (subtitle != null) ...[
                      const SizedBox(height: 1),
                      Text(
                        subtitle!,
                        style: TextStyle(
                          fontSize: 15,
                          color: AppTheme.tertiaryLabel,
                          letterSpacing: -0.24,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              if (trailing != null)
                trailing!
              else if (onTap != null)
                Icon(AppIcons.chevronRight,
                    size: 20, color: AppTheme.quaternaryLabel),
            ],
          ),
        ),
      ),
    );
  }
}

class SearchField extends StatelessWidget {
  const SearchField({
    super.key,
    required this.controller,
    this.hint = '搜索',
    this.onChanged,
  });

  final TextEditingController controller;
  final String hint;
  final ValueChanged<String>? onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
      child: TextField(
        controller: controller,
        onChanged: onChanged,
        textInputAction: TextInputAction.search,
        decoration: InputDecoration(
          hintText: hint,
          prefixIcon: Icon(AppIcons.search, color: AppTheme.tertiaryLabel),
          suffixIcon: controller.text.isEmpty
              ? null
              : IconButton(
                  icon: Icon(AppIcons.close, color: AppTheme.quaternaryLabel),
                  onPressed: () {
                    controller.clear();
                    onChanged?.call('');
                  },
                ),
        ),
      ),
    );
  }
}

class StudentAvatar extends StatelessWidget {
  const StudentAvatar({super.key, required this.name, this.size = 36});

  final String name;
  final double size;

  @override
  Widget build(BuildContext context) {
    final letter = name.isEmpty ? '?' : name.substring(0, 1);
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: AppTheme.fill,
        shape: BoxShape.circle,
      ),
      child: Text(
        letter,
        style: TextStyle(
          fontSize: size * 0.38,
          fontWeight: FontWeight.w600,
          color: AppTheme.secondaryLabel.withValues(alpha: 0.7),
        ),
      ),
    );
  }
}

class QuietStat extends StatelessWidget {
  const QuietStat({
    super.key,
    required this.label,
    required this.value,
    this.center = false,
    this.onTap,
  });

  final String label;
  final String value;
  final bool center;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final child = Column(
      crossAxisAlignment:
          center ? CrossAxisAlignment.center : CrossAxisAlignment.start,
      children: [
        Text(
          value,
          style: TextStyle(
            fontSize: 26,
            fontWeight: FontWeight.w600,
            letterSpacing: -0.6,
            color: AppTheme.label,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 13,
            color: AppTheme.tertiaryLabel,
          ),
        ),
      ],
    );
    return Expanded(
      child: onTap == null
          ? child
          : InkWell(
              onTap: onTap,
              borderRadius: BorderRadius.circular(8),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: child,
              ),
            ),
    );
  }
}

/// 积分榜名次标（常见排行榜：金银铜）
class RankBadge extends StatelessWidget {
  const RankBadge({super.key, required this.rank});

  final int rank;

  @override
  Widget build(BuildContext context) {
    final Color bg;
    final Color fg;
    if (rank == 1) {
      bg = const Color(0xFFFFF3C4);
      fg = const Color(0xFFB8860B);
    } else if (rank == 2) {
      bg = const Color(0xFFE8E8ED);
      fg = const Color(0xFF636366);
    } else if (rank == 3) {
      bg = const Color(0xFFFFE8D6);
      fg = const Color(0xFFA85A2E);
    } else {
      bg = AppTheme.fill;
      fg = AppTheme.tertiaryLabel;
    }
    return Container(
      width: 28,
      height: 28,
      alignment: Alignment.center,
      decoration: BoxDecoration(color: bg, shape: BoxShape.circle),
      child: Text(
        '$rank',
        style: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: fg,
        ),
      ),
    );
  }
}

