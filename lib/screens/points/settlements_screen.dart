import 'dart:convert';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:smart_class/providers/class_controller.dart';
import 'package:smart_class/theme/app_icons.dart';
import 'package:smart_class/theme/app_theme.dart';
import 'package:smart_class/widgets/apple_widgets.dart';

class SettlementsScreen extends StatelessWidget {
  const SettlementsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final ctrl = context.watch<ClassController>();

    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.only(bottom: 28),
          children: [
            LargeTitle(
              '结算记录',
              trailing: IconButton(
                onPressed: () => Navigator.pop(context),
                icon: Icon(AppIcons.close, color: AppTheme.blue),
              ),
            ),
            GroupedSection(
              header: '历史阶段',
              footer: '结算会保存当时排行快照，并将所有积分清零重新开始。',
              children: [
                if (ctrl.settlements.isEmpty)
                  Padding(
                    padding: EdgeInsets.all(18),
                    child: Text('暂无结算',
                        style: TextStyle(color: AppTheme.tertiaryLabel)),
                  )
                else
                  for (final s in ctrl.settlements)
                    GroupedTile(
                      title: s.name,
                      subtitle:
                          DateFormat('yyyy/M/d HH:mm').format(s.createdAt),
                      onTap: () => _showSnapshot(context, s.name, s.snapshot),
                      trailing: IconButton(
                        visualDensity: VisualDensity.compact,
                        onPressed: () => _delete(context, s.id),
                        icon: Icon(AppIcons.trash,
                            color: AppTheme.destructive, size: 20),
                      ),
                    ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _delete(BuildContext context, String id) async {
    final ok = await showCupertinoDialog<bool>(
      context: context,
      builder: (ctx) => CupertinoAlertDialog(
        title: const Text('删除这条结算？'),
        content: const Text('仅删除历史记录，不影响当前积分。'),
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
    if (ok == true && context.mounted) {
      await context.read<ClassController>().deleteSettlement(id);
    }
  }

  void _showSnapshot(BuildContext context, String name, String snapshot) {
    List rows = [];
    try {
      rows = jsonDecode(snapshot) as List;
    } catch (_) {}

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(name, style: Theme.of(ctx).textTheme.titleLarge),
                const SizedBox(height: 12),
                if (rows.isEmpty)
                  Text('无快照数据',
                      style: TextStyle(color: AppTheme.tertiaryLabel))
                else
                  Flexible(
                    child: ListView.separated(
                      shrinkWrap: true,
                      itemCount: rows.length.clamp(0, 50),
                      separatorBuilder: (_, __) => const Divider(height: 1),
                      itemBuilder: (_, i) {
                        final row = Map<String, dynamic>.from(rows[i] as Map);
                        return ListTile(
                          contentPadding: EdgeInsets.zero,
                          title: Text('${i + 1}.  ${row['name'] ?? ''}'),
                          subtitle: Text('${row['rank'] ?? ''}'),
                          trailing: Text('${row['points'] ?? 0}',
                              style: const TextStyle(fontSize: 17)),
                        );
                      },
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}
