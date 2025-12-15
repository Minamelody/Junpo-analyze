import 'package:http/http.dart' as http;
import 'dart:convert';
import '../models/poker_session.dart';

class JyankenPokerAPI {
  // プロキシサーバーのURL（同じドメインなのでCORS問題なし）
  static const String proxyUrl = '/proxy';
  final http.Client _client = http.Client();
  String? _sessionId;

  // ログイン処理
  Future<bool> login(String email, String password) async {
    try {
      final response = await _client.post(
        Uri.parse('$proxyUrl/api/login'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'email': email,
          'password': password,
        }),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] == true) {
          _sessionId = data['session_id'];
          return true;
        }
      }
      
      return false;
    } catch (e) {
      return false;
    }
  }

  // チップ履歴を取得（期間指定）
  Future<List<PokerSession>> fetchChipHistory({
    required String storeId,
    String? month,  // 変更: yearMonth -> month
  }) async {
    if (_sessionId == null) {
      return [];
    }

    try {
      final uri = month != null
          ? Uri.parse('$proxyUrl/api/chip_histories?month=$month&store_id=$storeId')
          : Uri.parse('$proxyUrl/api/chip_histories?store_id=$storeId');

      final response = await _client.get(
        uri,
        headers: {
          'X-Session-ID': _sessionId!,
        },
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] == true) {
          final List<dynamic> sessions = data['data'];
          return sessions.map((session) => PokerSession.fromJson(session)).toList();
        }
      }

      return [];
    } catch (e) {
      return [];
    }
  }

  // 店舗一覧を取得
  Future<List<Map<String, String>>> fetchStores() async {
    if (_sessionId == null) {
      return [];
    }

    try {
      final response = await _client.get(
        Uri.parse('$proxyUrl/api/stores'),
        headers: {
          'X-Session-ID': _sessionId!,
        },
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] == true) {
          final List<dynamic> stores = data['stores'];
          return stores.map((store) => {
            'id': store['id'].toString(),
            'name': store['name'].toString(),
          }).toList();
        }
      }

      return [];
    } catch (e) {
      return [];
    }
  }

  // 複数月のデータを取得（バッチ処理版 - 高速）
  Future<List<PokerSession>> fetchMultipleMonths({
    required String storeId,
    required List<String> months,
  }) async {
    if (_sessionId == null || months.isEmpty) {
      return [];
    }

    try {
      // バッチAPIを使用して一度に全ての月のデータを取得
      final response = await _client.post(
        Uri.parse('$proxyUrl/api/chip_histories_batch'),
        headers: {
          'Content-Type': 'application/json',
          'X-Session-ID': _sessionId!,
        },
        body: json.encode({
          'store_id': storeId,
          'months': months,
        }),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] == true) {
          final List<dynamic> sessions = data['data'];
          return sessions.map((session) => PokerSession.fromJson(session)).toList();
        }
      }

      return [];
    } catch (e) {
      // バッチ取得失敗時は従来の逐次取得にフォールバック
      return _fetchMultipleMonthsSequential(storeId: storeId, months: months);
    }
  }

  // 従来の逐次取得メソッド（フォールバック用）
  Future<List<PokerSession>> _fetchMultipleMonthsSequential({
    required String storeId,
    required List<String> months,
  }) async {
    final allSessions = <PokerSession>[];
    
    for (final month in months) {
      final sessions = await fetchChipHistory(
        storeId: storeId,
        month: month,
      );
      allSessions.addAll(sessions);
    }

    // 日付順にソート（新しい順）
    allSessions.sort((a, b) => b.date.compareTo(a.date));
    
    // 重複を除去
    final uniqueSessions = <String, PokerSession>{};
    for (final session in allSessions) {
      final key = '${session.date.toIso8601String()}_${session.ringProfit}_${session.tournamentProfit}';
      uniqueSessions[key] = session;
    }
    
    return uniqueSessions.values.toList();
  }

  // セッションをクリア（ログアウト）
  void clearSession() {
    if (_sessionId != null) {
      _client.post(
        Uri.parse('$proxyUrl/api/logout'),
        headers: {
          'X-Session-ID': _sessionId!,
        },
      );
      _sessionId = null;
    }
  }

  // クライアントを閉じる
  void dispose() {
    clearSession();
    _client.close();
  }
}
