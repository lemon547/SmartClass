import 'dart:async';
import 'dart:math';

import 'package:smart_class/theme/app_icons.dart';
import 'package:flutter/material.dart';

import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:smart_class/models/models.dart';
import 'package:smart_class/providers/class_controller.dart';
import 'package:smart_class/theme/app_theme.dart';
import 'package:smart_class/theme/mascot_assets.dart';
import 'package:smart_class/widgets/apple_widgets.dart';
import 'package:smart_class/widgets/paddi_mascot.dart';

class RollCallScreen extends StatefulWidget {
  const RollCallScreen({super.key});

  @override
  State<RollCallScreen> createState() => _RollCallScreenState();
}

class _RollCallScreenState extends State<RollCallScreen> {
  final _rand = Random();
  final _picked = <String>{};
  bool _avoidRepeat = false;
  Student? _current;
  List<Student> _batchResult = [];
  String _spinName = '';
  bool _spinning = false;
  Timer? _timer;

  List<Student> _pool(ClassController ctrl, {String? group}) {
    var pool = ctrl.students.toList();
    if (group != null) {
      pool = pool.where((s) => s.groupName == group).toList();
    }
    if (_avoidRepeat) {
      pool = pool.where((s) => !_picked.contains(s.id)).toList();
    }
    return pool;
  }

  void _markPicked(Iterable<Student> students) {
    if (!_avoidRepeat) return;
    for (final s in students) {
      _picked.add(s.id);
    }
  }

  String _emptyPoolMessage() {
    if (_avoidRepeat && _picked.isNotEmpty) {
      return '暂无可点学生，请重置已点或关闭不重复';
    }
    return '没有可点名的学生';
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _pick(ClassController ctrl, {String? group}) async {
    final pool = _pool(ctrl, group: group);
    if (pool.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_emptyPoolMessage())),
      );
      return;
    }
    setState(() {
      _spinning = true;
      _batchResult = [];
    });
    var ticks = 0;
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(milliseconds: 60), (t) async {
      ticks++;
      setState(() {
        _spinName = pool[_rand.nextInt(pool.length)].name;
      });
      if (ticks >= 22) {
        t.cancel();
        final chosen = pool[_rand.nextInt(pool.length)];
        setState(() {
          _current = chosen;
          _spinName = chosen.name;
          _spinning = false;
        });
        _markPicked([chosen]);
        await ctrl.recordRollCall(chosen);
      }
    });
  }

  Future<void> _pickMany(ClassController ctrl) async {
    var count = 3;
    final ok = await showModalBottomSheet<bool>(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setModal) {
            return Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text('一次抽多人', style: Theme.of(ctx).textTheme.titleLarge),
                  const SizedBox(height: 8),
                  Text(
                    _avoidRepeat ? '从尚未点过的学生中抽取' : '从全班学生中随机抽取',
                    style: TextStyle(
                      color: AppTheme.tertiaryLabel,
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      const Text('人数'),
                      const Spacer(),
                      IconButton(
                        onPressed: () => setModal(() {
                          if (count > 1) count--;
                        }),
                        icon: const Icon(AppIcons.circleMinus),
                      ),
                      Text('$count',
                          style: const TextStyle(
                              fontSize: 22, fontWeight: FontWeight.w600)),
                      IconButton(
                        onPressed: () => setModal(() {
                          if (count < 20) count++;
                        }),
                        icon: const Icon(AppIcons.circlePlus),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  FilledButton(
                    onPressed: () => Navigator.pop(ctx, true),
                    child: const Text('开始抽取'),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
    if (ok != true || !mounted) return;

    final pool = _pool(ctrl)..shuffle(_rand);
    if (pool.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_emptyPoolMessage())),
      );
      return;
    }
    final n = count.clamp(1, pool.length);
    final chosen = pool.take(n).toList();
    setState(() {
      _batchResult = chosen;
      _current = null;
      _spinName = chosen.map((s) => s.name).join('、');
    });
    _markPicked(chosen);
    for (final s in chosen) {
      await ctrl.recordRollCall(s);
    }
  }

  @override
  Widget build(BuildContext context) {
    final ctrl = context.watch<ClassController>();

    return Scaffold(
      appBar: PageAppBar(
        title: const Text('随机点名'),
        actions: [
          if (_avoidRepeat && _picked.isNotEmpty)
            TextButton(
              onPressed: _spinning
                  ? null
                  : () => setState(() {
                        _picked.clear();
                        _current = null;
                        _batchResult = [];
                        _spinName = '';
                      }),
              child: const Text('重置已点'),
            ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
        children: [
          Container(
            height: 220,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: AppTheme.surface,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Stack(
              alignment: Alignment.center,
              children: [
                if (AppTheme.showMascot && _spinName.isEmpty)
                  const Positioned(
                    right: 8,
                    bottom: 4,
                    child: PaddiMascot(
                      asset: MascotAssets.emote,
                      height: 40,
                    ),
                  ),
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 180),
                  child: Text(
                    _spinName.isEmpty ? '点击下方开始' : _spinName,
                    key: ValueKey(_spinName),
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: _spinName.isEmpty ? 18 : 42,
                      fontWeight: FontWeight.w700,
                      color: _spinName.isEmpty
                          ? AppTheme.tertiaryLabel
                          : AppTheme.label,
                      letterSpacing: -0.8,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          FilledButton(
            onPressed: ctrl.students.isEmpty || _spinning
                ? null
                : () => _pick(ctrl),
            child: Text(_spinning ? '抽取中…' : '开始点名'),
          ),
          const SizedBox(height: 8),
          OutlinedButton(
            onPressed: ctrl.students.isEmpty || _spinning
                ? null
                : () => _pickMany(ctrl),
            child: const Text('一次抽多人'),
          ),
          if (ctrl.groupNames.isNotEmpty) ...[
            const SizedBox(height: 8),
            OutlinedButton(
              onPressed: ctrl.students.isEmpty || _spinning
                  ? null
                  : () async {
                      final g = await showModalBottomSheet<String>(
                        context: context,
                        builder: (ctx) => SafeArea(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Padding(
                                padding: EdgeInsets.all(16),
                                child: Text('按小组点名',
                                    style: TextStyle(
                                        fontSize: 17,
                                        fontWeight: FontWeight.w600)),
                              ),
                              for (final name in ctrl.groupNames)
                                ListTile(
                                  title: Text(name),
                                  onTap: () => Navigator.pop(ctx, name),
                                ),
                            ],
                          ),
                        ),
                      );
                      if (g != null) await _pick(ctrl, group: g);
                    },
              child: const Text('按小组点名'),
            ),
          ],
          const SizedBox(height: 12),
          GroupedSection(
            padding: EdgeInsets.zero,
            children: [
              SwitchListTile.adaptive(
                title: const Text('不重复点名'),
                subtitle: Text(
                  _avoidRepeat ? '同一人只点一次，点完需重置' : '允许重复抽到同一人',
                ),
                value: _avoidRepeat,
                onChanged: _spinning
                    ? null
                    : (v) => setState(() {
                          _avoidRepeat = v;
                          _picked.clear();
                        }),
              ),
            ],
          ),
          if (_batchResult.isNotEmpty) ...[
            const SizedBox(height: 16),
            GroupedSection(
              header: '批量结果',
              padding: EdgeInsets.zero,
              children: [
                for (final s in _batchResult)
                  GroupedTile(
                    title: s.name,
                    subtitle: [
                      if (s.role.isNotEmpty) s.role,
                      if (s.groupName.isNotEmpty) s.groupName,
                    ].isEmpty
                        ? null
                        : [
                            if (s.role.isNotEmpty) s.role,
                            if (s.groupName.isNotEmpty) s.groupName,
                          ].join(' · '),
                    leading: StudentAvatar(name: s.name),
                  ),
              ],
            ),
          ],
          if (_current != null) ...[
            const SizedBox(height: 16),
            GroupedSection(
              header: '点名结果',
              padding: EdgeInsets.zero,
              children: [
                GroupedTile(
                  title: _current!.name,
                  subtitle: _current!.studentNo.isEmpty
                      ? null
                      : '学号 ${_current!.studentNo}',
                  leading: StudentAvatar(name: _current!.name),
                ),
              ],
            ),
          ],
          const SizedBox(height: 20),
          GroupedSection(
            header: '历史记录',
            padding: EdgeInsets.zero,
            children: [
              if (ctrl.rollHistory.isEmpty)
                const ListEmptyPlaceholder(
                  icon: AppIcons.clock,
                  message: '暂无记录',
                  detail: '开始点名后会显示在这里',
                )
              else ...[
                for (final h in ctrl.rollHistory.take(20))
                  GroupedTile(
                    title: (h['name'] as String?) ?? '',
                    subtitle: () {
                      final at = DateTime.tryParse((h['at'] as String?) ?? '');
                      return at == null
                          ? null
                          : DateFormat('M/d HH:mm').format(at);
                    }(),
                    leading: Icon(AppIcons.clock,
                        color: AppTheme.secondaryLabel),
                  ),
                GroupedTile(
                  title: '清空历史',
                  titleColor: AppTheme.destructive,
                  onTap: () => ctrl.clearRollHistory(),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}
