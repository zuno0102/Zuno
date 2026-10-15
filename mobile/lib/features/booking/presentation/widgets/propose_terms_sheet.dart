import 'package:flutter/material.dart';
import 'package:zuno/core/utils/formatting.dart';
import 'package:zuno/features/booking/domain/entities/booking.dart';

/// What was agreed: a crew size and the price that goes with it.
class ProposedTerms {
  const ProposedTerms({
    required this.workerCount,
    required this.price,
    this.message,
  });

  final int workerCount;
  final double price;
  final String? message;
}

/// Making an offer on an order, or countering one.
///
/// The same sheet for both sides — it is the same two numbers and a note either way. For a
/// per-person service the price is worked out as rate × people as you type, and shown with its
/// arithmetic, because the headcount is the thing being argued over and the money should be seen
/// to follow it. The figure is still editable: a business that wants to round down for a good
/// customer should be able to.
class ProposeTermsSheet extends StatefulWidget {
  const ProposeTermsSheet({
    required this.booking,
    required this.viewerIsBusiness,
    super.key,
  });

  final Booking booking;
  final bool viewerIsBusiness;

  static Future<ProposedTerms?> show(
    BuildContext context, {
    required Booking booking,
    required bool viewerIsBusiness,
  }) => showModalBottomSheet<ProposedTerms>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => ProposeTermsSheet(
      booking: booking,
      viewerIsBusiness: viewerIsBusiness,
    ),
  );

  @override
  State<ProposeTermsSheet> createState() => _ProposeTermsSheetState();
}

class _ProposeTermsSheetState extends State<ProposeTermsSheet> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _workerController;
  late final TextEditingController _priceController;
  final _messageController = TextEditingController();

  /// The per-head rate, for working the total out as the crew size changes.
  ///
  /// Only meaningful before terms are agreed: once an offer is accepted the order's price becomes
  /// the agreed total, and multiplying that again would be nonsense.
  double? get _perPersonRate =>
      widget.booking.isPricedPerPerson && !widget.booking.termsAreAgreed
      ? widget.booking.priceQuoted
      : null;

  @override
  void initState() {
    super.initState();

    // Countering starts from what the other side said, not from a blank box: the answer is
    // usually "nearly that", and retyping both numbers invites a mistake.
    final open = widget.booking.openProposal;
    final startingCrew = open?.workerCount ?? 0;

    _workerController = TextEditingController(
      text: startingCrew > 0 ? startingCrew.toString() : '',
    );
    _priceController = TextEditingController(
      text: open == null ? '' : open.price.toStringAsFixed(0),
    );

    _workerController.addListener(_recalculate);
  }

  @override
  void dispose() {
    _workerController
      ..removeListener(_recalculate)
      ..dispose();
    _priceController.dispose();
    _messageController.dispose();
    super.dispose();
  }

  /// Keeps the price in step with the crew size on a per-person job.
  void _recalculate() {
    final rate = _perPersonRate;
    if (rate == null) return;

    final count = int.tryParse(_workerController.text.trim());
    if (count == null || count < 1) return;

    final total = (rate * count).toStringAsFixed(0);
    if (_priceController.text != total) {
      _priceController.text = total;
    }
    setState(() {});
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;

    Navigator.of(context).pop(
      ProposedTerms(
        workerCount: int.parse(_workerController.text.trim()),
        price: double.parse(_priceController.text.trim()),
        message: _messageController.text.trim().isEmpty
            ? null
            : _messageController.text.trim(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final open = widget.booking.openProposal;
    final rate = _perPersonRate;
    final count = int.tryParse(_workerController.text.trim()) ?? 0;

    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                open == null ? 'Propose crew & price' : 'Counter their offer',
                style: theme.textTheme.titleLarge,
              ),
              const SizedBox(height: 2),
              Text(
                open == null
                    ? 'How many people will this job take?'
                    : 'They proposed ${open.workerCount} people for '
                          '${rupees(open.price)}.',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 18),

              TextFormField(
                controller: _workerController,
                keyboardType: TextInputType.number,
                autofocus: true,
                decoration: const InputDecoration(
                  labelText: 'People on the job',
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  final parsed = int.tryParse((value ?? '').trim());
                  if (parsed == null) return 'Enter a number.';
                  return parsed < 1 ? 'A job needs at least one person.' : null;
                },
              ),
              const SizedBox(height: 14),

              TextFormField(
                controller: _priceController,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: InputDecoration(
                  labelText: 'Price for the whole order (INR)',
                  border: const OutlineInputBorder(),
                  helperText: rate != null && count > 0
                      ? perPersonTotalLabel(rate, count)
                      : null,
                ),
                validator: (value) {
                  final parsed = double.tryParse((value ?? '').trim());
                  if (parsed == null) return 'Enter an amount.';
                  return parsed <= 0 ? 'Enter what the order will cost.' : null;
                },
              ),
              const SizedBox(height: 14),

              TextFormField(
                controller: _messageController,
                maxLines: 2,
                maxLength: 500,
                textCapitalization: TextCapitalization.sentences,
                decoration: InputDecoration(
                  labelText: 'Why? (optional)',
                  border: const OutlineInputBorder(),
                  hintText: widget.viewerIsBusiness
                      ? '400 guests needs 5 servers per 100'
                      : 'we have 2 of our own',
                ),
              ),

              const SizedBox(height: 6),
              FilledButton(
                onPressed: _submit,
                child: Text(open == null ? 'Send offer' : 'Send counter'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
