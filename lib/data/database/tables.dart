import 'package:drift/drift.dart';

/// 持仓表
class Positions extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get symbol => text().withLength(min: 1, max: 20)();
  TextColumn get name => text().withLength(min: 1, max: 100)();
  TextColumn get market => text()(); // sh, sz, hk, us
  RealColumn get quantity => real()();
  RealColumn get avgCost => real()();
  TextColumn get platform => text()(); // BrokerageType.name
  TextColumn get currency => text().withDefault(const Constant('CNY'))();
  DateTimeColumn get createdAt =>
      dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt =>
      dateTime().withDefault(currentDateAndTime)();
}

/// 行情缓存表
class PriceCache extends Table {
  TextColumn get symbol => text()();
  TextColumn get market => text()();
  RealColumn get currentPrice => real()();
  RealColumn get prevClose => real().withDefault(const Constant(0))();
  RealColumn get changePct => real().withDefault(const Constant(0))();
  TextColumn get stockName => text().withDefault(const Constant(''))();
  DateTimeColumn get updatedAt =>
      dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {symbol};
}
