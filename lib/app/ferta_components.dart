import 'package:flutter/material.dart';

import 'ferta_theme.dart';

/// A compact, accessible count-up for values that have no configured range.
/// It adds motion without suggesting a nutrient threshold or soil-health score.
class FertaAnimatedNumber extends StatelessWidget {
  const FertaAnimatedNumber({
    super.key,
    required this.value,
    this.style,
    this.duration = const Duration(milliseconds: 650),
  });

  final num value;
  final TextStyle? style;
  final Duration duration;

  @override
  Widget build(BuildContext context) {
    final number = value.toDouble();
    final reducedMotion = MediaQuery.disableAnimationsOf(context);
    if (reducedMotion) {
      return Text(_format(number), style: style);
    }
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: number),
      duration: duration,
      curve: Curves.easeOutCubic,
      builder: (context, current, _) => Text(_format(current), style: style),
    );
  }

  static String _format(double value) => value == value.roundToDouble()
      ? value.toStringAsFixed(0)
      : value.toStringAsFixed(1);
}

class FertaSectionLabel extends StatelessWidget {
  const FertaSectionLabel({super.key, required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) => Row(
        children: [
          Container(
            width: 4,
            height: 20,
            decoration: BoxDecoration(
              color: FertaColors.leaf,
              borderRadius: BorderRadius.circular(FertaRadius.pill),
            ),
          ),
          const SizedBox(width: 10),
          ...children,
        ],
      );
}
