import 'package:flutter/material.dart';
import 'package:zuno/core/theme/app_colors.dart';
import 'package:zuno/features/booking/domain/entities/booking.dart';
import 'package:zuno/shared/domain/track_state.dart';
import 'package:zuno/shared/widgets/status_track.dart';

/// The four tracks an order runs on, in the order each one opens.
///
/// They cascade: confirming opens the event, the day opening the work, starting the work opening
/// the wages. Reading down the list tells the business what it is waiting on and what that will
/// unlock — which one word could never do, because "in progress" meant either that the day had
/// come or that the crew was on site, and "completed" either that the work was done or that
/// everyone had been paid.
class BookingTracks extends StatelessWidget {
  const BookingTracks({required this.booking, super.key});

  final Booking booking;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        StatusTrackList(
          tracks: [
            TrackRow(
              name: 'Event',
              state: booking.eventState(),
              detail: booking.eventDetail(),
            ),
            TrackRow(
              name: 'Crew',
              state: _crewState,
              detail: booking.crewStatusLabel,
            ),
            TrackRow(
              name: 'Work',
              state: booking.workState(),
              detail: booking.workDetail(),
            ),
            // Blank for a customer, and blank when the screen did not ask — not the same as
            // owing nothing, so the line is left off rather than guessed at.
            if (booking.hasWageInfo)
              TrackRow(
                name: 'Payment',
                state: booking.paymentState(),
                detail: booking.paymentDetail(),
              ),
          ],
        ),
        if (booking.isEntirelyComplete) ...[
          const SizedBox(height: 12),
          Row(
            children: [
              Icon(
                Icons.verified_rounded,
                size: 16,
                color: AppColors.status(StatusTone.success, theme.brightness),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  'Finished and settled — counted on your profile',
                  style: theme.textTheme.bodySmall?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: AppColors.status(
                      StatusTone.success,
                      theme.brightness,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }

  /// Staffing read as a track. Derived from the server's own crew status so the line and the
  /// count behind it cannot disagree.
  TrackState get _crewState => switch (booking.crewStatus) {
    'Done' => TrackState.completed,
    'FullyStaffed' => TrackState.completed,
    'PartStaffed' => TrackState.inProgress,
    _ => booking.isPending ? TrackState.notStarted : TrackState.active,
  };
}
