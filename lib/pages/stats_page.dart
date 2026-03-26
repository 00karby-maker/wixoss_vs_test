import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:fl_chart/fl_chart.dart';
import '../model/match_record.dart';

class StatsPage extends StatefulWidget {
  const StatsPage({super.key});

  @override
  State<StatsPage> createState() => _StatsPageState();
}

class _StatsPageState extends State<StatsPage> {
  String format = "∀";

  Color lrigColor(String name) {
    final hash = name.hashCode;
    final hue = ((hash * 137) % 360 + 360) % 360;
    const saturation = 0.6;
    const lightness = 0.5;

    return HSLColor.fromAHSL(1.0, hue.toDouble(), saturation, lightness).toColor();
  }

  /// データ取得
  List<MatchRecord> getRecords(Box<MatchRecord> box) {
    if (format == "∀") return box.values.toList();
    return box.values.where((e) => e.format == format).toList();
  }

  /// ルリグごとの件数カウント
  Map<String, int> countBy(Box<MatchRecord> box, bool used) {
    final map = <String, int>{};
    for (var r in getRecords(box)) {
      final key = used ? r.usedLrig : r.opponentLrig;
      if (key.isEmpty) continue;
      map[key] = (map[key] ?? 0) + 1;
    }
    return map;
  }

  /// 勝率データ
  Map<String, Map<String, int>> winData(Box<MatchRecord> box) {
    final map = <String, Map<String, int>>{};
    for (var r in getRecords(box)) {
      final key = r.usedLrig;
      if (key.isEmpty) continue;
      map.putIfAbsent(key, () => {"win": 0, "total": 0});
      map[key]!["total"] = map[key]!["total"]! + 1;
      if (r.result == "勝") map[key]!["win"] = map[key]!["win"]! + 1;
    }
    return map;
  }

  @override
  Widget build(BuildContext context) {
    final box = Hive.box<MatchRecord>('records');

    if (box.isEmpty) {
      return const Center(child: Text("記録がありません"));
    }

    final used = countBy(box, true);
    final opp = countBy(box, false);
    final winMap = winData(box);
    final entries = winMap.entries.toList()
      ..sort((a, b) {
        final winA = a.value["win"]!;
        final totalA = a.value["total"]!;
        final rateA = totalA == 0 ? 0 : winA / totalA;

        final winB = b.value["win"]!;
        final totalB = b.value["total"]!;
        final rateB = totalB == 0 ? 0 : winB / totalB;

        // 勝率優先 → 同率なら試合数
        final cmp = rateB.compareTo(rateA);
        if (cmp != 0) return cmp;

        return totalB.compareTo(totalA);
      });

    return SingleChildScrollView(
      key: ValueKey(format),
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          /// フィルター
          Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: DropdownButtonFormField<String>(
                value: format,
                decoration: const InputDecoration(
                  labelText: "フォーマット",
                  border: OutlineInputBorder(),
                ),
                items: ["∀", "A", "K", "D"]
                    .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                    .toList(),
                onChanged: (v) => setState(() => format = v!),
              ),
            ),
          ),

          const SizedBox(height: 16),

          buildPie("使用ルリグ割合", used),
          buildPie("対戦ルリグ割合", opp),
          buildBar(entries, winMap),
        ],
      ),
    );
  }

  /// 円グラフ
  Widget buildPie(String title, Map<String, int> data) {
    final total = data.values.fold<int>(0, (a, b) => a + b);

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Text(title,
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            SizedBox(
              height: 220,
              child: PieChart(
                PieChartData(
                  sections: data.entries.map((e) {
                    final percent = total == 0 ? 0.0 : (e.value / total * 100);
                    return PieChartSectionData(
                      value: percent.toDouble(),
                      color: lrigColor(e.key),
                      radius: 65,
                      title: "${e.key}\n${percent.toStringAsFixed(1)}%",
                      titleStyle: const TextStyle(fontSize: 12, color: Colors.white),
                    );
                  }).toList(),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 棒グラフ（勝率）
  Widget buildBar(
      List<MapEntry<String, Map<String, int>>> entries,
      Map<String, Map<String, int>> winMap) {

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            const Text("使用ルリグ勝率",
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            SizedBox(
              height: 260,
              child: BarChart(
                BarChartData(
                  maxY: 100,
                  titlesData: FlTitlesData(
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        interval: 20,
                        getTitlesWidget: (value, meta) => Text(
                          "${value.toInt()}%",
                          style: TextStyle(
                              fontSize: 10,
                              color: Theme.of(context).brightness == Brightness.dark
                                  ? Colors.white70
                                  : Colors.black87),
                        ),
                      ),
                    ),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        getTitlesWidget: (value, meta) {
                          final i = value.toInt();
                          if (i >= entries.length) return const SizedBox();
                          // 下部はルリグ名
                          return Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Text(entries[i].key,
                                style: const TextStyle(fontSize: 10)),
                          );
                        },
                      ),
                    ),
                    topTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        getTitlesWidget: (value, meta) {
                          final i = value.toInt();
                          if (i >= entries.length) return const SizedBox();
                          // 上位5位はTier1〜Tier5、それ以降は数字表示
                          final label = i < 5 ? "Tier${i + 1}" : "$i";
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 4),
                            child: Text(label,
                                style: const TextStyle(
                                    fontSize: 10, fontWeight: FontWeight.bold)),
                          );
                        },
                      ),
                    ),
                  ),
                  barTouchData: BarTouchData(
                    enabled: true,
                    touchTooltipData: BarTouchTooltipData(
                      tooltipBgColor: Colors.black87,
                      getTooltipItem: (group, groupIndex, rod, rodIndex) {
                        final name = entries[groupIndex].key;
                        final win = winMap[name]!["win"]!;
                        final total = winMap[name]!["total"]!;
                        final rate = total == 0 ? 0.0 : (win / total * 100);
                        return BarTooltipItem(
                          "$name\n${rate.toStringAsFixed(1)}%\n$win勝 / $total戦",
                          const TextStyle(color: Colors.white),
                        );
                      },
                    ),
                  ),
                  barGroups: List.generate(entries.length, (i) {
                    final name = entries[i].key;
                    final win = winMap[name]!["win"]!;
                    final total = winMap[name]!["total"]!;
                    final rate = total == 0 ? 0.0 : (win / total * 100);
                    return BarChartGroupData(
                      x: i,
                      barRods: [
                        BarChartRodData(
                          toY: rate.toDouble(),
                          color: lrigColor(name),
                          width: 18,
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ],
                    );
                  }),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
