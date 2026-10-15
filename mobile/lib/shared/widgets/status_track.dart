import 'package:flutter/material.dart';
import 'package:zuno/core/theme/app_colors.dart';
import 'package:zuno/shared/domain/track_state.dart';

/// One strand of a job's progress.
class TrackRow {
  const TrackRow({
    required this.name,
    required this.state,
    required this.detail,
  });

  /// "Event", "Workers", "Payment".
  final String name;
  final TrackState state;

  /// What the state actually rests on — "₹2,000 owed", "4 of 4 hired".
  final String detail;
}

/// Shows how far a hiring has got along each of its strands at once.
///
/// A job is three things running in parallel — the event, the crew, and the wages — and they
/// finish at different times. Showing them together is what makes "the event is over but two
/// people are still owed money" readable at a glance, which a single overall status never could.
class StatusTrackList extends StatelessWidget {
  const StatusTrackList({required this.tracks, super.key});

  final List<TrackRow> tracks;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (var i = 0; i < tracks.length; i++)
          Padding(
            padding: EdgeInsets.only(bottom: i == tracks.length - 1 ? 0 : 8),
            child: _Track(track: tracks[i]),
          ),
      ],
    );
  }
}

class _Track extends StatelessWidget {
  const _Track({required this.track});

  final TrackRow track;

  static const _stateWords = {
    TrackState.notStarted: 'Not started',
    TrackState.active: 'Active',
    TrackState.inProgress: 'In progress',
    TrackState.completed: 'Completed',
    TrackState.lapsed: 'Lapsed',
  };

  StatusTone get _tone => switch (track.state) {
    TrackState.completed => StatusTone.success,
    TrackState.inProgress => StatusTone.progress,
    // Neutral, not the danger tone. A post nobody applied to is a disappointment, not a
    // fault — and colouring it like a failure implies a black mark the business has not
    // actually earned. It is simply not the success colour either.
    _ => StatusTone.waiting,
  };

  /// How many of the three steps are behind us. Drives the dots.
  int get _reached => switch (track.state) {
    TrackState.notStarted => 0,
    TrackState.active => 1,
    TrackState.inProgress => 2,
    TrackState.completed => 3,
    // Stops short of the last dot — the track ended without ever getting there.
    TrackState.lapsed => 1,
  };

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = AppColors.status(_tone, theme.brightness);
    final muted = theme.colorScheme.onSurfaceVariant;

    return Row(
      children: [
        SizedBox(
          width: 66,
          child: Text(
            track.name,
            style: theme.textTheme.bodySmall?.copyWith(
              color: muted,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        _Dots(reached: _reached, color: color, muted: muted.withValues(alpha: 0.28)),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            _stateWords[track.state]!,
            style: theme.textTheme.bodySmall?.copyWith(
              color: color,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        Flexible(
          child: Text(
            track.detail,
            textAlign: TextAlign.right,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.bodySmall?.copyWith(color: muted),
          ),
        ),
      ],
    );
  }
}

/// Three dots joined by short bars — filled up to whatever the track has reached.
class _Dots extends StatelessWidget {
  const _Dots({
    required this.reached,
    required this.color,
    required this.muted,
  });

  final int reached;
  final Color color;
  final Color muted;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var step = 1; step <= 3; step++) ...[
          if (step > 1)
            Container(width: 10, height: 2, color: step <= reached ? color : muted),
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: step <= reached ? color : Colors.transparent,
              border: Border.all(
                color: step <= reached ? color : muted,
                width: 1.5,
              ),
            ),
          ),
        ],
      ],
    );
  }
}
