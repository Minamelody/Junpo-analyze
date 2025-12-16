import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../services/jyanken_poker_api.dart';
import '../models/poker_session.dart';
import '../widgets/statistics_card.dart';
import '../widgets/profit_chart.dart';
import '../widgets/session_list.dart';

enum PeriodFilter {
  currentMonth,
  lastMonth,
  last3Months,
  last6Months,
  lastYear,
  allTime,
}

class MainAppScreen extends StatefulWidget {
  final JyankenPokerAPI api;
  final String email;

  const MainAppScreen({
    super.key,
    required this.api,
    required this.email,
  });

  @override
  State<MainAppScreen> createState() => _MainAppScreenState();
}

class _MainAppScreenState extends State<MainAppScreen> with WidgetsBindingObserver {
  int _selectedIndex = 0;
  PeriodFilter _selectedPeriod = PeriodFilter.currentMonth;
  List<PokerSession> _sessions = [];
  bool _isLoading = false;
  String? _errorMessage;
  
  // 店舗関連
  List<Map<String, String>> _stores = [];
  String _selectedStoreId = '6'; // デフォルトは京都河原町店

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadInitialData();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    // ページを閉じる時にセッションをクリア
    widget.api.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused || state == AppLifecycleState.detached) {
      // アプリがバックグラウンドに移行または終了する時
      widget.api.clearSession();
    }
  }

  Future<void> _loadInitialData() async {
    // 店舗一覧を取得
    final stores = await widget.api.fetchStores();
    if (mounted && stores.isNotEmpty) {
      setState(() {
        _stores = stores;
        _selectedStoreId = stores.first['id']!;
      });
    }
    
    await _loadDataForPeriod(_selectedPeriod);
  }

  Future<void> _loadDataForPeriod(PeriodFilter period) async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _selectedPeriod = period;
    });

    try {
      final now = DateTime.now();
      final months = _getMonthsForPeriod(period, now);
      
      final sessions = await widget.api.fetchMultipleMonths(
        storeId: _selectedStoreId,
        months: months,
      );

      if (mounted) {
        setState(() {
          _sessions = sessions;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'データの取得に失敗しました: $e';
          _isLoading = false;
        });
      }
    }
  }

  List<String> _getMonthsForPeriod(PeriodFilter period, DateTime now) {
    final months = <String>[];
    
    switch (period) {
      case PeriodFilter.currentMonth:
        months.add(DateFormat('yyyy-MM').format(now));
        break;
      
      case PeriodFilter.lastMonth:
        final lastMonth = DateTime(now.year, now.month - 1);
        months.add(DateFormat('yyyy-MM').format(lastMonth));
        break;
      
      case PeriodFilter.last3Months:
        for (int i = 0; i < 3; i++) {
          final month = DateTime(now.year, now.month - i);
          months.add(DateFormat('yyyy-MM').format(month));
        }
        break;
      
      case PeriodFilter.last6Months:
        for (int i = 0; i < 6; i++) {
          final month = DateTime(now.year, now.month - i);
          months.add(DateFormat('yyyy-MM').format(month));
        }
        break;
      
      case PeriodFilter.lastYear:
        for (int i = 0; i < 12; i++) {
          final month = DateTime(now.year, now.month - i);
          months.add(DateFormat('yyyy-MM').format(month));
        }
        break;
      
      case PeriodFilter.allTime:
        // 過去24ヶ月分を取得（2年分）
        for (int i = 0; i < 24; i++) {
          final month = DateTime(now.year, now.month - i);
          months.add(DateFormat('yyyy-MM').format(month));
        }
        break;
    }
    
    return months;
  }

  String _getPeriodLabel(PeriodFilter period) {
    switch (period) {
      case PeriodFilter.currentMonth:
        return '当月';
      case PeriodFilter.lastMonth:
        return '前月';
      case PeriodFilter.last3Months:
        return '過去3ヶ月';
      case PeriodFilter.last6Months:
        return '過去6ヶ月';
      case PeriodFilter.lastYear:
        return '過去1年';
      case PeriodFilter.allTime:
        return '全期間';
    }
  }

  Map<String, dynamic> _calculateStatistics() {
    if (_sessions.isEmpty) {
      return {
        'total_sessions': 0,
        'total_ring': 0,
        'total_tournament': 0,
        'total_profit': 0,
        'avg_profit': 0.0,
        'win_rate': 0.0,
        'avg_daily_change': 0.0,
        'max_profit_day': 0,
        'min_profit_day': 0,
        'plus_days': 0,
        'minus_days': 0,
        'avg_ring': 0.0,
        'avg_tournament': 0.0,
      };
    }

    int totalRing = 0;
    int totalTournament = 0;
    int totalProfit = 0;
    int winCount = 0;
    int maxProfit = _sessions.first.totalChange;
    int minProfit = _sessions.first.totalChange;
    int plusDays = 0;
    int minusDays = 0;

    for (var session in _sessions) {
      totalRing += session.ringProfit;
      totalTournament += session.tournamentProfit;
      totalProfit += session.totalChange;
      
      if (session.totalChange > 0) {
        winCount++;
        plusDays++;
      } else if (session.totalChange < 0) {
        minusDays++;
      }
      
      if (session.totalChange > maxProfit) maxProfit = session.totalChange;
      if (session.totalChange < minProfit) minProfit = session.totalChange;
    }

    return {
      'total_sessions': _sessions.length,
      'total_ring': totalRing,
      'total_tournament': totalTournament,
      'total_profit': totalProfit,
      'avg_profit': totalProfit / _sessions.length,
      'win_rate': (winCount / _sessions.length) * 100,
      'avg_daily_change': totalProfit / _sessions.length,
      'max_profit_day': maxProfit,
      'min_profit_day': minProfit,
      'plus_days': plusDays,
      'minus_days': minusDays,
      'avg_ring': totalRing / _sessions.length,
      'avg_tournament': totalTournament / _sessions.length,
    };
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Poker Ledger',
          style: TextStyle(
            fontWeight: FontWeight.w300,
            letterSpacing: 1.5,
          ),
        ),
        actions: [
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert),
            onSelected: (value) {
              if (value == 'logout') {
                _handleLogout();
              }
            },
            itemBuilder: (context) => [
              PopupMenuItem(
                value: 'user',
                enabled: false,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'ログイン中',
                      style: TextStyle(fontSize: 12, color: Colors.black45),
                    ),
                    Text(
                      widget.email,
                      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
                    ),
                  ],
                ),
              ),
              const PopupMenuDivider(),
              const PopupMenuItem(
                value: 'logout',
                child: Row(
                  children: [
                    Icon(Icons.logout, size: 20),
                    SizedBox(width: 8),
                    Text('ログアウト'),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            if (_stores.isNotEmpty) _buildStoreSelector(),
            _buildPeriodSelector(),
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _errorMessage != null
                      ? _buildErrorView()
                      : _selectedIndex == 0
                          ? _buildOverviewTab()
                          : _buildHistoryTab(),
            ),
          ],
        ),
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedIndex,
        onDestinationSelected: (index) {
          setState(() {
            _selectedIndex = index;
          });
        },
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.analytics_outlined),
            selectedIcon: Icon(Icons.analytics),
            label: '概要',
          ),
          NavigationDestination(
            icon: Icon(Icons.list_outlined),
            selectedIcon: Icon(Icons.list),
            label: '履歴',
          ),
        ],
      ),
    );
  }

  Widget _buildStoreSelector() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        border: Border(
          bottom: BorderSide(color: Colors.grey.shade200),
        ),
      ),
      child: Row(
        children: [
          const Icon(Icons.store, size: 20, color: Colors.black54),
          const SizedBox(width: 8),
          const Text(
            '店舗:',
            style: TextStyle(
              fontSize: 14,
              color: Colors.black54,
              fontWeight: FontWeight.w300,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: _stores.map((store) {
                  final isSelected = _selectedStoreId == store['id'];
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: OutlinedButton(
                      onPressed: () {
                        setState(() {
                          _selectedStoreId = store['id']!;
                        });
                        _loadDataForPeriod(_selectedPeriod);
                      },
                      style: OutlinedButton.styleFrom(
                        backgroundColor: isSelected ? Colors.black : Colors.white,
                        foregroundColor: isSelected ? Colors.white : Colors.black,
                        side: const BorderSide(color: Colors.black, width: 1),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                        minimumSize: const Size(0, 32),
                      ),
                      child: Text(
                        store['name']!,
                        style: const TextStyle(fontSize: 13),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPeriodSelector() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(
          bottom: BorderSide(color: Colors.grey.shade200),
        ),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: PeriodFilter.values.map((period) {
            final isSelected = _selectedPeriod == period;
            return Padding(
              padding: const EdgeInsets.only(right: 8),
              child: OutlinedButton(
                onPressed: () => _loadDataForPeriod(period),
                style: OutlinedButton.styleFrom(
                  backgroundColor: isSelected ? Colors.black : Colors.white,
                  foregroundColor: isSelected ? Colors.white : Colors.black,
                  side: const BorderSide(color: Colors.black, width: 1),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                ),
                child: Text(_getPeriodLabel(period)),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildOverviewTab() {
    final statistics = _calculateStatistics();
    
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          StatisticsCard(statistics: statistics),
          const SizedBox(height: 24),
          const Text(
            '収支推移',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w300,
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 300,
            child: ProfitChart(sessions: _sessions),
          ),
        ],
      ),
    );
  }

  Widget _buildHistoryTab() {
    return SessionList(sessions: _sessions);
  }

  Widget _buildErrorView() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 64, color: Colors.red),
            const SizedBox(height: 16),
            Text(
              _errorMessage!,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () => _loadDataForPeriod(_selectedPeriod),
              icon: const Icon(Icons.refresh),
              label: const Text('再試行'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.black,
                foregroundColor: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _handleLogout() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('ログアウト'),
        content: const Text('ログアウトしますか？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('キャンセル'),
          ),
          TextButton(
            onPressed: () {
              widget.api.dispose();
              Navigator.pop(context); // ダイアログを閉じる
              Navigator.pop(context); // ログイン画面に戻る
            },
            child: const Text('ログアウト'),
          ),
        ],
      ),
    );
  }
}
