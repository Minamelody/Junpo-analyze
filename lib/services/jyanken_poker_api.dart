import 'package:http/http.dart' as http;
import 'dart:convert';
import '../models/poker_session.dart';

class JyankenPokerAPI {
  // プロキシサーバーのURL
  // 本番環境: 環境変数 API_BASE_URL を設定
  // ローカル/同一ドメイン: '/proxy'
  static const String proxyUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: '/proxy',
  );
  final http.Client _client = http.Client();
  String? _sessionId;
  
  // 🔒 タイムアウト設定
  static const Duration _timeout = Duration(seconds: 30);
  
  // 🔒 入力検証
  bool _validateEmail(String email) {
    final emailRegex = RegExp(r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$');
    return emailRegex.hasMatch(email) && email.length <= 254;
  }
  
  bool _validateMonth(String month) {
    final monthRegex = RegExp(r'^\d{4}-(0[1-9]|1[0-2])$');
    return monthRegex.hasMatch(month);
  }
  
  bool _validateStoreId(String storeId) {
    final id = int.tryParse(storeId);
    return id != null && id >= 1 && id <= 100;
  }

  // 🔒 ログイン処理（入力検証＋タイムアウト）
  Future<bool> login(String email, String password) async {
    try {
      // 🔒 入力検証
      if (!_validateEmail(email)) {
        throw Exception('Invalid email format');
      }
      
      if (password.length < 6 || password.length > 128) {
        throw Exception('Invalid password length');
      }
      
      final response = await _client.post(
        Uri.parse('$proxyUrl/api/login'),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: json.encode({
          'email': email.trim(),
          'password': password,
        }),
      ).timeout(_timeout);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] == true) {
          _sessionId = data['session_id'];
          return true;
        }
      }
      
      return false;
    } catch (e) {
      // エラーログ（デバッグ用）
      
      return false;
    }
  }
  
  // 🔒 ログアウト処理
  Future<void> logout() async {
    if (_sessionId == null) return;
    
    try {
      await _client.post(
        Uri.parse('$proxyUrl/api/logout'),
        headers: {
          'X-Session-ID': _sessionId!,
          'Content-Type': 'application/json',
        },
      ).timeout(_timeout);
    } catch (e) {
      // エラーを無視（セッションクリーンアップ）
      
    } finally {
      _sessionId = null;
    }
  }

  // 🔒 チップ履歴を取得（期間指定＋入力検証）
  Future<List<PokerSession>> fetchChipHistory({
    required String storeId,
    String? month,
  }) async {
    if (_sessionId == null) {
      return [];
    }

    try {
      // 🔒 入力検証
      if (!_validateStoreId(storeId)) {
        throw Exception('Invalid store ID');
      }
      
      if (month != null && !_validateMonth(month)) {
        throw Exception('Invalid month format');
      }
      
      final uri = month != null
          ? Uri.parse('$proxyUrl/api/chip_histories?month=$month&store_id=$storeId')
          : Uri.parse('$proxyUrl/api/chip_histories?store_id=$storeId');

      final response = await _client.get(
        uri,
        headers: {
          'X-Session-ID': _sessionId!,
          'Accept': 'application/json',
        },
      ).timeout(_timeout);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] == true) {
          final List<dynamic> sessions = data['data'];
          return sessions.map((session) => PokerSession.fromJson(session)).toList();
        }
      } else if (response.statusCode == 401) {
        // セッション期限切れ
        _sessionId = null;
      }

      return [];
    } catch (e) {
      
      return [];
    }
  }

  // 店舗一覧を取得
  // 🔒 店舗一覧を取得（タイムアウト＋セッション検証）
  Future<List<Map<String, String>>> fetchStores() async {
    if (_sessionId == null) {
      return [];
    }

    try {
      final response = await _client.get(
        Uri.parse('$proxyUrl/api/stores'),
        headers: {
          'X-Session-ID': _sessionId!,
          'Accept': 'application/json',
        },
      ).timeout(_timeout);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] == true) {
          final List<dynamic> stores = data['stores'];
          return stores.map((store) => {
            'id': store['id'].toString(),
            'name': store['name'].toString(),
          }).toList();
        }
      } else if (response.statusCode == 401) {
        // セッション期限切れ
        _sessionId = null;
      }

      return [];
    } catch (e) {
      
      return [];
    }
  }

  // 🔒 複数月のデータを取得（バッチ処理版＋入力検証）
  Future<List<PokerSession>> fetchMultipleMonths({
    required String storeId,
    required List<String> months,
  }) async {
    if (_sessionId == null || months.isEmpty) {
      return [];
    }

    try {
      // 🔒 入力検証
      if (!_validateStoreId(storeId)) {
        throw Exception('Invalid store ID');
      }
      
      // 🔒 月数制限（DoS対策）
      if (months.length > 24) {
        throw Exception('Too many months requested');
      }
      
      // 🔒 各月の形式検証
      for (final month in months) {
        if (!_validateMonth(month)) {
          throw Exception('Invalid month format: $month');
        }
      }
      
      // バッチAPIを使用して一度に全ての月のデータを取得
      final response = await _client.post(
        Uri.parse('$proxyUrl/api/chip_histories_batch'),
        headers: {
          'Content-Type': 'application/json',
          'X-Session-ID': _sessionId!,
          'Accept': 'application/json',
        },
        body: json.encode({
          'store_id': storeId,
          'months': months,
        }),
      ).timeout(_timeout);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] == true) {
          final List<dynamic> sessions = data['data'];
          return sessions.map((session) => PokerSession.fromJson(session)).toList();
        }
      } else if (response.statusCode == 401) {
        // セッション期限切れ
        _sessionId = null;
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
