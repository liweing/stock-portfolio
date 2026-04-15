import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
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

  const AddPositionScreen({
    super.key,
    this.editPositionId,
    this.initialSymbol,
    this.initialName,
    this.initialMarket,
    this.initialQuantity,
    this.initialAvgCost,
    this.initialPlatform,
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
  bool _isSaving = false;
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

    // 监听代码输入，自动推断市场
    _symbolController.addListener(_onSymbolChanged);
  }

  void _onSymbolChanged() {
    if (widget.isEditing) return;
    final text = _symbolController.text.trim();
    // 如果用户当前选的是"基金"，就不要自动推断为股票市场
    if (!_selectedMarket.isFund) {
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
    // 基金走基金 API，股票走股票 API
    final market = _selectedMarket.isFund
        ? StockMarket.fund
        : (StockMarket.guessFromSymbol(symbol) ?? _selectedMarket);
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
                setState(() => _selectedMarket = v);
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

            const SizedBox(height: 20),

            // 股票代码
            TextFormField(
              controller: _symbolController,
              decoration: const InputDecoration(
                labelText: '股票代码',
                hintText: '如 600519、00700、AAPL',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.tag),
              ),
              textCapitalization: TextCapitalization.characters,
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? '请输入股票代码' : null,
            ),

            const SizedBox(height: 16),

            // 股票名称
            TextFormField(
              controller: _nameController,
              decoration: InputDecoration(
                labelText: '股票名称',
                hintText: '输入代码后自动查询，也可手动输入',
                border: const OutlineInputBorder(),
                prefixIcon: const Icon(Icons.business),
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
                  (v == null || v.trim().isEmpty) ? '请输入股票名称' : null,
            ),

            const SizedBox(height: 16),

            // 持仓数量
            TextFormField(
              controller: _quantityController,
              decoration: const InputDecoration(
                labelText: '持仓数量（股）',
                hintText: '如 100',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.numbers),
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
                labelText: '平均成本价',
                hintText: '如 1800.50',
                border: const OutlineInputBorder(),
                prefixIcon: const Icon(Icons.attach_money),
                suffixText: _selectedMarket.currency,
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
          ],
        ),
      ),
    );
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
