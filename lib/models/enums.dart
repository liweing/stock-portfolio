/// 券商平台类型
enum BrokerageType {
  futu('富途'),
  tiger('老虎'),
  xueqiu('雪球'),
  aShareBroker('A股券商'),
  other('其他');

  final String label;
  const BrokerageType(this.label);

  static BrokerageType fromName(String name) {
    return BrokerageType.values.firstWhere(
      (e) => e.name == name,
      orElse: () => BrokerageType.other,
    );
  }
}

/// 股票市场
enum StockMarket {
  sh('沪市', 'CNY', '¥'),
  sz('深市', 'CNY', '¥'),
  hk('港股', 'HKD', 'HK\$'),
  us('美股', 'USD', '\$');

  final String label;
  final String currency;
  final String currencySymbol;
  const StockMarket(this.label, this.currency, this.currencySymbol);

  static StockMarket fromName(String name) {
    return StockMarket.values.firstWhere(
      (e) => e.name == name,
      orElse: () => StockMarket.us,
    );
  }

  /// 根据股票代码自动推断市场
  static StockMarket? guessFromSymbol(String symbol) {
    final trimmed = symbol.trim();
    if (trimmed.isEmpty) return null;

    // 纯数字6位
    if (RegExp(r'^\d{6}$').hasMatch(trimmed)) {
      final first = trimmed[0];
      if (first == '6') return StockMarket.sh;
      if (first == '0' || first == '3') return StockMarket.sz;
    }
    // 纯数字5位 -> 港股
    if (RegExp(r'^\d{5}$').hasMatch(trimmed)) {
      return StockMarket.hk;
    }
    // 字母开头 -> 美股
    if (RegExp(r'^[A-Za-z]').hasMatch(trimmed)) {
      return StockMarket.us;
    }
    return null;
  }

  /// 获取腾讯 API 前缀
  String get tencentPrefix {
    switch (this) {
      case StockMarket.sh:
        return 'sh';
      case StockMarket.sz:
        return 'sz';
      case StockMarket.hk:
        return 'hk';
      case StockMarket.us:
        return 'us';
    }
  }
}
