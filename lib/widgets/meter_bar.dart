import 'package:flutter/material.dart';

/// A labeled 0–100 meter whose bar glides to the current value.
/// The number shown is always the real state value, never the animated one.
class MeterBar extends StatelessWidget {
  const MeterBar({
    super.key,
    required this.label,
    required this.value,
    required this.color,
    this.reduceMotion = false,
  });

  final String label;
  final int value;
  final Color color;
  final bool reduceMotion;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Semantics(
      label: '$label $value out of 100',
      excludeSemantics: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Text(label, style: textTheme.titleSmall),
              const Spacer(),
              Text(
                '$value',
                key: ValueKey('$label-value'),
                style: textTheme.titleSmall,
              ),
            ],
          ),
          const SizedBox(height: 4),
          TweenAnimationBuilder<double>(
            tween: Tween<double>(end: value / 100),
            duration: reduceMotion
                ? Duration.zero
                : const Duration(milliseconds: 400),
            curve: Curves.easeOut,
            builder: (context, v, _) => ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: LinearProgressIndicator(
                value: v,
                minHeight: 12,
                color: color,
                backgroundColor: color.withValues(alpha: 0.18),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
