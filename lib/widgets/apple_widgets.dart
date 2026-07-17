import 'package:flutter/material.dart';
import 'package:smart_class/theme/app_icons.dart';
import 'package:smart_class/theme/app_theme.dart';
import 'package:smart_class/theme/mascot_assets.dart';
import 'package:smart_class/widgets/paddi_mascot.dart';

class LargeTitle extends StatelessWidget {
  const LargeTitle(this.title, {super.key, this.trailing, this.showLogo = false});

  final String title;
  final Widget? trailing;
  final bool showLogo;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 4, 12, 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (showLogo) ...[
            Padding(
              padding: const EdgeInsets.only(bottom: 2, right: 10),
              child: AppTheme.showMascot
                  ? const PaddiMascot(
                      asset: MascotAssets.icon,
                      height: 40,
                    )
                  : Icon(AppIcons.logo, size: 32, color: AppTheme.label),
            ),
          ],
          Expanded(
            child: Text(title, style: Theme.of(context).textTheme.displayLarge),
          ),
          if (trailing != null) trailing!,
        ],
      ),
    );
  }
}

class GroupedSection extends StatelessWidget {
  const GroupedSection({
    super.key,
    this.header,
    this.footer,
    required this.children,
    this.padding = const EdgeInsets.symmetric(horizontal: 16),
  });

  final String? header;
  final String? footer;
  final List<Widget> children;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: padding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (header != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 6, 16, 6),
              child: Text(
                header!.toUpperCase(),
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w400,
                  color: AppTheme.tertiaryLabel,
                  letterSpacing: -0.08,
                ),
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
                    Divider(
                      height: 0.33,
                      thickness: 0.33,
                      indent: 16,
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
  const QuietStat({super.key, required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            value,
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.w600,
              letterSpacing: -0.6,
              color: AppTheme.label,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: TextStyle(
              fontSize: 13,
              color: AppTheme.tertiaryLabel,
            ),
          ),
        ],
      ),
    );
  }
}
