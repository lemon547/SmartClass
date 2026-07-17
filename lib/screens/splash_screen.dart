import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:smart_class/app_info.dart';
import 'package:smart_class/providers/class_controller.dart';
import 'package:smart_class/screens/shell_screen.dart';
import 'package:smart_class/theme/app_icons.dart';
import 'package:smart_class/theme/app_theme.dart';

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

/// 启动页：品牌块绝对居中，版本钉在底部
class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Stack(
          children: [
            Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 40),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      AppIcons.logo,
                      size: 72,
                      color: const Color(0xFF111111),
                    ),
                    const SizedBox(height: 20),
                    const Text(
                      AppInfo.name,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 30,
                        fontWeight: FontWeight.w700,
                        letterSpacing: -0.5,
                        color: Color(0xFF111111),
                        height: 1.2,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      AppInfo.tagline,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 15,
                        height: 1.4,
                        color: AppTheme.secondaryLabel,
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
    );
  }
}
