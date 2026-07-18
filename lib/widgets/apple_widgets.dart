import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
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
    this.subtitleColor,
  });

  final String title;
  final String? subtitle;
  final Widget? leading;
  final Widget? trailing;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final Color? titleColor;
  final Color? subtitleColor;

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
                          color: subtitleColor ?? AppTheme.tertiaryLabel,
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
    this.focusNode,
  });

  final TextEditingController controller;
  final String hint;
  final ValueChanged<String>? onChanged;
  final FocusNode? focusNode;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
      child: TextField(
        controller: controller,
        focusNode: focusNode,
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

/// 分组列表空状态：居中图标 + 主文案 + 可选副文案
class ListEmptyPlaceholder extends StatelessWidget {
  const ListEmptyPlaceholder({
    super.key,
    required this.message,
    this.detail,
    this.icon = AppIcons.clock,
  });

  final String message;
  final String? detail;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 36, horizontal: 24),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 44, color: AppTheme.quaternaryLabel),
            const SizedBox(height: 12),
            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 17,
                color: AppTheme.secondaryLabel,
                letterSpacing: -0.41,
              ),
            ),
            if (detail != null) ...[
              const SizedBox(height: 4),
              Text(
                detail!,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 13,
                  color: AppTheme.tertiaryLabel,
                  height: 1.35,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class StudentAvatar extends StatelessWidget {
  const StudentAvatar({
    super.key,
    required this.name,
    this.gender = '',
    this.size = 36,
  });

  final String name;
  final String gender;
  final double size;

  @override
  Widget build(BuildContext context) {
    final letter = name.isEmpty ? '?' : name.substring(0, 1);
    final bg = switch (gender) {
      '男' => const Color(0xFFD6EBFF),
      '女' => const Color(0xFFFFD6E0),
      _ => AppTheme.fill,
    };
    final fg = switch (gender) {
      '男' => const Color(0xFF007AFF),
      '女' => const Color(0xFFFF2D55),
      _ => AppTheme.secondaryLabel.withValues(alpha: 0.7),
    };
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: bg,
        shape: BoxShape.circle,
      ),
      child: Text(
        letter,
        style: TextStyle(
          fontSize: size * 0.38,
          fontWeight: FontWeight.w600,
          color: fg,
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

/// 积分榜名次标
class RankBadge extends StatelessWidget {
  const RankBadge({super.key, required this.rank});

  final int rank;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 28,
      height: 28,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: AppTheme.fill,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        '$rank',
        style: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: AppTheme.secondaryLabel,
        ),
      ),
    );
  }
}

/// Cupertino 风格确认删除
Future<bool> confirmAppleDelete(
  BuildContext context, {
  required String title,
  String? message,
}) async {
  final ok = await showCupertinoDialog<bool>(
    context: context,
    builder: (ctx) => CupertinoAlertDialog(
      title: Text(title),
      content: message == null ? null : Text(message),
      actions: [
        CupertinoDialogAction(
          onPressed: () => Navigator.pop(ctx, false),
          child: const Text('取消'),
        ),
        CupertinoDialogAction(
          isDestructiveAction: true,
          onPressed: () => Navigator.pop(ctx, true),
          child: const Text('删除'),
        ),
      ],
    ),
  );
  return ok ?? false;
}

/// iOS 列表左滑：露出圆角「删除」按钮，须点按才删；不可滑动即删。
/// 用 [ClipRect] 裁切左滑内容，避免标题飘出卡片。
class AppleDeleteSlidable extends StatelessWidget {
  const AppleDeleteSlidable({
    super.key,
    required this.itemKey,
    required this.child,
    required this.onDelete,
    this.confirmTitle,
    this.confirmMessage,
    this.groupTag = 'apple-delete',
  });

  final Key itemKey;
  final Widget child;
  final Future<void> Function() onDelete;
  final String? confirmTitle;
  final String? confirmMessage;
  final Object? groupTag;

  Future<void> _handleDelete(BuildContext ctx) async {
    if (confirmTitle != null) {
      final ok = await confirmAppleDelete(
        ctx,
        title: confirmTitle!,
        message: confirmMessage,
      );
      if (!ok) return;
    }
    await onDelete();
  }

  @override
  Widget build(BuildContext context) {
    return ClipRect(
      child: Slidable(
        key: itemKey,
        groupTag: groupTag,
        endActionPane: ActionPane(
          motion: const BehindMotion(),
          extentRatio: 0.2,
          dragDismissible: false,
          children: [
            CustomSlidableAction(
              onPressed: _handleDelete,
              backgroundColor: Colors.transparent,
              padding: const EdgeInsets.fromLTRB(6, 8, 12, 8),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: AppTheme.destructive,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Center(
                  child: Text(
                    '删除',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                      letterSpacing: -0.2,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
        child: child,
      ),
    );
  }
}

