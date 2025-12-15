import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class StatisticsCard extends StatelessWidget {
  final Map<String, dynamic> statistics;

  const StatisticsCard({super.key, required this.statistics});

  @override
  Widget build(BuildContext context) {
    final formatter = NumberFormat('#,###');
    final totalSessions = statistics['total_sessions'] ?? 0;
    final totalProfit = statistics['total_profit'] ?? 0;
    final avgProfit = statistics['avg_profit'] ?? 0.0;
    final winRate = statistics['win_rate'] ?? 0.0;
    final totalRing = statistics['total_ring'] ?? 0;
    final totalTournament = statistics['total_tournament'] ?? 0;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '統計',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w300,
                letterSpacing: 1.2,
              ),
            ),
            const SizedBox(height: 20),
            _buildStatRow('セッション数', '$totalSessions 回', Colors.black87),
            const Divider(height: 32),
            _buildStatRow(
              '合計収支',
              '${formatter.format(totalProfit)}pt',
              totalProfit >= 0 ? Colors.green : Colors.red,
              isLarge: true,
            ),
            const SizedBox(height: 16),
            _buildStatRow(
              '平均収支',
              '${formatter.format(avgProfit.round())}pt',
              avgProfit >= 0 ? Colors.green.shade700 : Colors.red.shade700,
            ),
            const SizedBox(height: 8),
            _buildStatRow(
              '勝率',
              '${winRate.toStringAsFixed(1)}%',
              Colors.black87,
            ),
            const Divider(height: 32),
            _buildStatRow(
              'リング合計',
              '${formatter.format(totalRing)}pt',
              totalRing >= 0 ? Colors.blue : Colors.red,
            ),
            const SizedBox(height: 8),
            _buildStatRow(
              'トーナメント合計',
              '${formatter.format(totalTournament)}pt',
              totalTournament >= 0 ? Colors.purple : Colors.red,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatRow(String label, String value, Color valueColor, {bool isLarge = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: isLarge ? 16 : 14,
            color: Colors.black54,
            fontWeight: FontWeight.w300,
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: isLarge ? 24 : 16,
            fontWeight: isLarge ? FontWeight.w500 : FontWeight.w400,
            color: valueColor,
            letterSpacing: 0.5,
          ),
        ),
      ],
    );
  }
}
