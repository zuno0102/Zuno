import 'package:flutter/material.dart';

/// The icon on a notification row, chosen from what the notification is about.
///
/// Keyed off the server's `kind` name, which is why the fallback matters: a server that grows a new
/// kind must show up as a notification with a generic icon, never as a missing row or a crash.
///
/// Grouped by what the person has to do about it rather than by which role it reaches. Somebody
/// scanning a list wants to tell "money arrived" from "answer needed" at a glance, and both of those
/// happen to several roles.
IconData notificationIcon(String kind) => switch (kind) {
  // Work being offered — the thing a worker opens the app for.
  'JobInvitation' || 'JobOfferConfirmed' || 'TeamInvitation' => Icons
      .person_add_alt_1_outlined,
  'JobAssignment' => Icons.assignment_ind_outlined,

  // Money.
  'WagePaid' => Icons.payments_outlined,
  'WageRaised' => Icons.trending_up,
  'PaymentDisputed' => Icons.report_gmailerrorred_outlined,

  // An order moving along.
  'BookingRequested' => Icons.add_shopping_cart_outlined,
  'BookingConfirmed' => Icons.event_available_outlined,
  'BookingTermsProposed' => Icons.handshake_outlined,
  'BookingCrewAssigned' => Icons.groups_outlined,
  'BookingWorkStarted' => Icons.play_circle_outline,
  'BookingCompleted' => Icons.star_outline,

  // Something falling through.
  'BookingCancelledByBusiness' ||
  'BookingCancelledByCustomer' ||
  'JobCancelled' => Icons.event_busy_outlined,
  'ApplicationRejected' => Icons.do_not_disturb_on_outlined,

  // Somebody answering.
  'NewApplicants' => Icons.how_to_reg_outlined,
  'OfferAnswered' || 'AssignmentAnswered' => Icons.mark_email_read_outlined,
  'WorkerFinishedWork' => Icons.task_alt_outlined,
  'RatingReceived' => Icons.grade_outlined,

  'ChatMessage' => Icons.chat_bubble_outline,

  // Anything this build has not heard of.
  _ => Icons.notifications_outlined,
};
