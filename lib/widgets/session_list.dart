import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/poker_session.dart';

class SessionList extends StatelessWidget {
  final List<dynamic> sessions;

  const SessionList({super.key, required this.sessions});

  @override
  Widget build(BuildContext context) {
    if (sessions.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.inbox_outlined, size: 80, color: Colors.grey.shade300),
            const SizedBox(height: 16),
            Text(
              'セッションがありません',
              style: TextStyle(
                color: Colors.grey.shade600,
                fontSize: 18,
                fontWeight: FontWeight.w300,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '右上の + ボタンからセッションを追加できます',
              style: TextStyle(
                color: Colors.grey.shade500,
                fontSize: 14,
              ),
            ),
          ],
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: sessions.length,
      separatorBuilder: (context, index) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final session = sessions[index] as PokerSession;
        return _SessionCard(session: session, index: index);
      },
    );
  }
}

class _SessionCard extends StatelessWidget {
  final PokerSession session;
  final int index;

  const _SessionCard({required this.session, required this.index});

  @override
  Widget build(BuildContext context) {
    final formatter = NumberFormat('#,###');
    final dateFormatter = DateFormat('yyyy/MM/dd');

    return Card(
      child: InkWell(
        onTap: () => _showSessionDetails(context),
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    dateFormatter.format(session.date),
                    style: const TextStyle(
                      fontSize: 14,
                      color: Colors.black54,
                      fontWeight: FontWeight.w300,
                    ),
                  ),
                  Text(
                    '${formatter.format(session.totalChange)}pt',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w500,
                      color: session.totalChange >= 0 ? Colors.green : Colors.red,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _buildDataChip(
                      'リング',
                      session.ringProfit,
                      Colors.blue,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _buildDataChip(
                      'トーナメント',
                      session.tournamentProfit,
                      Colors.purple,
                    ),
                  ),
                ],
              ),
              if (session.notes != null && session.notes!.isNotEmpty) ...[
                const SizedBox(height: 12),
                Text(
                  session.notes!,
                  style: const TextStyle(
                    fontSize: 13,
                    color: Colors.black54,
                    fontStyle: FontStyle.italic,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDataChip(String label, int value, Color color) {
    final formatter = NumberFormat('#,###');
    final displayValue = value >= 0 ? '+${formatter.format(value)}' : formatter.format(value);
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: color.withValues(alpha: 0.3),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              color: color,
              fontWeight: FontWeight.w300,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            displayValue,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  void _showSessionDetails(BuildContext context) {
    final dateFormatter = DateFormat('yyyy年MM月dd日 (E)', 'ja');

    showModalBottomSheet(
      context: context,
      builder: (context) => Container(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'セッション詳細',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w300,
                letterSpacing: 1.2,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              dateFormatter.format(session.date),
              style: const TextStyle(fontSize: 14, color: Colors.black54),
            ),
            const Divider(height: 32),
            _buildDetailRow('リングゲーム', session.ringProfit),
            const SizedBox(height: 12),
            _buildDetailRow('トーナメント', session.tournamentProfit),
            const SizedBox(height: 12),
            _buildDetailRow('購入', session.purchase, isPositive: true),
            const Divider(height: 32),
            _buildDetailRow('合計', session.totalChange, isLarge: true),
            const SizedBox(height: 12),
            _buildDetailRow('残高', session.balance, isBalance: true),
            if (session.notes != null && session.notes!.isNotEmpty) ...[
              const Divider(height: 32),
              const Text(
                'メモ',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.black54,
                  fontWeight: FontWeight.w300,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                session.notes!,
                style: const TextStyle(fontSize: 14),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildDetailRow(String label, int value, {bool isLarge = false, bool isPositive = false, bool isBalance = false}) {
    final formatter = NumberFormat('#,###');
    Color valueColor;
    
    if (isBalance) {
      valueColor = Colors.black87;
    } else if (isPositive) {
      valueColor = Colors.black87;
    } else {
      valueColor = value >= 0 ? Colors.green : Colors.red;
    }

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
          '${formatter.format(value)}pt',
          style: TextStyle(
            fontSize: isLarge ? 20 : 16,
            fontWeight: isLarge ? FontWeight.w500 : FontWeight.w400,
            color: valueColor,
          ),
        ),
      ],
    );
  }


}
