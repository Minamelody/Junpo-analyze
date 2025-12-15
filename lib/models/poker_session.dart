class PokerSession {
  final String id;
  final DateTime date;
  final int ringProfit; // リングゲームの収支
  final int tournamentProfit; // トーナメントの収支
  final int purchase; // 購入額
  final int totalChange; // 合計増減
  final int balance; // 累積残高
  final String? notes; // メモ
  final String? storeName; // 店舗名

  PokerSession({
    required this.id,
    required this.date,
    required this.ringProfit,
    required this.tournamentProfit,
    required this.purchase,
    required this.totalChange,
    required this.balance,
    this.notes,
    this.storeName,
  });

  // 累積収支を計算（購入を除く純収支）
  int get netProfit => ringProfit + tournamentProfit;

  // JSONからの変換（外部データインポート用）
  factory PokerSession.fromJson(Map<String, dynamic> json) {
    return PokerSession(
      id: json['id'] ?? DateTime.now().millisecondsSinceEpoch.toString(),
      date: DateTime.parse(json['date']),
      ringProfit: json['ring'] ?? 0,
      tournamentProfit: json['tournament'] ?? 0,
      purchase: json['purchase'] ?? 0,
      totalChange: json['total_change'] ?? 0,
      balance: json['balance'] ?? 0,
      notes: json['notes'],
      storeName: json['store_name'],
    );
  }

  // JSONへの変換
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'date': date.toIso8601String(),
      'ring': ringProfit,
      'tournament': tournamentProfit,
      'purchase': purchase,
      'total_change': totalChange,
      'balance': balance,
      'notes': notes,
      'store_name': storeName,
    };
  }
}
