import 'package:flutter/material.dart';
import 'package:zuno/core/router/push_screen.dart';
import 'package:zuno/features/booking/presentation/screens/booking_chat_screen.dart';
import 'package:zuno/features/rental/domain/entities/rental_customer.dart';
import 'package:zuno/features/rental/domain/entities/rental_stock.dart';
import 'package:zuno/features/rental/presentation/providers/rental_order_providers.dart';
import 'package:zuno/features/rental/presentation/screens/rental_order_detail_screen.dart';
import 'package:zuno/features/rental/presentation/widgets/rental_order_card.dart';

/// The business and the customer talking about one rent order. The app's own chat screen, as a
/// service chat uses it, fed from the Rent server instead.
class RentalOrderChatScreen extends StatelessWidget {
  const RentalOrderChatScreen({
    required this.order,
    this.audience = RentalAudience.business,
    this.canOpenOrder = true,
    super.key,
  });

  final RentalOrder order;

  /// Who is writing: the business, or the customer.
  final RentalAudience audience;

  /// Off when the chat was opened from the order itself, so its title does not lead back there.
  final bool canOpenOrder;

  @override
  Widget build(BuildContext context) => ChatScreen(
    title: order.itemName.isEmpty
        ? '${order.quantity} pcs'
        : '${order.quantity} × ${order.itemName}',
    counterpartName: rentalCounterpartName(order, audience),
    messages: rentalOrderConversationProvider(order.id, audience),
    onSend: (ref, body) => ref
        .read(rentalOrderConversationProvider(order.id, audience).notifier)
        .send(body),
    onOpenOrder: canOpenOrder
        ? (context) => pushScreen(
            context,
            RentalOrderDetailScreen(order: order, audience: audience),
          )
        : null,
  );
}
