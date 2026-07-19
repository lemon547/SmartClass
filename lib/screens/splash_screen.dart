import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:smart_class/app_info.dart';
import 'package:smart_class/providers/class_controller.dart';
import 'package:smart_class/screens/shell_screen.dart';
import 'package:smart_class/services/share_inbox.dart';
import 'package:smart_class/theme/app_theme.dart';
import 'package:smart_class/widgets/app_brand.dart';

/// 冷启动品牌页：等首屏数据就绪后尽快进入（最短约 0.4s，不再强制 1.6s）
class SplashGate extends StatefulWidget {
  const SplashGate({super.key});

  @override
  State<SplashGate> createState() => _SplashGateState();
}

class _SplashGateState extends State<SplashGate> {
  bool _ready = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _boot());
  }

  Future<void> _boot() async {
    final started = DateTime.now();
    final ctrl = context.read<ClassController>();
    // 尽早挂上分享通道，避免从微信冷启动进 App 时丢失文件。
    await ShareInbox.ensureStarted();

    while (mounted && !ctrl.essentialReady && ctrl.error == null) {
      await Future<void>.delayed(const Duration(milliseconds: 32));
    }

    final elapsed = DateTime.now().difference(started);
    const minShow = Duration(milliseconds: 400);
    if (elapsed < minShow) {
      await Future<void>.delayed(minShow - elapsed);
    }
    if (mounted) setState(() => _ready = true);
  }

  @override
  Widget build(BuildContext context) {
    if (_ready) return const ShellScreen();
    return const SplashScreen();
  }
}

/// 启动页：品牌块光学居中，版本钉在底部
class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFFF2F6FC),
              Color(0xFFFFFFFF),
              Color(0xFFF8FAFD),
            ],
            stops: [0.0, 0.55, 1.0],
          ),
        ),
        child: SafeArea(
          child: Stack(
            children: [
              // 略偏上，避免「中间一坨、上下大空」的 Demo 感
              Align(
                alignment: const Alignment(0, -0.12),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 36),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const AppBrandMark(size: 200),
                      const SizedBox(height: 20),
                      const Text(
                        AppInfo.name,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 32,
                          fontWeight: FontWeight.w700,
                          letterSpacing: -0.6,
                          color: Color(0xFF0B1220),
                          height: 1.15,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        AppInfo.tagline,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 16,
                          height: 1.35,
                          fontWeight: FontWeight.w500,
                          color: AppTheme.blue,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              Positioned(
                left: 0,
                right: 0,
                bottom: 28,
                child: Text(
                  AppInfo.versionLabel,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 13,
                    color: AppTheme.quaternaryLabel,
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
