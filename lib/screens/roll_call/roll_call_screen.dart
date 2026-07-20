import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:smart_class/models/models.dart';
import 'package:smart_class/providers/class_controller.dart';
import 'package:smart_class/theme/app_icons.dart';
import 'package:smart_class/theme/app_theme.dart';
import 'package:smart_class/theme/mascot_assets.dart';
import 'package:smart_class/widgets/apple_widgets.dart';
import 'package:smart_class/widgets/class_switcher_sheet.dart';
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
  String? _lastClassId;

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

  void _resetSession() {
    _picked.clear();
    _current = null;
    _batchResult = [];
    _spinName = '';
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
      showDragHandle: true,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setModal) {
            return Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
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
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      const Text('人数', style: TextStyle(fontSize: 15)),
                      const Spacer(),
                      IconButton.filledTonal(
                        onPressed: count <= 2
                            ? null
                            : () => setModal(() => count--),
                        icon: const Icon(Icons.remove, size: 18),
                      ),
                      SizedBox(
                        width: 40,
                        child: Text(
                          '$count',
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      IconButton.filledTonal(
                        onPressed: count >= 12
                            ? null
                            : () => setModal(() => count++),
                        icon: const Icon(Icons.add, size: 18),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  FilledButton(
                    onPressed: () => Navigator.pop(ctx, true),
                    child: const Text('开始抽取'),
                  ),
                  TextButton(
                    onPressed: () => Navigator.pop(ctx, false),
                    child: const Text('取消'),
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

  Future<void> _pickByGroup(ClassController ctrl) async {
    final g = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(16, 8, 16, 8),
              child: Text(
                '按小组点名',
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
              ),
            ),
            for (final name in ctrl.groupNames)
              ListTile(
                title: Text(name),
                trailing: const Icon(AppIcons.chevronRight, size: 18),
                onTap: () => Navigator.pop(ctx, name),
              ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
    if (g != null) await _pick(ctrl, group: g);
  }

  @override
  Widget build(BuildContext context) {
    final ctrl = context.watch<ClassController>();
    final classId = ctrl.currentClass?.id;
    if (classId != _lastClassId) {
      _lastClassId = classId;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        setState(_resetSession);
      });
    }

    final classTitle = ctrl.currentClass?.displayTitle ?? '未选班级';
    final studentCount = ctrl.students.length;
    final remain = _avoidRepeat
        ? (_pool(ctrl).length)
        : studentCount;

    final canAct = studentCount > 0 && !_spinning;
    final btnStyle = FilledButton.styleFrom(
      minimumSize: const Size.fromHeight(50),
      shape: const StadiumBorder(),
      textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
    );
    final outlineStyle = OutlinedButton.styleFrom(
      minimumSize: const Size.fromHeight(46),
      shape: const StadiumBorder(),
      side: BorderSide(color: AppTheme.blue.withValues(alpha: 0.45)),
      foregroundColor: AppTheme.blue,
      textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
    );

    return Scaffold(
      backgroundColor: AppTheme.bg,
      appBar: PageAppBar(
        title: const Text('随机点名'),
        actions: [
          if (_avoidRepeat && _picked.isNotEmpty)
            TextButton(
              onPressed: _spinning ? null : () => setState(_resetSession),
              child: const Text('重置已点'),
            ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
        children: [
          // 选择班级
          _RollCard(
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: BorderRadius.circular(16),
                onTap: _spinning
                    ? null
                    : () async {
                        await showClassSwitcherSheet(context);
                        if (mounted) setState(_resetSession);
                      },
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(14, 12, 10, 12),
                  child: Row(
                    children: [
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: AppTheme.blue.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(
                          AppIcons.users,
                          size: 20,
                          color: AppTheme.blue,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '选择班级',
                              style: TextStyle(
                                fontSize: 12,
                                color: AppTheme.tertiaryLabel,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              classTitle,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Text(
                        studentCount == 0 ? '去选择' : '$studentCount 人',
                        style: TextStyle(
                          fontSize: 13,
                          color: studentCount == 0
                              ? AppTheme.blue
                              : AppTheme.secondaryLabel,
                          fontWeight: studentCount == 0
                              ? FontWeight.w600
                              : FontWeight.w400,
                        ),
                      ),
                      Icon(
                        AppIcons.chevronRight,
                        size: 18,
                        color: AppTheme.tertiaryLabel,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 14),

          // 主展示区
          _RollCard(
            child: Container(
              height: 210,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    AppTheme.blue.withValues(alpha: 0.07),
                    AppTheme.surface,
                    AppTheme.blue.withValues(alpha: 0.04),
                  ],
                ),
              ),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  if (AppTheme.showMascot && _spinName.isEmpty)
                    const Positioned(
                      right: 10,
                      bottom: 6,
                      child: PaddiMascot(
                        asset: MascotAssets.emote,
                        height: 40,
                      ),
                    ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 180),
                      child: Column(
                        key: ValueKey('$_spinName|$_spinning'),
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            _spinName.isEmpty ? '点击下方开始' : _spinName,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: _spinName.isEmpty ? 16 : 42,
                              fontWeight: FontWeight.w700,
                              color: _spinName.isEmpty
                                  ? AppTheme.tertiaryLabel
                                  : AppTheme.label,
                              letterSpacing: -0.8,
                              height: 1.15,
                            ),
                          ),
                          if (_spinning) ...[
                            const SizedBox(height: 12),
                            Text(
                              '抽取中…',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
                                color: AppTheme.blue,
                              ),
                            ),
                          ] else if (_avoidRepeat && studentCount > 0) ...[
                            const SizedBox(height: 10),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: AppTheme.blue.withValues(alpha: 0.08),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Text(
                                '剩余 $remain / $studentCount',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                  color: AppTheme.blue,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 18),

          FilledButton(
            style: btnStyle,
            onPressed: canAct ? () => _pick(ctrl) : null,
            child: Text(_spinning ? '抽取中…' : '开始点名'),
          ),
          const SizedBox(height: 10),
          OutlinedButton(
            style: outlineStyle,
            onPressed: canAct ? () => _pickMany(ctrl) : null,
            child: const Text('一次抽多人'),
          ),
          if (ctrl.groupNames.isNotEmpty) ...[
            const SizedBox(height: 10),
            OutlinedButton(
              style: outlineStyle,
              onPressed: canAct ? () => _pickByGroup(ctrl) : null,
              child: const Text('按小组点名'),
            ),
          ],
          const SizedBox(height: 14),

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
                    leading: Icon(
                      AppIcons.clock,
                      color: AppTheme.secondaryLabel,
                    ),
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

class _RollCard extends StatelessWidget {
  const _RollCard({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: child,
    );
  }
}
