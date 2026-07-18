import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:smart_class/providers/ai_settings_controller.dart';
import 'package:smart_class/services/deepseek_ai_service.dart';
import 'package:smart_class/theme/app_icons.dart';
import 'package:smart_class/theme/app_theme.dart';
import 'package:smart_class/widgets/apple_widgets.dart';

/// DeepSeek API Key 与体验档（约¥100/月优化）
class AiSettingsScreen extends StatefulWidget {
  const AiSettingsScreen({super.key});

  @override
  State<AiSettingsScreen> createState() => _AiSettingsScreenState();
}

class _AiSettingsScreenState extends State<AiSettingsScreen> {
  late final TextEditingController _keyCtrl;
  bool _obscure = true;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    final ai = context.read<AiSettingsController>();
    _keyCtrl = TextEditingController(text: ai.apiKey);
  }

  @override
  void dispose() {
    _keyCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final ai = context.read<AiSettingsController>();
    await ai.setApiKey(_keyCtrl.text);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('已保存')),
    );
  }

  Future<void> _test() async {
    setState(() => _busy = true);
    final ai = context.read<AiSettingsController>();
    try {
      await ai.setApiKey(_keyCtrl.text);
      final ok = await ai.createService().testConnection();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(ok ? '连通成功，DeepSeek 可用' : '连通异常，请检查 Key')),
      );
    } on DeepSeekAiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('测试失败：$e')),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _clear() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('清除 API Key？'),
        content: const Text('清除后需重新填写才能使用 AI。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('清除'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    await context.read<AiSettingsController>().clearApiKey();
    _keyCtrl.clear();
    setState(() {});
  }

  Future<void> _applyPlan(AiExperiencePlan plan) async {
    final ai = context.read<AiSettingsController>();
    await ai.applyExperiencePlan(plan);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('已切换为「${ai.planTitle}」')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final ai = context.watch<AiSettingsController>();

    return Scaffold(
      backgroundColor: AppTheme.bg,
      appBar: PageAppBar(
        title: const Text('AI 助手'),
        actions: [
          TextButton(
            onPressed: _busy ? null : _save,
            child: const Text('保存'),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
        children: [
          Text(
            '当前：${ai.hasApiKey ? ai.maskedApiKey : '未配置'}',
            style: TextStyle(fontSize: 13, color: AppTheme.secondaryLabel),
          ),
          const SizedBox(height: 16),
          Text(
            '体验档位',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: AppTheme.secondaryLabel,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '按月预算约 100 元给对象用：推荐「体验优先」。日常够聪明、回答快，不会无谓烧余额。',
            style: TextStyle(
              fontSize: 13,
              height: 1.4,
              color: AppTheme.tertiaryLabel,
            ),
          ),
          const SizedBox(height: 10),
          for (final plan in AiExperiencePlan.values) ...[
            _PlanTile(
              selected: ai.plan == plan,
              title: switch (plan) {
                AiExperiencePlan.experience100 => '体验优先（约¥100/月）· 推荐',
                AiExperiencePlan.saver => '尽量省钱',
                AiExperiencePlan.fullPower => '满血优先（更费）',
              },
              subtitle: switch (plan) {
                AiExperiencePlan.experience100 =>
                  '日常 Flash；点「深度」才上满血 Pro · 问本班才带数据',
                AiExperiencePlan.saver => '更短回答 · 适合偶尔用',
                AiExperiencePlan.fullPower => '始终 Pro · 更强但更烧钱',
              },
              onTap: _busy ? null : () => _applyPlan(plan),
            ),
            const SizedBox(height: 8),
          ],
          SwitchListTile.adaptive(
            contentPadding: EdgeInsets.zero,
            title: const Text('本轮深度分析'),
            subtitle: Text(
              ai.plan == AiExperiencePlan.experience100
                  ? '打开后临时用满血 Pro+思考，难题更准；日常请关，省下预算给常用。'
                  : '打开后会「思考」再答，更准但更费。日常建议关。',
              style: TextStyle(fontSize: 12, color: AppTheme.tertiaryLabel),
            ),
            value: ai.deepAnalyze,
            onChanged: _busy
                ? null
                : (v) => context.read<AiSettingsController>().setDeepAnalyze(v),
          ),
          const SizedBox(height: 8),
          Text(
            '${ai.runtimeHint}\n配置模型名（档位会覆盖实际调用）：${ai.model}',
            style: TextStyle(fontSize: 12, color: AppTheme.tertiaryLabel),
          ),
          const SizedBox(height: 20),
          Text('DeepSeek API Key', style: TextStyle(color: AppTheme.tertiaryLabel)),
          const SizedBox(height: 8),
          TextField(
            controller: _keyCtrl,
            obscureText: _obscure,
            decoration: InputDecoration(
              hintText: 'sk-…',
              suffixIcon: IconButton(
                tooltip: _obscure ? '显示' : '隐藏',
                onPressed: () => setState(() => _obscure = !_obscure),
                icon: Icon(_obscure ? AppIcons.eyeOff : AppIcons.eye),
              ),
            ),
            autocorrect: false,
            enableSuggestions: false,
            keyboardType: TextInputType.visiblePassword,
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: FilledButton(
                  onPressed: _busy ? null : _test,
                  child: Text(_busy ? '测试中…' : '测试连通'),
                ),
              ),
              const SizedBox(width: 10),
              OutlinedButton(
                onPressed: _busy ? null : _clear,
                child: const Text('清除'),
              ),
            ],
          ),
          const SizedBox(height: 24),
          Text(
            '说明',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: AppTheme.secondaryLabel,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Key 只保存在本机。推荐档「体验优先」：日常又快又省；难题再点「深度」。\n'
            '懒羊羊会自动判断：闲聊不塞班级表；问成绩/课表只带相关数据。\n'
            '150 人班按中等用量，¥100/月通常很宽裕。平台可先充 ¥100，看账单再调。\n'
            '申请与充值：platform.deepseek.com',
            style: TextStyle(
              fontSize: 13,
              height: 1.45,
              color: AppTheme.tertiaryLabel,
            ),
          ),
          const SizedBox(height: 12),
          TextButton.icon(
            onPressed: () async {
              await Clipboard.setData(
                const ClipboardData(
                  text: 'https://platform.deepseek.com/api_keys',
                ),
              );
              if (!context.mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('已复制开放平台链接')),
              );
            },
            icon: Icon(AppIcons.share, size: 18, color: AppTheme.blue),
            label: const Text('复制 API Key 管理页链接'),
          ),
        ],
      ),
    );
  }
}

class _PlanTile extends StatelessWidget {
  const _PlanTile({
    required this.selected,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final bool selected;
  final String title;
  final String subtitle;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? AppTheme.blue.withValues(alpha: 0.08) : AppTheme.surface,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
          child: Row(
            children: [
              Icon(
                selected ? Icons.check_circle : Icons.circle_outlined,
                color: selected ? AppTheme.blue : AppTheme.tertiaryLabel,
                size: 22,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.label,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 12,
                        height: 1.3,
                        color: AppTheme.secondaryLabel,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
