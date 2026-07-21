import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:smart_class/theme/app_theme.dart';

/// 数据图表卡片容器（跟分组列表风格一致）
class ChartCard extends StatelessWidget {
  const ChartCard({
    super.key,
    required this.title,
    required this.child,
    this.height = 220,
    this.footer,
  });

  final String title;
  final Widget child;
  final double height;
  final String? footer;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      child: Container(
        decoration: BoxDecoration(
          color: AppTheme.surface,
          borderRadius: BorderRadius.circular(12),
        ),
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              title,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AppTheme.tertiaryLabel,
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(height: height, child: child),
            if (footer != null) ...[
              const SizedBox(height: 8),
              Text(
                footer!,
                style: TextStyle(fontSize: 12, color: AppTheme.quaternaryLabel),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class ChartBarItem {
  const ChartBarItem({
    required this.label,
    required this.value,
    this.color,
  });

  final String label;
  final double value;
  final Color? color;
}

class ChartSlice {
  const ChartSlice({
    required this.label,
    required this.value,
    required this.color,
  });

  final String label;
  final double value;
  final Color color;
}

/// 纵向柱状图（科目均分、及格率等）
class SimpleBarChart extends StatelessWidget {
  const SimpleBarChart({
    super.key,
    required this.items,
    this.maxY,
    this.valueSuffix = '',
    this.showAsPercent = false,
  });

  final List<ChartBarItem> items;
  final double? maxY;
  final String valueSuffix;
  final bool showAsPercent;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return Center(
        child: Text('暂无数据', style: TextStyle(color: AppTheme.tertiaryLabel)),
      );
    }

    final peak = maxY ??
        items.map((e) => e.value).fold<double>(0, (a, b) => a > b ? a : b);
    final yMax = peak <= 0 ? 1.0 : peak * 1.15;
    final rotate = items.length > 5;

    return BarChart(
      BarChartData(
        maxY: yMax,
        minY: 0,
        alignment: BarChartAlignment.spaceAround,
        barTouchData: BarTouchData(
          enabled: true,
          touchTooltipData: BarTouchTooltipData(
            getTooltipColor: (_) => AppTheme.label.withValues(alpha: 0.85),
            getTooltipItem: (group, groupIndex, rod, rodIndex) {
              final item = items[group.x.toInt()];
              final text = showAsPercent
                  ? '${item.label}\n${item.value.toStringAsFixed(0)}%'
                  : '${item.label}\n${_fmt(item.value)}$valueSuffix';
              return BarTooltipItem(
                text,
                const TextStyle(color: Colors.white, fontSize: 12),
              );
            },
          ),
        ),
        titlesData: FlTitlesData(
          topTitles:
              const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles:
              const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 36,
              getTitlesWidget: (v, _) {
                if (v <= 0 || v >= yMax) return const SizedBox.shrink();
                return Text(
                  showAsPercent ? '${v.toInt()}' : _fmt(v),
                  style: TextStyle(
                    fontSize: 10,
                    color: AppTheme.tertiaryLabel,
                  ),
                );
              },
            ),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: rotate ? 42 : 28,
              getTitlesWidget: (v, meta) {
                final i = v.toInt();
                if (i < 0 || i >= items.length) {
                  return const SizedBox.shrink();
                }
                final label = items[i].label;
                final short = label.length > 3 ? label.substring(0, 2) : label;
                final child = Text(
                  short,
                  style: TextStyle(
                    fontSize: 11,
                    color: AppTheme.secondaryLabel,
                  ),
                );
                return SideTitleWidget(
                  meta: meta,
                  angle: rotate ? -0.55 : 0,
                  child: child,
                );
              },
            ),
          ),
        ),
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          getDrawingHorizontalLine: (_) => FlLine(
            color: AppTheme.separator.withValues(alpha: 0.5),
            strokeWidth: 1,
          ),
        ),
        borderData: FlBorderData(show: false),
        barGroups: [
          for (var i = 0; i < items.length; i++)
            BarChartGroupData(
              x: i,
              barRods: [
                BarChartRodData(
                  toY: items[i].value,
                  width: items.length > 8 ? 10 : 16,
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(6),
                  ),
                  color: items[i].color ?? AppTheme.blue,
                  gradient: LinearGradient(
                    colors: [
                      (items[i].color ?? AppTheme.blue).withValues(alpha: 0.55),
                      (items[i].color ?? AppTheme.blue),
                    ],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }

  static String _fmt(double v) =>
      v == v.roundToDouble() ? '${v.round()}' : v.toStringAsFixed(1);
}

/// 横向柱状图（排行 Top N）
class HorizontalRankChart extends StatelessWidget {
  const HorizontalRankChart({
    super.key,
    required this.items,
  });

  final List<ChartBarItem> items;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return Center(
        child: Text('暂无数据', style: TextStyle(color: AppTheme.tertiaryLabel)),
      );
    }
    final maxV =
        items.map((e) => e.value).fold<double>(0, (a, b) => a > b ? a : b);
    final safeMax = maxV <= 0 ? 1.0 : maxV;

    return Column(
      children: [
        for (var i = 0; i < items.length; i++) ...[
          if (i > 0) const SizedBox(height: 10),
          _RankBarRow(
            rank: i + 1,
            label: items[i].label,
            value: items[i].value,
            ratio: items[i].value / safeMax,
            color: items[i].color ?? _rankColor(i),
          ),
        ],
      ],
    );
  }

  static Color _rankColor(int i) {
    if (i == 0) return const Color(0xFFFF9500);
    if (i == 1) return const Color(0xFF8E8E93);
    if (i == 2) return const Color(0xFFCD7F32);
    return AppTheme.blue;
  }
}

class _RankBarRow extends StatelessWidget {
  const _RankBarRow({
    required this.rank,
    required this.label,
    required this.value,
    required this.ratio,
    required this.color,
  });

  final int rank;
  final String label;
  final double value;
  final double ratio;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        SizedBox(
          width: 22,
          child: Text(
            '$rank',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: AppTheme.tertiaryLabel,
            ),
          ),
        ),
        SizedBox(
          width: 56,
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(fontSize: 13, color: AppTheme.label),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: ratio.clamp(0.0, 1.0),
              minHeight: 10,
              backgroundColor: AppTheme.separator.withValues(alpha: 0.35),
              color: color,
            ),
          ),
        ),
        const SizedBox(width: 8),
        SizedBox(
          width: 40,
          child: Text(
            value == value.roundToDouble()
                ? '${value.round()}'
                : value.toStringAsFixed(1),
            textAlign: TextAlign.right,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: AppTheme.secondaryLabel,
            ),
          ),
        ),
      ],
    );
  }
}

/// 环形图（考勤构成、分数段等）
class SimpleDonutChart extends StatelessWidget {
  const SimpleDonutChart({
    super.key,
    required this.slices,
  });

  final List<ChartSlice> slices;

  @override
  Widget build(BuildContext context) {
    final total =
        slices.fold<double>(0, (a, b) => a + b.value);
    if (total <= 0) {
      return Center(
        child: Text('暂无数据', style: TextStyle(color: AppTheme.tertiaryLabel)),
      );
    }

    return Row(
      children: [
        Expanded(
          child: PieChart(
            PieChartData(
              sectionsSpace: 2,
              centerSpaceRadius: 36,
              sections: [
                for (final s in slices)
                  if (s.value > 0)
                    PieChartSectionData(
                      value: s.value,
                      color: s.color,
                      radius: 28,
                      title: s.value / total >= 0.08
                          ? '${(s.value / total * 100).round()}%'
                          : '',
                      titleStyle: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
              ],
            ),
          ),
        ),
        const SizedBox(width: 8),
        Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (final s in slices)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 3),
                child: Row(
                  children: [
                    Container(
                      width: 10,
                      height: 10,
                      decoration: BoxDecoration(
                        color: s.color,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      '${s.label} ${s.value == s.value.roundToDouble() ? s.value.round() : s.value.toStringAsFixed(1)}',
                      style: TextStyle(
                        fontSize: 12,
                        color: AppTheme.secondaryLabel,
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ],
    );
  }
}
