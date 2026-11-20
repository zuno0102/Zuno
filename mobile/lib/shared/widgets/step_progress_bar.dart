import 'package:flutter/material.dart';
import 'package:zuno/core/theme/app_colors.dart';

/// One stop on a [StepProgressBar]: its name and, once reached, a short line under it (a date).
class ProgressStop {
  const ProgressStop({required this.label, this.caption});

  final String label;
  final String? caption;
}

/// Where an order is on its way, left to right, as shops show it: dots joined by a line, filled up
/// to the step reached, the current one ringed. A journey that ended early ([stoppedAt]) shows a red
/// dot there and fades the steps it never reached.
class StepProgressBar extends StatelessWidget {
  const StepProgressBar({
    required this.stops,
    required this.reached,
    this.stoppedAt,
    super.key,
  });

  final List<ProgressStop> stops;

  /// The last stop reached, from 0; -1 for none. Every stop before it reads as done.
  final int reached;

  /// The stop that ended the journey early (e.g. Cancelled), drawn red; null when it did not.
  final int? stoppedAt;

  static const dotSize = 14.0;
  static const lineThickness = 3.0;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final done = AppColors.status(StatusTone.success, theme.brightness);
    final stop = AppColors.status(StatusTone.danger, theme.brightness);
    final idle = theme.colorScheme.outlineVariant;
    final last = stoppedAt ?? reached;

    Color dotColor(int i) {
      if (i == stoppedAt) return stop;
      return i <= reached ? done : idle;
    }

    // A line into stop i is filled when i is done or is where the journey stopped.
    Color lineInto(int i) {
      if (i == stoppedAt) return stop;
      return i <= reached ? done : idle;
    }

    return Row(
      key: const ValueKey('step-progress-bar'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var i = 0; i < stops.length; i++)
          Expanded(
            child: Opacity(
              // Steps after an early end were never going to happen.
              opacity: stoppedAt != null && i > stoppedAt! ? 0.4 : 1,
              child: Column(
                children: [
                  SizedBox(
                    height: dotSize,
                    child: Row(
                      children: [
                        Expanded(
                          child: i == 0
                              ? const SizedBox.shrink()
                              : Container(
                                  height: lineThickness,
                                  color: lineInto(i),
                                ),
                        ),
                        _Dot(color: dotColor(i), current: i == last),
                        Expanded(
                          child: i == stops.length - 1
                              ? const SizedBox.shrink()
                              : Container(
                                  height: lineThickness,
                                  color: lineInto(i + 1),
                                ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    stops[i].label,
                    key: ValueKey('step-progress-$i'),
                    textAlign: TextAlign.center,
                    style: theme.textTheme.labelSmall?.copyWith(
                      fontWeight: i <= last ? FontWeight.w700 : null,
                      color: i == stoppedAt
                          ? stop
                          : i <= last
                          ? theme.colorScheme.onSurface
                          : theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  if (stops[i].caption case final caption?)
                    Text(
                      caption,
                      textAlign: TextAlign.center,
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                        fontSize: 10,
                      ),
                    ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

class _Dot extends StatelessWidget {
  const _Dot({required this.color, required this.current});

  final Color color;
  final bool current;

  @override
  Widget build(BuildContext context) => Container(
    width: StepProgressBar.dotSize,
    height: StepProgressBar.dotSize,
    decoration: BoxDecoration(
      color: color,
      shape: BoxShape.circle,
      boxShadow: current
          ? [BoxShadow(color: color.withValues(alpha: 0.35), spreadRadius: 4)]
          : null,
    ),
  );
}
