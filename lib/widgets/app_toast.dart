import 'package:flutter/material.dart';
import 'package:smart_class/theme/app_icons.dart';
import 'package:smart_class/theme/app_theme.dart';

enum AppToastKind { neutral, success, error }

/// 全局轻提示：居中胶囊，避免贴底黑条
abstract final class AppToast {
  static void show(
    BuildContext context,
    String message, {
    AppToastKind kind = AppToastKind.neutral,
    Duration duration = const Duration(milliseconds: 2200),
  }) {
    if (!context.mounted) return;
    showOn(
      ScaffoldMessenger.of(context),
      message,
      kind: kind,
      duration: duration,
    );
  }

  /// 用于先 pop 再提示：在关闭页面前取出 messenger
  static void showOn(
    ScaffoldMessengerState messenger,
    String message, {
    AppToastKind kind = AppToastKind.neutral,
    Duration duration = const Duration(milliseconds: 2200),
  }) {
    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(
      SnackBar(
        duration: duration,
        behavior: SnackBarBehavior.floating,
        elevation: 0,
        backgroundColor: Colors.transparent,
        padding: EdgeInsets.zero,
        margin: const EdgeInsets.fromLTRB(20, 0, 20, 100),
        content: Center(
          child: _ToastBody(message: message, kind: kind),
        ),
      ),
    );
  }

  static void success(BuildContext context, String message) =>
      show(context, message, kind: AppToastKind.success);

  static void error(BuildContext context, String message) =>
      show(context, message, kind: AppToastKind.error);

  static void successOn(ScaffoldMessengerState messenger, String message) =>
      showOn(messenger, message, kind: AppToastKind.success);

  static void errorOn(ScaffoldMessengerState messenger, String message) =>
      showOn(messenger, message, kind: AppToastKind.error);
}

class _ToastBody extends StatelessWidget {
  const _ToastBody({required this.message, required this.kind});

  final String message;
  final AppToastKind kind;

  @override
  Widget build(BuildContext context) {
    final (icon, tint) = switch (kind) {
      AppToastKind.success => (AppIcons.circleCheck, const Color(0xFF34C759)),
      AppToastKind.error => (AppIcons.alert, AppTheme.destructive),
      AppToastKind.neutral => (null, null),
    };

    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 320),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: AppTheme.isDark
              ? const Color(0xF22C2C2E)
              : const Color(0xE61C1C1E),
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.18),
              blurRadius: 20,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Padding(
          padding: EdgeInsets.fromLTRB(
            icon != null ? 14 : 18,
            12,
            18,
            12,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icon != null) ...[
                Icon(icon, size: 18, color: tint),
                const SizedBox(width: 8),
              ],
              Flexible(
                child: Text(
                  message,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: Colors.white,
                    height: 1.25,
                    letterSpacing: -0.1,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
