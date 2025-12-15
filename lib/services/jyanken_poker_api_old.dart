import 'package:http/http.dart' as http;
import 'package:html/parser.dart' as html_parser;
import '../models/poker_session.dart';

class JyankenPokerAPI {
  static const String baseUrl = 'https://jyanken-poker.onrender.com';
  final http.Client _client = http.Client();
  String? _csrfToken;
  final Map<String, String> _cookies = {};

  // ログイン処理
  Future<bool> login(String email, String password) async {
    try {
      // ログインページにアクセスしてCSRFトークンを取得
      final loginPageResponse = await _client.get(
        Uri.parse('$baseUrl/users/sign_in'),
      );

      if (loginPageResponse.statusCode != 200) {
        return false;
      }

      // Cookieを保存
      _extractCookies(loginPageResponse.headers);

      // CSRFトークンを抽出
      final document = html_parser.parse(loginPageResponse.body);
      final tokenInput = document.querySelector('input[name="authenticity_token"]');
      if (tokenInput != null) {
        _csrfToken = tokenInput.attributes['value'];
      }

      if (_csrfToken == null) {
        return false;
      }

      // ログイン実行
      final loginResponse = await _client.post(
        Uri.parse('$baseUrl/users/sign_in'),
        headers: {
          'Content-Type': 'application/x-www-form-urlencoded',
          'Cookie': _buildCookieHeader(),
        },
        body: {
          'user[email]': email,
          'user[password]': password,
          'authenticity_token': _csrfToken!,
        },
      );

      // リダイレクト先のCookieも保存
      _extractCookies(loginResponse.headers);

      // ログイン成功判定
      // リダイレクトされた場合は成功
      if (loginResponse.statusCode == 302 || loginResponse.statusCode == 303) {
        return true;
      }
      
      // 200の場合は、ログインページではないことを確認
      if (loginResponse.statusCode == 200) {
        // ログイン後のページにリダイレクトされているか確認
        final finalUrl = loginResponse.request?.url.toString() ?? '';
        // リダイレクト先がstore_visit_applicationsなら成功
        return finalUrl.contains('store_visit_applications') || !finalUrl.contains('sign_in');
      }
      
      return false;
    } catch (e) {
      // エラー内容を出力
      if (e.toString().isNotEmpty) {
        // デバッグ用（本番環境では削除すること）
        // print('Login error: $e');
      }
      return false;
    }
  }

  // チップ履歴を取得（期間指定）
  Future<List<PokerSession>> fetchChipHistory({
    required String storeId,
    String? yearMonth, // 例: "2025-12" or null（全期間）
  }) async {
    try {
      final uri = yearMonth != null
          ? Uri.parse('$baseUrl/players/chip_histories?year_month=$yearMonth&store_id=$storeId')
          : Uri.parse('$baseUrl/players/chip_histories?store_id=$storeId');

      final response = await _client.get(
        uri,
        headers: {
          'Cookie': _buildCookieHeader(),
        },
      );

      if (response.statusCode != 200) {
        return [];
      }

      return _parseChipHistory(response.body);
    } catch (e) {
      return [];
    }
  }

  // 複数月のデータを取得
  Future<List<PokerSession>> fetchMultipleMonths({
    required String storeId,
    required List<String> yearMonths,
  }) async {
    final allSessions = <PokerSession>[];
    
    for (final yearMonth in yearMonths) {
      final sessions = await fetchChipHistory(
        storeId: storeId,
        yearMonth: yearMonth,
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

  // HTMLからチップ履歴を解析
  List<PokerSession> _parseChipHistory(String htmlContent) {
    final document = html_parser.parse(htmlContent);
    final sessions = <PokerSession>[];

    final dateDivs = document.querySelectorAll('.histories-date');

    for (final dateDiv in dateDivs) {
      try {
        // 日付を取得
        final dateText = dateDiv.text.trim();
        final dateMatch = RegExp(r'(\d{4})年(\d{1,2})月(\d{1,2})日').firstMatch(dateText);
        if (dateMatch == null) continue;

        final year = int.parse(dateMatch.group(1)!);
        final month = int.parse(dateMatch.group(2)!);
        final day = int.parse(dateMatch.group(3)!);
        final date = DateTime(year, month, day);

        // 累積残高を取得
        final balanceMatch = RegExp(r'([\d,]+)ポイント').firstMatch(dateText);
        final balance = balanceMatch != null
            ? int.parse(balanceMatch.group(1)!.replaceAll(',', ''))
            : 0;

        // 対応するテーブルを探す
        var nextElement = dateDiv.nextElementSibling;
        while (nextElement != null && !nextElement.classes.contains('histories-table')) {
          nextElement = nextElement.nextElementSibling;
        }

        if (nextElement == null) continue;

        // テーブルからデータを抽出
        final tbody = nextElement.querySelector('tbody');
        if (tbody == null) continue;

        final rows = tbody.querySelectorAll('tr');
        if (rows.length < 2) continue;

        // 2行目がデータ行
        final dataRow = rows[1];
        final cells = dataRow.querySelectorAll('td');

        if (cells.length < 3) continue;

        final ringText = cells[0].text.trim();
        final tournamentText = cells[1].text.trim();
        final purchaseText = cells[2].text.trim();

        final ring = int.tryParse(ringText.replaceAll(RegExp(r'[^\d-]'), '')) ?? 0;
        final tournament = int.tryParse(tournamentText.replaceAll(RegExp(r'[^\d-]'), '')) ?? 0;
        final purchase = int.tryParse(purchaseText.replaceAll(RegExp(r'[^\d-]'), '')) ?? 0;

        // 増減を取得
        final tfoot = nextElement.querySelector('tfoot');
        int totalChange = 0;
        if (tfoot != null) {
          final tfootCells = tfoot.querySelectorAll('td');
          if (tfootCells.isNotEmpty) {
            final changeText = tfootCells.last.text.trim();
            totalChange = int.tryParse(changeText.replaceAll(RegExp(r'[^\d-]'), '')) ?? 0;
          }
        }

        final session = PokerSession(
          id: '${date.millisecondsSinceEpoch}',
          date: date,
          ringProfit: ring,
          tournamentProfit: tournament,
          purchase: purchase,
          totalChange: totalChange,
          balance: balance,
        );

        sessions.add(session);
      } catch (e) {
        // エラーをスキップして次のセッションへ
        continue;
      }
    }

    return sessions;
  }

  // Cookieを抽出
  void _extractCookies(Map<String, String> headers) {
    // set-cookieヘッダーを全て取得（大文字小文字を区別しない）
    headers.forEach((key, value) {
      if (key.toLowerCase() == 'set-cookie') {
        // 複数のクッキーが含まれる場合、カンマで区切られていることがある
        // ただし、expires属性にもカンマが含まれるので注意
        final cookieParts = value.split(';');
        if (cookieParts.isNotEmpty) {
          final mainPart = cookieParts[0];
          final parts = mainPart.split('=');
          if (parts.length >= 2) {
            final name = parts[0].trim();
            final cookieValue = parts.sublist(1).join('=').trim();
            _cookies[name] = cookieValue;
          }
        }
      }
    });
  }

  // Cookie headerを構築
  String _buildCookieHeader() {
    return _cookies.entries.map((e) => '${e.key}=${e.value}').join('; ');
  }

  // セッションをクリア（ログアウト）
  void clearSession() {
    _cookies.clear();
    _csrfToken = null;
  }

  // クライアントを閉じる
  void dispose() {
    _client.close();
    clearSession();
  }
}
