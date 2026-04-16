import 'package:flutter/material.dart';
import '../../models/enums.dart';

/// 券商平台选择器
class PlatformSelector extends StatelessWidget {
  final BrokerageType selected;
  final ValueChanged<BrokerageType> onChanged;

  const PlatformSelector({
    super.key,
    required this.selected,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      children: BrokerageType.values.map((type) {
        final isSelected = type == selected;
        return ChoiceChip(
          label: Text(type.label),
          selected: isSelected,
          onSelected: (_) => onChanged(type),
        );
      }).toList(),
    );
  }
}

/// 市场选择器
class MarketSelector extends StatelessWidget {
  final StockMarket selected;
  final ValueChanged<StockMarket> onChanged;

  const MarketSelector({
    super.key,
    required this.selected,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: StockMarket.values.map((market) {
        final isSelected = market == selected;
        return ChoiceChip(
          label: Text(market.label),
          selected: isSelected,
          onSelected: (_) => onChanged(market),
        );
      }).toList(),
    );
  }
}
