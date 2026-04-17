import 'package:supabase_flutter/supabase_flutter.dart';
import '../../models/portfolio_summary.dart';

/// 每日快照数据
class PortfolioSnapshot {
  final DateTime date;
  final double totalMarketValue;
  final double totalCost;
  final double totalPnl;
  final double dailyPnl;
  final int positionCount;

  PortfolioSnapshot({
    required this.date,
    required this.totalMarketValue,
    required this.totalCost,
    required this.totalPnl,
    required this.dailyPnl,
    required this.positionCount,
  });

  /// 累计收益率 %
  double get returnPercent =>
      totalCost > 0 ? (totalPnl / totalCost) * 100 : 0;

  factory PortfolioSnapshot.fromJson(Map<String, dynamic> json) =>
      PortfolioSnapshot(
        date: DateTime.parse(json['snapshot_date'] as String),
        totalMarketValue: (json['total_market_value'] as num).toDouble(),
        totalCost: (json['total_cost'] as num).toDouble(),
        totalPnl: (json['total_pnl'] as num).toDouble(),
        dailyPnl: (json['daily_pnl'] as num?)?.toDouble() ?? 0,
        positionCount: (json['position_count'] as num?)?.toInt() ?? 0,
      );
}

/// 快照 Repository
class SnapshotRepository {
  final SupabaseClient _client;

  SnapshotRepository(this._client);

  static const String _table = 'portfolio_snapshots';

  String? get _userId => _client.auth.currentUser?.id;

  /// 保存今日快照（如果今天已有则跳过）
  Future<void> saveTodaySnapshot(PortfolioSummary summary) async {
    final userId = _userId;
    if (userId == null || summary.isEmpty) return;

    final today = DateTime.now().toIso8601String().substring(0, 10);

    // upsert: 同一天只保留最新一条
    await _client.from(_table).upsert({
      'user_id': userId,
      'snapshot_date': today,
      'total_market_value': summary.totalMarketValue,
      'total_cost': summary.totalCost,
      'total_pnl': summary.totalPnl,
      'daily_pnl': summary.dailyPnl,
      'position_count': summary.positionDetails.length,
    }, onConflict: 'user_id,snapshot_date');
  }

  /// 查询指定日期范围的快照
  Future<List<PortfolioSnapshot>> getSnapshots({
    required DateTime from,
    required DateTime to,
  }) async {
    final userId = _userId;
    if (userId == null) return [];

    final fromStr = from.toIso8601String().substring(0, 10);
    final toStr = to.toIso8601String().substring(0, 10);

    final rows = await _client
        .from(_table)
        .select()
        .eq('user_id', userId)
        .gte('snapshot_date', fromStr)
        .lte('snapshot_date', toStr)
        .order('snapshot_date');

    return (rows as List)
        .map((r) => PortfolioSnapshot.fromJson(r as Map<String, dynamic>))
        .toList();
  }

  /// 获取所有快照
  Future<List<PortfolioSnapshot>> getAllSnapshots() async {
    final userId = _userId;
    if (userId == null) return [];

    final rows = await _client
        .from(_table)
        .select()
        .eq('user_id', userId)
        .order('snapshot_date');

    return (rows as List)
        .map((r) => PortfolioSnapshot.fromJson(r as Map<String, dynamic>))
        .toList();
  }
}
