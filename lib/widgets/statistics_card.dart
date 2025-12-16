import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';
import 'dart:ui' as ui;
import 'dart:typed_data';

class StatisticsCard extends StatelessWidget {
  final Map<String, dynamic> statistics;
  final GlobalKey? chartKey;
  final VoidCallback? onCaptureChart;

  const StatisticsCard({
    super.key, 
    required this.statistics,
    this.chartKey,
    this.onCaptureChart,
  });

  @override
  Widget build(BuildContext context) {
    final formatter = NumberFormat('#,###');
    final totalSessions = statistics['total_sessions'] ?? 0;
    final totalProfit = statistics['total_profit'] ?? 0;
    final winRate = statistics['win_rate'] ?? 0.0;
    
    // 新しい統計データ
    final avgDailyChange = statistics['avg_daily_change'] ?? 0.0;
    final maxProfitDay = statistics['max_profit_day'] ?? 0;
    final minProfitDay = statistics['min_profit_day'] ?? 0;
    final plusDays = statistics['plus_days'] ?? 0;
    final minusDays = statistics['minus_days'] ?? 0;
    final avgRing = statistics['avg_ring'] ?? 0.0;
    final avgTournament = statistics['avg_tournament'] ?? 0.0;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  '統計',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w300,
                    letterSpacing: 1.2,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.share, size: 20),
                  onPressed: () => _showShareDialog(context),
                  tooltip: 'SNSでシェア',
                ),
              ],
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
              '平均日次増減',
              '${formatter.format(avgDailyChange.round())}pt/日',
              avgDailyChange >= 0 ? Colors.green.shade700 : Colors.red.shade700,
            ),
            const SizedBox(height: 8),
            _buildStatRow(
              '勝率',
              '${winRate.toStringAsFixed(1)}% ($plusDays勝 $minusDays敗)',
              Colors.black87,
            ),
            const Divider(height: 32),
            const Text(
              '収支詳細',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: Colors.black54,
              ),
            ),
            const SizedBox(height: 12),
            _buildStatRow(
              '最高収支日',
              '${formatter.format(maxProfitDay)}pt',
              Colors.green.shade600,
            ),
            const SizedBox(height: 8),
            _buildStatRow(
              '最低収支日',
              '${formatter.format(minProfitDay)}pt',
              Colors.red.shade600,
            ),
            const Divider(height: 32),
            const Text(
              'ゲーム別',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: Colors.black54,
              ),
            ),
            const SizedBox(height: 12),
            _buildStatRow(
              'リング平均',
              '${formatter.format(avgRing.round())}pt/日',
              avgRing >= 0 ? Colors.blue : Colors.red,
            ),
            const SizedBox(height: 8),
            _buildStatRow(
              'トーナメント平均',
              '${formatter.format(avgTournament.round())}pt/日',
              avgTournament >= 0 ? Colors.purple : Colors.red,
            ),
          ],
        ),
      ),
    );
  }
  
  void _showShareDialog(BuildContext context) {
    final formatter = NumberFormat('#,###');
    final totalProfit = statistics['total_profit'] ?? 0;
    final winRate = statistics['win_rate'] ?? 0.0;
    final avgDailyChange = statistics['avg_daily_change'] ?? 0.0;
    final totalSessions = statistics['total_sessions'] ?? 0;
    final maxProfitDay = statistics['max_profit_day'] ?? 0;
    
    // シェア用テキストを生成
    final shareText = '📊 じゃんぽ分析\n\n'
        'セッション数: $totalSessions回\n'
        '総収支: ${formatter.format(totalProfit)}pt\n'
        '平均増減: ${formatter.format(avgDailyChange.round())}pt/日\n'
        '勝率: ${winRate.toStringAsFixed(1)}%\n'
        '最高日: ${formatter.format(maxProfitDay)}pt';
    
    // 匿名版（金額を隠す）
    final anonymousText = '📊 じゃんぽ分析\n\n'
        'セッション数: $totalSessions回\n'
        '勝率: ${winRate.toStringAsFixed(1)}%\n'
        '継続プレイ中！';
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('SNSでシェア'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.grey[300]!),
                ),
                child: Text(
                  shareText,
                  style: const TextStyle(fontSize: 12),
                ),
              ),
              const SizedBox(height: 16),
              // グラフ付きシェア
              if (chartKey != null) ...[
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () {
                      Navigator.pop(context);
                      _shareWithChart(context, shareText, false);
                    },
                    icon: const Icon(Icons.image, size: 18),
                    label: const Text('グラフ付きでシェア'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
              ],
              // テキストのみシェア
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () {
                    Navigator.pop(context);
                    _shareToSNS(shareText);
                  },
                  icon: const Icon(Icons.share, size: 18),
                  label: const Text('テキストのみシェア'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue,
                    foregroundColor: Colors.white,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () {
                    Navigator.pop(context);
                    _shareToSNS(anonymousText);
                  },
                  icon: const Icon(Icons.lock_outline, size: 18),
                  label: const Text('匿名版をシェア'),
                ),
              ),
              const SizedBox(height: 16),
              const Divider(),
              const SizedBox(height: 8),
              // グラフ画像ダウンロード
              if (chartKey != null) ...[
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () {
                      Navigator.pop(context);
                      _downloadChartImage(context);
                    },
                    icon: const Icon(Icons.download, size: 18),
                    label: const Text('グラフ画像をダウンロード'),
                  ),
                ),
              ],
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('キャンセル'),
          ),
        ],
      ),
    );
  }
  
  Future<void> _shareWithChart(BuildContext context, String text, bool anonymous) async {
    if (chartKey == null || chartKey!.currentContext == null) {
      _shareToSNS(text);
      return;
    }

    try {
      // グラフをキャプチャ
      RenderRepaintBoundary boundary = chartKey!.currentContext!.findRenderObject() as RenderRepaintBoundary;
      ui.Image image = await boundary.toImage(pixelRatio: 2.0);
      ByteData? byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      
      if (byteData != null) {
        Uint8List pngBytes = byteData.buffer.asUint8List();
        
        // 画像ファイルとしてシェア
        await Share.shareXFiles(
          [XFile.fromData(pngBytes, name: 'jyanpo_chart.png', mimeType: 'image/png')],
          text: text,
        );
      }
    } catch (e) {
      // エラーの場合はテキストのみシェア
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('グラフのキャプチャに失敗しました。テキストのみシェアします。')),
        );
      }
      _shareToSNS(text);
    }
  }
  
  Future<void> _downloadChartImage(BuildContext context) async {
    if (chartKey == null || chartKey!.currentContext == null) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('グラフが見つかりません')),
        );
      }
      return;
    }

    try {
      // グラフをキャプチャ
      RenderRepaintBoundary boundary = chartKey!.currentContext!.findRenderObject() as RenderRepaintBoundary;
      ui.Image image = await boundary.toImage(pixelRatio: 3.0);
      ByteData? byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      
      if (byteData != null) {
        Uint8List pngBytes = byteData.buffer.asUint8List();
        
        // Web環境では自動ダウンロード
        final timestamp = DateTime.now().millisecondsSinceEpoch;
        await Share.shareXFiles(
          [XFile.fromData(pngBytes, name: 'jyanpo_chart_$timestamp.png', mimeType: 'image/png')],
          subject: 'じゃんぽ分析グラフ',
        );
        
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('グラフ画像を保存しました！'),
              backgroundColor: Colors.green,
            ),
          );
        }
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('エラー: $e')),
        );
      }
    }
  }
  
  void _shareToSNS(String text) {
    Share.share(text);
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
