import 'package:flutter/material.dart';
import 'package:smart_class/screens/assistant/ai_assistant_chat_screen.dart';
import 'package:smart_class/theme/app_theme.dart';
import 'package:smart_class/theme/mascot_assets.dart';

/// 可拖动的懒羊羊悬浮钮，点击进入 AI 聊天。
class LazySheepFabOverlay extends StatefulWidget {
  const LazySheepFabOverlay({super.key, required this.child});

  final Widget child;

  @override
  State<LazySheepFabOverlay> createState() => _LazySheepFabOverlayState();
}

class _LazySheepFabOverlayState extends State<LazySheepFabOverlay> {
  // 羊头 + 下方「懒羊羊」小标签
  static const _w = 72.0;
  static const _h = 88.0;
  Offset? _offset;
  Offset _panStart = Offset.zero;
  bool _moved = false;

  void _ensureOffset(Size area) {
    if (_offset != null) return;
    _offset = Offset(
      area.width - _w - 16,
      area.height - _h - 88,
    );
  }

  Future<void> _openChat() async {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const AiAssistantChatScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final area = Size(constraints.maxWidth, constraints.maxHeight);
        _ensureOffset(area);
        var pos = _offset!;
        pos = Offset(
          pos.dx.clamp(8.0, area.width - _w - 8),
          pos.dy.clamp(8.0, area.height - _h - 8),
        );
        _offset = pos;

        return Stack(
          clipBehavior: Clip.none,
          children: [
            Positioned.fill(child: widget.child),
            Positioned(
              left: pos.dx,
              top: pos.dy,
              child: GestureDetector(
                onPanStart: (d) {
                  _panStart = d.globalPosition;
                  _moved = false;
                },
                onPanUpdate: (d) {
                  final dist = (d.globalPosition - _panStart).distance;
                  if (dist > 6) _moved = true;
                  setState(() {
                    _offset = Offset(
                      (pos.dx + d.delta.dx).clamp(8.0, area.width - _w - 8),
                      (pos.dy + d.delta.dy).clamp(8.0, area.height - _h - 8),
                    );
                    pos = _offset!;
                  });
                },
                onPanEnd: (_) {
                  if (!_moved) _openChat();
                },
                child: _SheepBubble(dragging: _moved),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _SheepBubble extends StatelessWidget {
  const _SheepBubble({required this.dragging});
  final bool dragging;

  @override
  Widget build(BuildContext context) {
    return AnimatedScale(
      scale: dragging ? 1.08 : 1,
      duration: const Duration(milliseconds: 120),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: const Color(0xFFFFF8E7),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFFFFB347).withValues(alpha: 0.45),
                  blurRadius: dragging ? 16 : 14,
                  offset: const Offset(0, 5),
                ),
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.12),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
              border: Border.all(color: Colors.white, width: 2.5),
            ),
            clipBehavior: Clip.antiAlias,
            child: Stack(
              fit: StackFit.expand,
              children: [
                Image.asset(
                  MascotAssets.wave,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => const Center(
                    child: Text('🐑', style: TextStyle(fontSize: 32)),
                  ),
                ),
                Positioned(
                  right: 2,
                  bottom: 2,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 5,
                      vertical: 1,
                    ),
                    decoration: BoxDecoration(
                      color: AppTheme.blue,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Text(
                      'AI',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 9,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 4),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.92),
              borderRadius: BorderRadius.circular(10),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.08),
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Text(
              '懒羊羊',
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w600,
                color: AppTheme.secondaryLabel,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
