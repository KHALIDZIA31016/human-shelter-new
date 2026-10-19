import 'package:flutter/widgets.dart';

/// Responsive helpers. Design base is a 375 x 812 phone.
///
/// Usage: `16.w`, `12.h`, `14.sp`, `10.r` (after [ScreenUtils.init]).
class ScreenUtils {
  ScreenUtils._();

  static double _width = 375;
  static double _height = 812;

  /// Call from `MaterialApp.builder` so values follow rotation / resize.
  static void init(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    _width = size.width;
    _height = size.height;
  }

  static double get width => _width;
  static double get height => _height;
  static bool get isTablet => _width >= 600;

  /// Widest a content column may grow on tablets / landscape.
  static const double maxContentWidth = 640;

  static double get _ws => (_width / 375).clamp(0.85, 1.2);
  static double get _hs => (_height / 812).clamp(0.85, 1.2);
}

extension ScreenNum on num {
  double get w => this * ScreenUtils._ws;
  double get h => this * ScreenUtils._hs;
  double get sp => this * ScreenUtils._ws;
  double get r => this * ScreenUtils._ws;
}
