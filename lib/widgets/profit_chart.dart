import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../models/poker_session.dart';

class ProfitChart extends StatefulWidget {
  final List<dynamic> sessions;

  const ProfitChart({super.key, required this.sessions});

  @override
  State<ProfitChart> createState() => _ProfitChartState();
}

class _ProfitChartState extends State<ProfitChart> {
  String _selectedChart = 'cumulative'; // 'cumulative', 'ring', 'tournament', 'monthly'

  @override
  Widget build(BuildContext context) {
    if (widget.sessions.isEmpty) {
      return Card(
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.show_chart, size: 64, color: Colors.grey.shade300),
              const SizedBox(height: 16),
              Text(
                'データがありません',
                style: TextStyle(
                  color: Colors.grey.shade600,
                  fontSize: 16,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            _buildChartSelector(),
            const SizedBox(height: 16),
            Expanded(child: _buildChart()),
          ],
        ),
      ),
    );
  }

  Widget _buildChartSelector() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _buildChipButton('累積', 'cumulative'),
          const SizedBox(width: 8),
          _buildChipButton('リング', 'ring'),
          const SizedBox(width: 8),
          _buildChipButton('トーナメント', 'tournament'),
          const SizedBox(width: 8),
          _buildChipButton('月別比較', 'monthly'),
        ],
      ),
    );
  }

  Widget _buildChipButton(String label, String value) {
    final isSelected = _selectedChart == value;
    return OutlinedButton(
      onPressed: () {
        setState(() {
          _selectedChart = value;
        });
      },
      style: OutlinedButton.styleFrom(
        backgroundColor: isSelected ? Colors.black : Colors.white,
        foregroundColor: isSelected ? Colors.white : Colors.black,
        side: const BorderSide(color: Colors.black, width: 1),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      ),
      child: Text(label),
    );
  }

  Widget _buildChart() {
    if (_selectedChart == 'monthly') {
      return _buildMonthlyComparisonChart();
    }
    
    final reversedSessions = widget.sessions.reversed.toList();
    
    List<FlSpot> spots;
    Color lineColor;
    
    if (_selectedChart == 'cumulative') {
      // 累積収支
      int cumulative = 0;
      spots = List.generate(reversedSessions.length, (i) {
        final session = reversedSessions[i] as PokerSession;
        cumulative += session.totalChange;
        return FlSpot(i.toDouble(), cumulative.toDouble());
      });
      lineColor = Colors.black;
    } else if (_selectedChart == 'ring') {
      // リングゲーム収支
      int cumulative = 0;
      spots = List.generate(reversedSessions.length, (i) {
        final session = reversedSessions[i] as PokerSession;
        cumulative += session.ringProfit;
        return FlSpot(i.toDouble(), cumulative.toDouble());
      });
      lineColor = Colors.blue;
    } else {
      // トーナメント収支
      int cumulative = 0;
      spots = List.generate(reversedSessions.length, (i) {
        final session = reversedSessions[i] as PokerSession;
        cumulative += session.tournamentProfit;
        return FlSpot(i.toDouble(), cumulative.toDouble());
      });
      lineColor = Colors.purple;
    }

    return LineChart(
      LineChartData(
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          horizontalInterval: _calculateInterval(spots),
          getDrawingHorizontalLine: (value) {
            return FlLine(
              color: Colors.grey.shade200,
              strokeWidth: 1,
            );
          },
        ),
        titlesData: FlTitlesData(
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 60,
              getTitlesWidget: (value, meta) {
                return Text(
                  _formatNumber(value),
                  style: const TextStyle(fontSize: 10, color: Colors.black54),
                );
              },
            ),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              interval: (reversedSessions.length / 5).ceilToDouble(),
              getTitlesWidget: (value, meta) {
                if (value.toInt() >= reversedSessions.length) {
                  return const SizedBox.shrink();
                }
                final session = reversedSessions[value.toInt()] as PokerSession;
                return Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    '${session.date.month}/${session.date.day}',
                    style: const TextStyle(fontSize: 10, color: Colors.black54),
                  ),
                );
              },
            ),
          ),
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        ),
        borderData: FlBorderData(
          show: true,
          border: Border(
            bottom: BorderSide(color: Colors.grey.shade300),
            left: BorderSide(color: Colors.grey.shade300),
          ),
        ),
        lineBarsData: [
          LineChartBarData(
            spots: spots,
            isCurved: false,
            color: lineColor,
            barWidth: 2,
            dotData: const FlDotData(show: false),
            belowBarData: BarAreaData(show: false),
          ),
        ],
        lineTouchData: LineTouchData(
          touchTooltipData: LineTouchTooltipData(
            getTooltipItems: (touchedSpots) {
              return touchedSpots.map((spot) {
                final session = reversedSessions[spot.x.toInt()] as PokerSession;
                final storeName = session.storeName ?? '不明';
                
                // タップされたグラフに応じて表示する収支を変更
                String profitInfo;
                if (_selectedChart == 'cumulative') {
                  profitInfo = '合計: ${_formatNumber(spot.y)}pt\n'
                      'リング: ${session.ringProfit >= 0 ? '+' : ''}${session.ringProfit}pt\n'
                      'トーナメント: ${session.tournamentProfit >= 0 ? '+' : ''}${session.tournamentProfit}pt';
                } else if (_selectedChart == 'ring') {
                  profitInfo = 'リング累計: ${_formatNumber(spot.y)}pt\n'
                      '当日: ${session.ringProfit >= 0 ? '+' : ''}${session.ringProfit}pt';
                } else {
                  profitInfo = 'トーナメント累計: ${_formatNumber(spot.y)}pt\n'
                      '当日: ${session.tournamentProfit >= 0 ? '+' : ''}${session.tournamentProfit}pt';
                }
                
                return LineTooltipItem(
                  '${session.date.month}/${session.date.day}\n'
                  '$storeName\n'
                  '$profitInfo',
                  const TextStyle(color: Colors.white, fontSize: 11),
                );
              }).toList();
            },
          ),
        ),
      ),
    );
  }

  double _calculateInterval(List<FlSpot> spots) {
    if (spots.isEmpty) return 1000;
    
    final values = spots.map((spot) => spot.y).toList();
    final min = values.reduce((a, b) => a < b ? a : b);
    final max = values.reduce((a, b) => a > b ? a : b);
    final range = (max - min).abs();
    
    if (range < 1000) return 200;
    if (range < 5000) return 1000;
    if (range < 10000) return 2000;
    return 5000;
  }

  String _formatNumber(double value) {
    if (value.abs() >= 10000) {
      return '${(value / 1000).toStringAsFixed(0)}k';
    }
    return value.toStringAsFixed(0);
  }
  
  Widget _buildMonthlyComparisonChart() {
    // 月ごとにデータを集計
    Map<String, Map<String, dynamic>> monthlyData = {};
    
    for (var session in widget.sessions) {
      final pokerSession = session as PokerSession;
      final monthKey = '${pokerSession.date.year}-${pokerSession.date.month.toString().padLeft(2, '0')}';
      
      if (!monthlyData.containsKey(monthKey)) {
        monthlyData[monthKey] = {
          'total': 0,
          'ring': 0,
          'tournament': 0,
          'sessions': 0,
          'year': pokerSession.date.year,
          'month': pokerSession.date.month,
        };
      }
      
      monthlyData[monthKey]!['total'] += pokerSession.totalChange;
      monthlyData[monthKey]!['ring'] += pokerSession.ringProfit;
      monthlyData[monthKey]!['tournament'] += pokerSession.tournamentProfit;
      monthlyData[monthKey]!['sessions'] += 1;
    }
    
    // ソート（古い順）
    final sortedKeys = monthlyData.keys.toList()..sort();
    
    if (sortedKeys.isEmpty) {
      return const Center(child: Text('データがありません'));
    }
    
    // 棒グラフ用のデータを作成
    final barGroups = <BarChartGroupData>[];
    
    for (int i = 0; i < sortedKeys.length; i++) {
      final key = sortedKeys[i];
      final data = monthlyData[key]!;
      final total = data['total'] as int;
      
      barGroups.add(
        BarChartGroupData(
          x: i,
          barRods: [
            BarChartRodData(
              toY: total.toDouble(),
              color: total >= 0 ? Colors.green : Colors.red,
              width: sortedKeys.length > 6 ? 12 : 20,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(4),
                topRight: Radius.circular(4),
              ),
            ),
          ],
        ),
      );
    }
    
    return BarChart(
      BarChartData(
        alignment: BarChartAlignment.spaceAround,
        maxY: _calculateMaxY(monthlyData),
        minY: _calculateMinY(monthlyData),
        barGroups: barGroups,
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          horizontalInterval: _calculateMonthlyInterval(monthlyData),
          getDrawingHorizontalLine: (value) {
            return FlLine(
              color: Colors.grey.shade200,
              strokeWidth: 1,
            );
          },
        ),
        titlesData: FlTitlesData(
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 60,
              getTitlesWidget: (value, meta) {
                return Text(
                  _formatNumber(value),
                  style: const TextStyle(fontSize: 10, color: Colors.black54),
                );
              },
            ),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              getTitlesWidget: (value, meta) {
                if (value.toInt() >= sortedKeys.length) {
                  return const SizedBox.shrink();
                }
                final key = sortedKeys[value.toInt()];
                final data = monthlyData[key]!;
                return Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    '${data['year']}\n${data['month']}月',
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 9, color: Colors.black54),
                  ),
                );
              },
            ),
          ),
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        ),
        borderData: FlBorderData(
          show: true,
          border: Border(
            bottom: BorderSide(color: Colors.grey.shade300),
            left: BorderSide(color: Colors.grey.shade300),
          ),
        ),
        barTouchData: BarTouchData(
          touchTooltipData: BarTouchTooltipData(
            getTooltipItem: (group, groupIndex, rod, rodIndex) {
              final key = sortedKeys[group.x.toInt()];
              final data = monthlyData[key]!;
              final total = data['total'] as int;
              final ring = data['ring'] as int;
              final tournament = data['tournament'] as int;
              final sessions = data['sessions'] as int;
              
              return BarTooltipItem(
                '${data['year']}年${data['month']}月\n',
                const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                children: [
                  TextSpan(
                    text: '総収支: ${total >= 0 ? '+' : ''}${total}pt\n',
                    style: const TextStyle(fontSize: 11, fontWeight: FontWeight.normal),
                  ),
                  TextSpan(
                    text: 'リング: ${ring >= 0 ? '+' : ''}${ring}pt\n',
                    style: const TextStyle(fontSize: 10),
                  ),
                  TextSpan(
                    text: 'トーナメント: ${tournament >= 0 ? '+' : ''}${tournament}pt\n',
                    style: const TextStyle(fontSize: 10),
                  ),
                  TextSpan(
                    text: 'セッション数: $sessions回',
                    style: const TextStyle(fontSize: 10),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
  
  double _calculateMaxY(Map<String, Map<String, dynamic>> monthlyData) {
    if (monthlyData.isEmpty) return 1000;
    final maxValue = monthlyData.values
        .map((data) => data['total'] as int)
        .reduce((a, b) => a > b ? a : b)
        .toDouble();
    return maxValue > 0 ? maxValue * 1.2 : 1000;
  }
  
  double _calculateMinY(Map<String, Map<String, dynamic>> monthlyData) {
    if (monthlyData.isEmpty) return -1000;
    final minValue = monthlyData.values
        .map((data) => data['total'] as int)
        .reduce((a, b) => a < b ? a : b)
        .toDouble();
    return minValue < 0 ? minValue * 1.2 : 0;
  }
  
  double _calculateMonthlyInterval(Map<String, Map<String, dynamic>> monthlyData) {
    if (monthlyData.isEmpty) return 1000;
    
    final values = monthlyData.values.map((data) => data['total'] as int).toList();
    final min = values.reduce((a, b) => a < b ? a : b);
    final max = values.reduce((a, b) => a > b ? a : b);
    final range = (max - min).abs();
    
    if (range < 1000) return 200;
    if (range < 5000) return 1000;
    if (range < 10000) return 2000;
    return 5000;
  }
}
