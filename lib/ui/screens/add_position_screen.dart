import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/repositories/transaction_repository.dart';
import '../../models/enums.dart';
import '../../providers/database_provider.dart';
import '../widgets/platform_selector.dart';

class AddPositionScreen extends ConsumerStatefulWidget {
  final int? editPositionId;
  final String? initialSymbol;
  final String? initialName;
  final StockMarket? initialMarket;
  final double? initialQuantity;
  final double? initialAvgCost;
  final BrokerageType? initialPlatform;
  final PositionDirection? initialDirection;

  const AddPositionScreen({
    super.key,
    this.editPositionId,
    this.initialSymbol,
    this.initialName,
    this.initialMarket,
    this.initialQuantity,
    this.initialAvgCost,
    this.initialPlatform,
    this.initialDirection,
  });

  bool get isEditing => editPositionId != null;

  @override
  ConsumerState<AddPositionScreen> createState() => _AddPositionScreenState();
}

class _AddPositionScreenState extends ConsumerState<AddPositionScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _symbolController;
  late final TextEditingController _nameController;
  late final TextEditingController _quantityController;
  late final TextEditingController _costController;
  late StockMarket _selectedMarket;
  late BrokerageType _selectedPlatform;
  late PositionDirection _selectedDirection;
  bool _isSaving = false;
  bool _isDeleting = false;
  bool _isLookingUp = false;
  Timer? _debounceTimer;

  @override
  void initState() {
    super.initState();
    _symbolController =
        TextEditingController(text: widget.initialSymbol ?? '');
    _nameController = TextEditingController(text: widget.initialName ?? '');
    _quantityController = TextEditingController(
        text: widget.initialQuantity?.toString() ?? '');
    _costController = TextEditingController(
        text: widget.initialAvgCost?.toString() ?? '');
    _selectedMarket = widget.initialMarket ?? StockMarket.sh;
    _selectedPlatform = widget.initialPlatform ?? BrokerageType.futu;
    _selectedDirection = widget.initialDirection ?? PositionDirection.long;

    // 监听代码输入，自动推断市场
    _symbolController.addListener(_onSymbolChanged);
  }

  void _onSymbolChanged() {
    if (widget.isEditing) return;
    final text = _symbolController.text.trim();
    // 基金 / 期货都是用户手动指定的市场，不要让自动推断覆盖
    if (!_selectedMarket.isFund && !_selectedMarket.isFutures) {
      final guess = StockMarket.guessFromSymbol(text);
      if (guess != null && guess != _selectedMarket) {
        setState(() => _selectedMarket = guess);
      }
    }

    // 防抖：输入停止 800ms 后自动查询名称
    _debounceTimer?.cancel();
    if (text.isNotEmpty && _nameController.text.isEmpty) {
      _debounceTimer = Timer(const Duration(milliseconds: 800), () {
        _lookupStockName(text);
      });
    }
  }

  Future<void> _lookupStockName(String symbol) async {
    // 基金/期货走对应 API；股票则用自动推断
    final StockMarket market;
    if (_selectedMarket.isFund) {
      market = StockMarket.fund;
    } else if (_selectedMarket.isFutures) {
      market = StockMarket.futures;
    } else {
      market = StockMarket.guessFromSymbol(symbol) ?? _selectedMarket;
    }
    setState(() => _isLookingUp = true);
    try {
      final priceService = ref.read(stockPriceServiceProvider);
      final quote = await priceService.lookupStock(symbol.toUpperCase(), market);
      if (quote != null && mounted) {
        // 只在名称为空或还是上次查询结果时自动填充
        if (_nameController.text.isEmpty ||
            _nameController.text == _lastLookedUpName) {
          _nameController.text = quote.name;
          _lastLookedUpName = quote.name;
        }
      }
    } catch (_) {
      // 查询失败不影响用户操作
    } finally {
      if (mounted) setState(() => _isLookingUp = false);
    }
  }

  String? _lastLookedUpName;

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _symbolController.dispose();
    _nameController.dispose();
    _quantityController.dispose();
    _costController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.isEditing ? '编辑持仓' : '添加持仓'),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // 券商平台
            Text('选择平台',
                style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 8),
            PlatformSelector(
              selected: _selectedPlatform,
              onChanged: (v) => setState(() => _selectedPlatform = v),
            ),

            const SizedBox(height: 20),

            // 市场
            Text('选择市场',
                style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 8),
            MarketSelector(
              selected: _selectedMarket,
              onChanged: (v) {
                setState(() {
                  _selectedMarket = v;
                  // 切到不支持做空的市场时，强制重置为做多
                  if (!v.supportsShort) {
                    _selectedDirection = PositionDirection.long;
                  }
                });
                // 切换市场后，如果有代码就重新查一次名称
                final symbol = _symbolController.text.trim();
                if (symbol.isNotEmpty && !widget.isEditing) {
                  // 清空旧名称以允许重新填充（只在是上次自动填充的情况下）
                  if (_nameController.text == _lastLookedUpName) {
                    _nameController.clear();
                  }
                  _debounceTimer?.cancel();
                  _lookupStockName(symbol);
                }
              },
            ),

            // 交易方向（仅期货市场显示）
            if (_selectedMarket.supportsShort) ...[
              const SizedBox(height: 20),
              Text('交易方向',
                  style: Theme.of(context).textTheme.titleSmall),
              const SizedBox(height: 8),
              SegmentedButton<PositionDirection>(
                segments: PositionDirection.values
                    .map((d) => ButtonSegment(
                          value: d,
                          label: Text(d.label),
                          icon: Icon(
                            d.isLong
                                ? Icons.trending_up
                                : Icons.trending_down,
                            size: 18,
                          ),
                        ))
                    .toList(),
                selected: {_selectedDirection},
                onSelectionChanged: (set) =>
                    setState(() => _selectedDirection = set.first),
              ),
            ],

            const SizedBox(height: 20),

            // 代码
            TextFormField(
              controller: _symbolController,
              decoration: InputDecoration(
                labelText: _selectedMarket.isFund
                    ? '基金代码'
                    : _selectedMarket.isFutures
                        ? '合约代码'
                        : '股票代码',
                hintText: _selectedMarket.isFund
                    ? '如 000071、025492'
                    : _selectedMarket.isFutures
                        ? '如 MA609、rb2610、au2512'
                        : '如 600519、00700、AAPL',
                border: const OutlineInputBorder(),
                prefixIcon: const Icon(Icons.tag),
              ),
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? '请输入代码' : null,
            ),

            const SizedBox(height: 16),

            // 名称
            TextFormField(
              controller: _nameController,
              decoration: InputDecoration(
                labelText: _selectedMarket.isFund
                    ? '基金名称'
                    : _selectedMarket.isFutures
                        ? '合约名称'
                        : '股票名称',
                hintText: '输入代码后自动查询，也可手动输入',
                border: const OutlineInputBorder(),
                prefixIcon: const Icon(Icons.business_outlined),
                suffixIcon: _isLookingUp
                    ? const Padding(
                        padding: EdgeInsets.all(12),
                        child: SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      )
                    : null,
              ),
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? '请输入名称' : null,
            ),

            const SizedBox(height: 16),

            // 持仓数量 / 份额 / 手数
            TextFormField(
              controller: _quantityController,
              decoration: InputDecoration(
                labelText: _selectedMarket.isFund
                    ? '持仓份额'
                    : _selectedMarket.isFutures
                        ? '持仓手数'
                        : '持仓数量（股）',
                hintText: _selectedMarket.isFund
                    ? '如 1000.00'
                    : _selectedMarket.isFutures
                        ? '如 10'
                        : '如 100',
                border: const OutlineInputBorder(),
                prefixIcon: Icon(
                  _selectedMarket.isFund
                      ? Icons.donut_small_outlined
                      : _selectedMarket.isFutures
                          ? Icons.inventory_2_outlined
                          : Icons.numbers,
                ),
                suffixText: _selectedMarket.isFund
                    ? '份'
                    : _selectedMarket.isFutures
                        ? '手'
                        : '股',
              ),
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'[\d.]')),
              ],
              validator: (v) {
                if (v == null || v.trim().isEmpty) return '请输入数量';
                final val = double.tryParse(v);
                if (val == null || val <= 0) return '请输入有效数量';
                return null;
              },
            ),

            const SizedBox(height: 16),

            // 平均成本
            TextFormField(
              controller: _costController,
              decoration: InputDecoration(
                labelText: _selectedMarket.isFund
                    ? '成本净值'
                    : _selectedMarket.isFutures
                        ? '开仓均价'
                        : '平均成本价',
                hintText: _selectedMarket.isFund
                    ? '如 1.0487'
                    : _selectedMarket.isFutures
                        ? '如 2900'
                        : '如 1800.50',
                border: const OutlineInputBorder(),
                prefixIcon: const Icon(Icons.payments_outlined),
                suffixText: _selectedMarket.currencySymbol,
              ),
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'[\d.]')),
              ],
              validator: (v) {
                if (v == null || v.trim().isEmpty) return '请输入成本价';
                final val = double.tryParse(v);
                if (val == null || val <= 0) return '请输入有效价格';
                return null;
              },
            ),

            const SizedBox(height: 32),

            // 保存按钮
            FilledButton.icon(
              onPressed: _isSaving ? null : _save,
              icon: _isSaving
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white),
                    )
                  : const Icon(Icons.save),
              label: Text(widget.isEditing ? '保存修改' : '添加持仓'),
              style: FilledButton.styleFrom(
                minimumSize: const Size(double.infinity, 48),
              ),
            ),

            // 编辑模式下：加仓/减仓 + 交易记录 + 删除
            if (widget.isEditing) ...[
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => _showTradeDialog(isBuy: true),
                      icon: Icon(Icons.add_circle_outline,
                          color: Colors.red.shade700),
                      label: Text('加仓',
                          style: TextStyle(color: Colors.red.shade700)),
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size(0, 44),
                        side: BorderSide(color: Colors.red.shade300),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => _showTradeDialog(isBuy: false),
                      icon: Icon(Icons.remove_circle_outline,
                          color: Colors.green.shade700),
                      label: Text('减仓',
                          style: TextStyle(color: Colors.green.shade700)),
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size(0, 44),
                        side: BorderSide(color: Colors.green.shade300),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              // 交易记录列表
              _TransactionHistory(
                symbol: _symbolController.text.trim().toUpperCase(),
                ref: ref,
              ),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: _isSaving || _isDeleting ? null : _delete,
                icon: _isDeleting
                    ? SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.red.shade700,
                        ),
                      )
                    : Icon(Icons.delete_outline, color: Colors.red.shade700),
                label: Text(
                  '删除持仓',
                  style: TextStyle(color: Colors.red.shade700),
                ),
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size(double.infinity, 48),
                  side: BorderSide(color: Colors.red.shade300),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _delete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('确认删除'),
        content: Text(
          '确定要删除 ${_nameController.text.trim()} 的持仓吗？此操作无法撤销。',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('删除'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;
    setState(() => _isDeleting = true);

    try {
      await ref
          .read(positionRepositoryProvider)
          .delete(widget.editPositionId!);
      if (mounted) {
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('删除失败: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isDeleting = false);
    }
  }

  /// 加仓/减仓弹窗
  Future<void> _showTradeDialog({required bool isBuy}) async {
    final qtyCtrl = TextEditingController();
    final priceCtrl = TextEditingController();
    final currentQty = double.tryParse(_quantityController.text) ?? 0;
    final currentAvg = double.tryParse(_costController.text) ?? 0;
    final symbol = _symbolController.text.trim().toUpperCase();
    final name = _nameController.text.trim();
    final theme = Theme.of(context);
    final color = isBuy ? Colors.red.shade700 : Colors.green.shade700;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(
          children: [
            Icon(
              isBuy ? Icons.add_circle_outline : Icons.remove_circle_outline,
              color: color,
              size: 22,
            ),
            const SizedBox(width: 8),
            Text(isBuy ? '加仓 $symbol' : '减仓 $symbol'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (!isBuy)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Text(
                  '当前持仓 ${currentQty.toStringAsFixed(0)}，均价 ${currentAvg.toStringAsFixed(2)}',
                  style: theme.textTheme.bodySmall,
                ),
              ),
            TextField(
              controller: qtyCtrl,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'[\d.]')),
              ],
              decoration: InputDecoration(
                labelText: isBuy ? '买入数量' : '卖出数量',
                border: const OutlineInputBorder(),
                suffixText: _selectedMarket.isFund
                    ? '份'
                    : _selectedMarket.isFutures
                        ? '手'
                        : '股',
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: priceCtrl,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'[\d.]')),
              ],
              decoration: InputDecoration(
                labelText: isBuy ? '买入价格' : '卖出价格',
                border: const OutlineInputBorder(),
                suffixText: _selectedMarket.currencySymbol,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () {
              final qty = double.tryParse(qtyCtrl.text);
              final price = double.tryParse(priceCtrl.text);
              if (qty == null || qty <= 0 || price == null || price <= 0) {
                ScaffoldMessenger.of(ctx).showSnackBar(
                  const SnackBar(content: Text('请输入有效的数量和价格')),
                );
                return;
              }
              if (!isBuy && qty > currentQty) {
                ScaffoldMessenger.of(ctx).showSnackBar(
                  SnackBar(content: Text('卖出数量不能超过持仓 $currentQty')),
                );
                return;
              }
              Navigator.pop(ctx, true);
            },
            style: FilledButton.styleFrom(backgroundColor: color),
            child: Text(isBuy ? '确认加仓' : '确认减仓'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    final tradeQty = double.parse(qtyCtrl.text);
    final tradePrice = double.parse(priceCtrl.text);

    try {
      final txnRepo = ref.read(transactionRepositoryProvider);
      final posRepo = ref.read(positionRepositoryProvider);

      if (isBuy) {
        // 加仓：加权均价
        final newQty = currentQty + tradeQty;
        final newAvg =
            (currentQty * currentAvg + tradeQty * tradePrice) / newQty;

        // 1. 记录交易
        await txnRepo.addTransaction(
          symbol: symbol,
          name: name,
          market: _selectedMarket.name,
          platform: _selectedPlatform.name,
          direction: _selectedDirection.name,
          type: TransactionType.buy,
          quantity: tradeQty,
          price: tradePrice,
          currency: _selectedMarket.currency,
        );

        // 2. 更新持仓
        _quantityController.text = newQty.toString();
        _costController.text = newAvg.toStringAsFixed(4);
        await posRepo.update(
          id: widget.editPositionId!,
          symbol: symbol,
          name: name,
          market: _selectedMarket,
          quantity: newQty,
          avgCost: newAvg,
          platform: _selectedPlatform,
          direction: _selectedDirection,
        );
      } else {
        // 减仓：计算已实现盈亏
        final realizedPnl =
            (tradePrice - currentAvg) * tradeQty *
            (_selectedDirection.isShort ? -1 : 1);
        final newQty = currentQty - tradeQty;

        // 1. 记录交易（含已实现盈亏）
        await txnRepo.addTransaction(
          symbol: symbol,
          name: name,
          market: _selectedMarket.name,
          platform: _selectedPlatform.name,
          direction: _selectedDirection.name,
          type: TransactionType.sell,
          quantity: tradeQty,
          price: tradePrice,
          currency: _selectedMarket.currency,
          realizedPnl: realizedPnl,
        );

        // 2. 更新持仓（均价不变，数量减少）
        if (newQty <= 0) {
          // 全部清仓：删除持仓
          await posRepo.delete(widget.editPositionId!);
          if (mounted) {
            Navigator.pop(context, true);
            return;
          }
        } else {
          _quantityController.text = newQty.toString();
          await posRepo.update(
            id: widget.editPositionId!,
            symbol: symbol,
            name: name,
            market: _selectedMarket,
            quantity: newQty,
            avgCost: currentAvg,
            platform: _selectedPlatform,
            direction: _selectedDirection,
          );
        }
      }

      if (mounted) {
        setState(() {}); // 刷新交易记录列表
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(isBuy
                ? '加仓成功 +$tradeQty @$tradePrice'
                : '减仓成功 -$tradeQty @$tradePrice'),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('操作失败: $e')),
        );
      }
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);

    try {
      final repo = ref.read(positionRepositoryProvider);
      final symbol = _symbolController.text.trim().toUpperCase();
      final name = _nameController.text.trim();
      final quantity = double.parse(_quantityController.text.trim());
      final avgCost = double.parse(_costController.text.trim());

      if (widget.isEditing) {
        // 更新
        await repo.update(
          id: widget.editPositionId!,
          symbol: symbol,
          name: name,
          market: _selectedMarket,
          quantity: quantity,
          avgCost: avgCost,
          platform: _selectedPlatform,
          direction: _selectedDirection,
        );
      } else {
        // 新增
        await repo.add(
          symbol: symbol,
          name: name,
          market: _selectedMarket,
          quantity: quantity,
          avgCost: avgCost,
          platform: _selectedPlatform,
          direction: _selectedDirection,
        );
      }

      if (mounted) {
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('保存失败: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }
}

/// 交易记录列表组件
class _TransactionHistory extends StatelessWidget {
  final String symbol;
  final WidgetRef ref;

  const _TransactionHistory({required this.symbol, required this.ref});

  @override
  Widget build(BuildContext context) {
    if (symbol.isEmpty) return const SizedBox.shrink();
    final theme = Theme.of(context);

    return FutureBuilder<List<StockTransaction>>(
      future: ref.read(transactionRepositoryProvider).getTransactions(symbol),
      builder: (ctx, snap) {
        final txns = snap.data;
        if (txns == null || txns.isEmpty) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '交易记录',
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                '暂无交易记录，可通过上方"加仓/减仓"记录',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          );
        }

        // 已实现盈亏总和
        final totalRealized =
            txns.fold(0.0, (sum, t) => sum + t.realizedPnl);

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  '交易记录',
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
                if (totalRealized != 0)
                  Text(
                    '已实现 ${totalRealized >= 0 ? "+" : "-"}¥${totalRealized.abs().toStringAsFixed(2)}',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: totalRealized >= 0
                          ? Colors.red.shade700
                          : Colors.green.shade700,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            ...txns.map((t) {
              final isBuy = t.isBuy;
              final color =
                  isBuy ? Colors.red.shade700 : Colors.green.shade700;
              final dateStr =
                  '${t.tradedAt.month.toString().padLeft(2, '0')}-${t.tradedAt.day.toString().padLeft(2, '0')}';
              final unit = t.market == 'fund'
                  ? '份'
                  : t.market == 'futures'
                      ? '手'
                      : '股';

              return Container(
                padding:
                    const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
                decoration: BoxDecoration(
                  border: Border(
                    bottom: BorderSide(
                      color: theme.dividerColor.withValues(alpha: 0.3),
                    ),
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: color.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        isBuy ? '买' : '卖',
                        style: TextStyle(
                          color: color,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${t.quantity.toStringAsFixed(0)} $unit @ ¥${t.price.toStringAsFixed(2)}',
                            style: theme.textTheme.bodyMedium,
                          ),
                          Text(
                            dateStr,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (t.isSell && t.realizedPnl != 0)
                      Text(
                        '${t.realizedPnl >= 0 ? "+" : "-"}¥${t.realizedPnl.abs().toStringAsFixed(2)}',
                        style: TextStyle(
                          color: t.realizedPnl >= 0
                              ? Colors.red.shade700
                              : Colors.green.shade700,
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                      ),
                  ],
                ),
              );
            }),
          ],
        );
      },
    );
  }
}
