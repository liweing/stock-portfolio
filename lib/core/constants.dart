import 'package:flutter/material.dart';

/// API 配置
class ApiConfig {
  /// 价格缓存有效期（秒）
  static const int priceCacheTtl = 30;
}

/// 图表颜色
class ChartColors {
  static const List<Color> pieColors = [
    Color(0xFFE53935), // red
    Color(0xFF1E88E5), // blue
    Color(0xFF43A047), // green
    Color(0xFFFB8C00), // orange
    Color(0xFF8E24AA), // purple
    Color(0xFF00ACC1), // cyan
    Color(0xFFD81B60), // pink
    Color(0xFF6D4C41), // brown
    Color(0xFF546E7A), // blue grey
    Color(0xFFFFB300), // amber
  ];

  static Color getColor(int index) {
    return pieColors[index % pieColors.length];
  }
}
