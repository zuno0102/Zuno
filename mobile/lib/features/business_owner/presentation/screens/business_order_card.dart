import 'package:flutter/material.dart';
import 'package:zuno/core/utils/formatting.dart';
import 'package:zuno/features/booking/domain/entities/booking.dart';
import 'package:zuno/features/booking/presentation/widgets/booking_status_chip.dart';
import 'package:zuno/features/booking/presentation/widgets/order_code.dart';
import 'package:zuno/features/business_owner/presentation/screens/business_booking_detail_screen.dart';
import 'package:zuno/shared/widgets/call_icon_button.dart';
import 'package:zuno/shared/widgets/message_icon_button.dart';
import 'package:zuno/shared/widgets/status_with_actions.dart';
import 'package:zuno/core/router/push_screen.dart';

/// One booking on the Bookings tab: its code, what was booked, who for and when, its one status,
/// and the message and call buttons for the customer. Tapping it opens the order.
class BusinessOrderCard extends StatelessWidget {
  const BusinessOrderCard({required this.order, super.key});

  final Booking order;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final canMessage = order.canBeMessaged;
    final canCall = order.canBeCalled && order.customerPhone != null;

    // A plain row rather than a ListTile. A ListTile takes its height from its text alone, which
    // left the status and the buttons about 62px to share: they were squeezed together and the
    // buttons shrunk below a comfortable tap size. Laid out like this, the card grows to fit
    // whichever side is taller, so the status, a real gap and normal buttons all fit.
    return Card(
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () =>
            pushScreen(context, BusinessBookingDetailScreen(booking: order)),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 12, 12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // The order code first. A business running three weddings at once needs
                    // something it can say out loud and match against the hiring post it raised.
                    if (order.reference.isNotEmpty)
                      OrderCode(code: order.reference, compact: true),
                    const SizedBox(height: 4),
                    Text(
                      order.variantName ?? order.serviceName,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    if (order.variantName != null)
                      Text(order.serviceName, style: theme.textTheme.bodySmall),
                    Text(order.customerName, style: theme.textTheme.bodyMedium),
                    const SizedBox(height: 4),
                    Text(
                      '${formatDate(order.scheduledDate)} · '
                      '${formatTime(order.scheduledDate)}',
                      style: theme.textTheme.bodyMedium,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              StatusWithActions(
                // One status, and the one a customer would recognise. The work, crew and wage
                // tracks belong to the other tab — this list is for reading, not working.
                status: BookingStatusChip(order: order),
                actions: [
                  // Where a conversation starts from this end. The Messages tab only lists
                  // orders somebody has already written on, so without this the business could
                  // only ever reply to a customer who wrote first.
                  if (canMessage)
                    MessageIconButton(
                      bookingId: order.id,
                      title: order.variantName ?? order.serviceName,
                      // The customer, since this is the business reading it.
                      counterpartName: order.customerName,
                      tooltip: 'Message customer',
                      iconSize: 22,
                    ),
                  if (canCall)
                    CallIconButton(
                      phoneNumber: order.customerPhone!,
                      tooltip: 'Call customer',
                      iconSize: 22,
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
