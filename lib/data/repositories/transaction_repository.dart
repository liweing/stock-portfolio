import 'package:supabase_flutter/supabase_flutter.dart';

/// 交易类型
enum TransactionType {
  buy('买入'),
  sell('卖出');

  final String label;
  const TransactionType(this.label);
}

/// 交易记录
class StockTransaction {
  final int id;
  final String symbol;
  final String name;
  final String market;
  final String platform;
  final String direction;
  final String type; // 'buy' or 'sell'
  final double quantity;
  final double price;
  final String currency;
  final double realizedPnl;
  final DateTime tradedAt;
  final String note;

  StockTransaction({
    required this.id,
    required this.symbol,
    required this.name,
    required this.market,
    required this.platform,
    required this.direction,
    required this.type,
    required this.quantity,
    required this.price,
    required this.currency,
    required this.realizedPnl,
    required this.tradedAt,
    required this.note,
  });

  bool get isBuy => type == 'buy';
  bool get isSell => type == 'sell';

  factory StockTransaction.fromJson(Map<String, dynamic> json) =>
      StockTransaction(
        id: json['id'] as int,
        symbol: json['symbol'] as String,
        name: json['name'] as String,
        market: json['market'] as String,
        platform: json['platform'] as String,
        direction: json['direction'] as String? ?? 'long',
        type: json['type'] as String,
        quantity: (json['quantity'] as num).toDouble(),
        price: (json['price'] as num).toDouble(),
        currency: json['currency'] as String? ?? 'CNY',
        realizedPnl: (json['realized_pnl'] as num?)?.toDouble() ?? 0,
        tradedAt: DateTime.parse(json['traded_at'] as String),
        note: json['note'] as String? ?? '',
      );
}

/// 交易记录 Repository
class TransactionRepository {
  final SupabaseClient _client;

  TransactionRepository(this._client);

  static const String _table = 'transactions';

  String? get _userId => _client.auth.currentUser?.id;

  /// 记录一笔交易
  Future<void> addTransaction({
    required String symbol,
    required String name,
    required String market,
    required String platform,
    required String direction,
    required TransactionType type,
    required double quantity,
    required double price,
    required String currency,
    double realizedPnl = 0,
    DateTime? tradedAt,
    String note = '',
  }) async {
    final userId = _userId;
    if (userId == null) throw Exception('未登录');
    await _client.from(_table).insert({
      'user_id': userId,
      'symbol': symbol,
      'name': name,
      'market': market,
      'platform': platform,
      'direction': direction,
      'type': type.name,
      'quantity': quantity,
      'price': price,
      'currency': currency,
      'realized_pnl': realizedPnl,
      'traded_at': (tradedAt ?? DateTime.now()).toIso8601String(),
      'note': note,
    });
  }

  /// 查询某支持仓的交易记录（按时间倒序）
  Future<List<StockTransaction>> getTransactions(String symbol) async {
    final userId = _userId;
    if (userId == null) return [];
    final rows = await _client
        .from(_table)
        .select()
        .eq('user_id', userId)
        .eq('symbol', symbol)
        .order('traded_at', ascending: false);
    return (rows as List)
        .map((r) => StockTransaction.fromJson(r as Map<String, dynamic>))
        .toList();
  }

  /// 查询某支持仓的已实现盈亏总和
  Future<double> getTotalRealizedPnl(String symbol) async {
    final txns = await getTransactions(symbol);
    return txns.fold<double>(0.0, (sum, t) => sum + t.realizedPnl);
  }

  /// 查询所有交易记录（全局，最近 N 条）
  Future<List<StockTransaction>> getRecentTransactions({int limit = 50}) async {
    final userId = _userId;
    if (userId == null) return [];
    final rows = await _client
        .from(_table)
        .select()
        .eq('user_id', userId)
        .order('traded_at', ascending: false)
        .limit(limit);
    return (rows as List)
        .map((r) => StockTransaction.fromJson(r as Map<String, dynamic>))
        .toList();
  }
}
