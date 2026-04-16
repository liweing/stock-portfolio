import 'package:supabase_flutter/supabase_flutter.dart';
import '../../models/enums.dart';

/// 云端持仓数据（Supabase 版本）
class CloudPosition {
  final int id;
  final String symbol;
  final String name;
  final String market;
  final double quantity;
  final double avgCost;
  final String platform;
  final String currency;
  final String direction; // 'long' / 'short'
  final DateTime createdAt;
  final DateTime updatedAt;

  CloudPosition({
    required this.id,
    required this.symbol,
    required this.name,
    required this.market,
    required this.quantity,
    required this.avgCost,
    required this.platform,
    required this.currency,
    required this.direction,
    required this.createdAt,
    required this.updatedAt,
  });

  factory CloudPosition.fromJson(Map<String, dynamic> json) => CloudPosition(
        id: json['id'] as int,
        symbol: json['symbol'] as String,
        name: json['name'] as String,
        market: json['market'] as String,
        quantity: (json['quantity'] as num).toDouble(),
        avgCost: (json['avg_cost'] as num).toDouble(),
        platform: json['platform'] as String,
        currency: json['currency'] as String? ?? 'CNY',
        direction: json['direction'] as String? ?? 'long',
        createdAt: DateTime.parse(json['created_at'] as String),
        updatedAt: DateTime.parse(json['updated_at'] as String),
      );
}

/// 云端持仓 Repository（基于 Supabase）
class CloudPositionRepository {
  final SupabaseClient _client;

  CloudPositionRepository(this._client);

  static const String _table = 'positions';

  String? get _userId => _client.auth.currentUser?.id;

  /// 监听所有持仓（实时流）
  Stream<List<CloudPosition>> watchAll() {
    final userId = _userId;
    if (userId == null) {
      return Stream.value([]);
    }
    return _client
        .from(_table)
        .stream(primaryKey: ['id'])
        .eq('user_id', userId)
        .order('created_at', ascending: false)
        .map((rows) => rows.map(CloudPosition.fromJson).toList());
  }

  /// 获取所有持仓（一次性）
  Future<List<CloudPosition>> getAll() async {
    final userId = _userId;
    if (userId == null) return [];
    final rows = await _client
        .from(_table)
        .select()
        .eq('user_id', userId)
        .order('created_at', ascending: false);
    return (rows as List)
        .map((r) => CloudPosition.fromJson(r as Map<String, dynamic>))
        .toList();
  }

  /// 添加持仓
  Future<void> add({
    required String symbol,
    required String name,
    required StockMarket market,
    required double quantity,
    required double avgCost,
    required BrokerageType platform,
    PositionDirection direction = PositionDirection.long,
  }) async {
    final userId = _userId;
    if (userId == null) throw Exception('未登录');
    await _client.from(_table).insert({
      'user_id': userId,
      'symbol': symbol.toUpperCase(),
      'name': name,
      'market': market.name,
      'quantity': quantity,
      'avg_cost': avgCost,
      'platform': platform.name,
      'currency': market.currency,
      'direction': direction.name,
    });
  }

  /// 更新持仓
  Future<void> update({
    required int id,
    required String symbol,
    required String name,
    required StockMarket market,
    required double quantity,
    required double avgCost,
    required BrokerageType platform,
    PositionDirection direction = PositionDirection.long,
  }) async {
    final userId = _userId;
    if (userId == null) throw Exception('未登录');
    await _client.from(_table).update({
      'symbol': symbol.toUpperCase(),
      'name': name,
      'market': market.name,
      'quantity': quantity,
      'avg_cost': avgCost,
      'platform': platform.name,
      'currency': market.currency,
      'direction': direction.name,
      'updated_at': DateTime.now().toIso8601String(),
    }).eq('id', id).eq('user_id', userId);
  }

  /// 删除持仓
  Future<void> delete(int id) async {
    final userId = _userId;
    if (userId == null) throw Exception('未登录');
    await _client.from(_table).delete().eq('id', id).eq('user_id', userId);
  }
}
