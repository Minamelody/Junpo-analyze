import 'package:hive_flutter/hive_flutter.dart';
import '../models/poker_session.dart';

class PokerDataService {
  static const String _boxName = 'poker_sessions';
  late Box<Map> _box;

  Future<void> init() async {
    await Hive.initFlutter();
    _box = await Hive.openBox<Map>(_boxName);
  }

  // すべてのセッションを取得
  List<PokerSession> getAllSessions() {
    final sessions = <PokerSession>[];
    for (var i = 0; i < _box.length; i++) {
      final data = _box.getAt(i);
      if (data != null) {
        sessions.add(_mapToSession(Map<String, dynamic>.from(data)));
      }
    }
    // 日付順にソート（新しい順）
    sessions.sort((a, b) => b.date.compareTo(a.date));
    return sessions;
  }

  // セッションを追加
  Future<void> addSession(PokerSession session) async {
    await _box.add(session.toJson());
  }

  // セッションを更新
  Future<void> updateSession(int index, PokerSession session) async {
    await _box.putAt(index, session.toJson());
  }

  // セッションを削除
  Future<void> deleteSession(int index) async {
    await _box.deleteAt(index);
  }

  // すべてのデータをクリア
  Future<void> clearAll() async {
    await _box.clear();
  }

  // JSON配列からデータをインポート
  Future<void> importFromJson(List<Map<String, dynamic>> jsonData) async {
    for (var json in jsonData) {
      final session = PokerSession.fromJson(json);
      await addSession(session);
    }
  }

  // Mapからセッションに変換
  PokerSession _mapToSession(Map<String, dynamic> map) {
    return PokerSession(
      id: map['id'] ?? '',
      date: DateTime.parse(map['date']),
      ringProfit: map['ring'] ?? 0,
      tournamentProfit: map['tournament'] ?? 0,
      purchase: map['purchase'] ?? 0,
      totalChange: map['total_change'] ?? 0,
      balance: map['balance'] ?? 0,
      notes: map['notes'],
    );
  }

  // 統計情報を計算
  Map<String, dynamic> getStatistics() {
    final sessions = getAllSessions();
    if (sessions.isEmpty) {
      return {
        'total_sessions': 0,
        'total_ring': 0,
        'total_tournament': 0,
        'total_profit': 0,
        'avg_profit': 0.0,
        'win_rate': 0.0,
      };
    }

    int totalRing = 0;
    int totalTournament = 0;
    int totalProfit = 0;
    int winCount = 0;

    for (var session in sessions) {
      totalRing += session.ringProfit;
      totalTournament += session.tournamentProfit;
      totalProfit += session.totalChange;
      if (session.totalChange > 0) {
        winCount++;
      }
    }

    return {
      'total_sessions': sessions.length,
      'total_ring': totalRing,
      'total_tournament': totalTournament,
      'total_profit': totalProfit,
      'avg_profit': totalProfit / sessions.length,
      'win_rate': (winCount / sessions.length) * 100,
    };
  }
}
