import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:smart_class/providers/theme_controller.dart';
import 'package:smart_class/screens/assistant/ai_assistant_chat_screen.dart';
import 'package:smart_class/theme/app_theme.dart';
import 'package:smart_class/theme/mascot_assets.dart';

/// 关心 + 懒羊羊角色台词穿插；不用「咩」。
abstract final class LazySheepBubbles {
  static String? _last;

  static List<String> poolFor(DateTime now) {
    final h = now.hour;
    final wd = now.weekday;
    final weekend = wd >= 6;

    // 懒羊羊式台词（懒、怕麻烦、犯困）
    const character = [
      '好麻烦…晚点再说',
      '再躺五分钟',
      '不想动…',
      '有点困了',
      '等等再忙吧',
      '先歇一会儿',
      '好累，瘫一下',
      '能明天做吗',
      '让我发会儿呆',
      '算了，躺平',
    ];

    final care = <String>[];
    if (h >= 5 && h < 8) {
      care.addAll([
        '早上好',
        '记得吃早饭',
        '今天也要顺利',
        '出门别着凉',
        if (wd == 1) '周一慢慢来',
        if (weekend) '周末可以晚点起',
      ]);
    } else if (h >= 8 && h < 11) {
      care.addAll([
        '忙也记得喝水',
        '坐久了站起来走走',
        '眼睛累了看远处',
        '节奏别太赶',
        '保持好心情',
      ]);
    } else if (h >= 11 && h < 13) {
      care.addAll([
        '午饭时间到了',
        '别饿着自己',
        '好好吃一顿',
        '慢慢吃不着急',
        '吃点热乎的',
      ]);
    } else if (h >= 13 && h < 15) {
      care.addAll([
        '午后犯困很正常',
        '眯十分钟也好',
        '喝杯水提提神',
        '别硬撑着',
        '午安',
      ]);
    } else if (h >= 15 && h < 18) {
      care.addAll([
        '下午也稳住',
        '累了就歇口气',
        '再喝口水',
        '今天已经很棒了',
        if (wd == 5) '周五了，松一口气',
      ]);
    } else if (h >= 18 && h < 21) {
      care.addAll([
        '晚饭吃了吗',
        '今天辛苦了',
        '回家路上注意安全',
        '吃点喜欢的吧',
        '晚上别太忙',
        if (weekend) '周末好好歇歇',
      ]);
    } else if (h >= 21 && h < 23) {
      care.addAll([
        '夜深了',
        '该准备休息了',
        '早点睡更舒服',
        '放下手机眯一会儿',
        '做个好梦',
        '晚安',
      ]);
    } else {
      care.addAll([
        '这么晚了该睡了',
        '熬夜对身体不好',
        '先休息吧',
        '盖好被子',
        '明早见',
      ]);
    }

    // 关心与角色台词穿插
    return [...care, ...character];
  }

  static String pick([DateTime? now]) {
    final n = now ?? DateTime.now();
    final pool = [...poolFor(n)];
    if (_last != null && pool.length > 1) pool.remove(_last);
    final s = pool[math.Random().nextInt(pool.length)];
    _last = s;
    return s;
  }
}

/// 可拖动 AI 入口：拥抱贴纸 GIF + 气泡。
class LazySheepFabOverlay extends StatefulWidget {
  const LazySheepFabOverlay({super.key, required this.child});

  final Widget child;

  @override
  State<LazySheepFabOverlay> createState() => _LazySheepFabOverlayState();
}

class _LazySheepFabOverlayState extends State<LazySheepFabOverlay>
    with TickerProviderStateMixin {
  static const _slot = 72.0;
  static const _anim = 60.0;

  late final AnimationController _settle;
  late final AnimationController _bubble;

  Offset? _offset;
  Offset _panStart = Offset.zero;
  bool _moved = false;
  bool _dragging = false;
  String? _bubbleText;
  int _bubbleToken = 0;

  @override
  void initState() {
    super.initState();
    _settle = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 480),
    );
    _bubble = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3400),
    );
    _scheduleBubble(firstDelayMs: 10000);
  }

  @override
  void dispose() {
    _settle.dispose();
    _bubble.dispose();
    super.dispose();
  }

  void _scheduleBubble({int firstDelayMs = 0}) {
    final delay = firstDelayMs > 0 ? firstDelayMs : 10000;
    Future<void>.delayed(Duration(milliseconds: delay), () {
      if (!mounted) return;
      if (_dragging) {
        _scheduleBubble(firstDelayMs: 10000);
        return;
      }
      _showBubble(LazySheepBubbles.pick());
      _scheduleBubble(firstDelayMs: 10000);
    });
  }

  void _showBubble(String text) {
    final token = ++_bubbleToken;
    setState(() => _bubbleText = text);
    _bubble
      ..reset()
      ..forward().whenComplete(() {
        if (!mounted || token != _bubbleToken) return;
        setState(() => _bubbleText = null);
      });
  }

  void _ensureOffset(Size area) {
    if (_offset != null) return;
    _offset = Offset(area.width - _slot - 8, area.height - _slot - 14);
  }

  Offset _clamp(Offset o, Size area) => Offset(
        o.dx.clamp(4.0, area.width - _slot - 4),
        o.dy.clamp(4.0, area.height - _slot - 4),
      );

  Future<void> _openChat() async {
    setState(() => _bubbleText = null);
    if (!mounted) return;
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const AiAssistantChatScreen()),
    );
  }

  Future<void> _snapToEdge(Size area) async {
    final cur = _offset!;
    final mid = area.width / 2;
    final targetX = cur.dx + _slot / 2 < mid ? 4.0 : area.width - _slot - 4;
    final begin = cur;
    final end = _clamp(Offset(targetX, cur.dy), area);
    if ((begin - end).distance < 1) return;

    void tick() {
      if (!mounted) return;
      final t = Curves.easeOutBack.transform(_settle.value.clamp(0.0, 1.0));
      setState(() => _offset = Offset.lerp(begin, end, t)!);
    }

    _settle.addListener(tick);
    _settle.reset();
    await _settle.forward();
    _settle.removeListener(tick);
    if (mounted) setState(() => _offset = end);
  }

  @override
  Widget build(BuildContext context) {
    final fabAsset = context.watch<ThemeController>().fabMascotAsset;

    return LayoutBuilder(
      builder: (context, constraints) {
        final area = Size(constraints.maxWidth, constraints.maxHeight);
        _ensureOffset(area);
        _offset = _clamp(_offset!, area);
        final onRight = _offset!.dx + _slot / 2 >= area.width / 2;

        return Stack(
          clipBehavior: Clip.none,
          children: [
            Positioned.fill(child: widget.child),
            Positioned(
              left: _offset!.dx,
              top: _offset!.dy,
              child: GestureDetector(
                behavior: HitTestBehavior.translucent,
                onPanStart: (d) {
                  _panStart = d.globalPosition;
                  _moved = false;
                  setState(() {
                    _dragging = true;
                    _bubbleText = null;
                  });
                },
                onPanUpdate: (d) {
                  if ((d.globalPosition - _panStart).distance > 8) {
                    _moved = true;
                  }
                  setState(() {
                    _offset = _clamp(
                      Offset(
                        _offset!.dx + d.delta.dx,
                        _offset!.dy + d.delta.dy,
                      ),
                      area,
                    );
                  });
                },
                onPanEnd: (_) async {
                  final wasTap = !_moved;
                  setState(() => _dragging = false);
                  if (wasTap) {
                    await _openChat();
                    return;
                  }
                  await _snapToEdge(area);
                },
                child: AnimatedBuilder(
                  animation: _bubble,
                  builder: (context, _) => _PetSlot(
                    asset: fabAsset,
                    bubbleText: _dragging ? null : _bubbleText,
                    bubbleT: _bubble.value,
                    bubbleOnLeft: onRight,
                    slot: _slot,
                    animSize: _anim,
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _PetSlot extends StatelessWidget {
  const _PetSlot({
    required this.asset,
    required this.bubbleText,
    required this.bubbleT,
    required this.bubbleOnLeft,
    required this.slot,
    required this.animSize,
  });

  final String asset;
  final String? bubbleText;
  final double bubbleT;
  final bool bubbleOnLeft;
  final double slot;
  final double animSize;

  @override
  Widget build(BuildContext context) {
    double bubbleOpacity = 0;
    if (bubbleText != null) {
      if (bubbleT < 0.12) {
        bubbleOpacity = bubbleT / 0.12;
      } else if (bubbleT > 0.78) {
        bubbleOpacity = (1 - bubbleT) / 0.22;
      } else {
        bubbleOpacity = 1;
      }
    }

    final body = Image.asset(
      asset,
      width: animSize,
      height: animSize,
      fit: BoxFit.contain,
      gaplessPlayback: true,
      errorBuilder: (_, __, ___) => Image.asset(
        MascotAssets.fabHug,
        width: animSize,
        height: animSize,
        fit: BoxFit.contain,
      ),
    );

    return SizedBox(
      width: slot,
      height: slot,
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.center,
        children: [
          if (bubbleText != null)
            Positioned(
              top: -4,
              left: bubbleOnLeft ? null : slot - 4,
              right: bubbleOnLeft ? slot - 4 : null,
              child: Opacity(
                opacity: bubbleOpacity.clamp(0.0, 1.0),
                child: Transform.translate(
                  offset: Offset(
                    bubbleOnLeft ? -2 : 2,
                    (1 - bubbleOpacity) * 5,
                  ),
                  child: _SpeechBubble(text: bubbleText!),
                ),
              ),
            ),
          SizedBox(
            width: animSize + 8,
            height: animSize + 8,
            child: Stack(
              clipBehavior: Clip.none,
              alignment: Alignment.center,
              children: [
                body,
                Positioned(
                  right: 0,
                  bottom: 0,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 4,
                      vertical: 1,
                    ),
                    decoration: BoxDecoration(
                      color: AppTheme.blue,
                      borderRadius: BorderRadius.circular(7),
                      border: Border.all(color: Colors.white, width: 1.5),
                    ),
                    child: const Text(
                      'AI',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 7,
                        fontWeight: FontWeight.w800,
                        height: 1.1,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SpeechBubble extends StatelessWidget {
  const _SpeechBubble({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    // Bubble stays light in both themes; text must stay dark for contrast.
    return Container(
      constraints: const BoxConstraints(maxWidth: 120),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.18),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: Color(0xFF3A3A3C),
          height: 1.2,
        ),
      ),
    );
  }
}
