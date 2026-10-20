import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:zuno/core/utils/formatting.dart';
import 'package:zuno/features/booking/presentation/providers/customer_bookings_notifier.dart';
import 'package:zuno/features/customer/domain/entities/customer_service.dart';
import 'package:zuno/features/customer/domain/entities/service_coverage.dart';
import 'package:zuno/features/customer/presentation/providers/customer_providers.dart';
import 'package:zuno/features/customer/domain/entities/service_variant.dart';
import 'package:zuno/shared/widgets/primary_button.dart';
import 'package:zuno/shared/widgets/app_messages.dart';
import 'package:zuno/shared/widgets/job_location_card.dart';
import 'package:zuno/shared/widgets/location_pin_picker.dart';

class CreateBookingScreen extends ConsumerStatefulWidget {
  const CreateBookingScreen({
    required this.businessName,
    required this.service,
    this.variant,
    super.key,
  });

  final String businessName;
  final CustomerService service;

  /// When the service has variants, the specific sub-item the customer picked (e.g. "Chenda
  /// Melam" under a "Band Set" service). Null when booking a plain, variant-less service.
  final ServiceVariant? variant;

  @override
  ConsumerState<CreateBookingScreen> createState() =>
      _CreateBookingScreenState();
}

class _CreateBookingScreenState extends ConsumerState<CreateBookingScreen> {
  final _formKey = GlobalKey<FormState>();
  final _notesController = TextEditingController();
  final _addressLine1Controller = TextEditingController();
  final _addressLine2Controller = TextEditingController();
  final _cityController = TextEditingController();
  final _stateController = TextEditingController();
  final _postalCodeController = TextEditingController();

  DateTime? _scheduledDate;

  /// The exact spot of the job, pinned on a map. Required: a typed address alone is how workers
  /// ended up at the wrong house.
  PickedLocation? _pin;

  /// Set when somebody tried to book without a pin, so the pin tile can say so in red.
  bool _pinMissing = false;

  static const _pinMissingMessage =
      'Pin the job location on the map before booking.';

  /// Set when somebody tried to book without a date, so the date button can say so.
  bool _dateMissing = false;

  /// Where the form scrolls to when something there needs attention. The Confirm button is at the
  /// bottom; a message shown at the top of a long form is a message nobody sees.
  final _dateKey = GlobalKey();
  final _pinKey = GlobalKey();

  /// Whether the service is offered at [_pin], asked as soon as it is pinned. Null until the
  /// answer arrives, or when the check could not be made — the server still refuses the booking
  /// then, so a failed check never blocks the customer here.
  ServiceCoverage? _coverage;

  /// The check in flight, so a quick Confirm waits for it rather than racing past it.
  Future<void>? _coverageCheck;

  /// Bumped on every new pin, so an answer for a pin the customer has since moved is ignored.
  int _coverageRequest = 0;

  bool _isSubmitting = false;

  /// One controller per question the business asks, keyed by the question's id.
  ///
  /// Built from the service rather than declared here: the boxes are whatever this business
  /// typed, so a caterer's form and a painter's form are different forms.
  late final Map<String, TextEditingController> _answerControllers = {
    for (final question in widget.service.questions)
      question.id: TextEditingController(),
  };

  @override
  void dispose() {
    _notesController.dispose();
    _addressLine1Controller.dispose();
    _addressLine2Controller.dispose();
    _cityController.dispose();
    _stateController.dispose();
    _postalCodeController.dispose();
    for (final controller in _answerControllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _pickScheduledDate() async {
    final now = DateTime.now();
    final date = await showDatePicker(
      context: context,
      initialDate: now.add(const Duration(days: 1)),
      firstDate: now,
      lastDate: now.add(const Duration(days: 90)),
    );
    if (date == null || !mounted) {
      return;
    }

    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(now),
    );
    if (time == null) {
      return;
    }

    setState(() {
      _scheduledDate = DateTime(
        date.year,
        date.month,
        date.day,
        time.hour,
        time.minute,
      );
      _dateMissing = false;
    });
  }

  /// What the last pin wrote into each address box, so the next pin knows which boxes are still
  /// its own to change.
  final Map<TextEditingController, String> _filledByPin = {};

  /// Opens the map, then fills the address from the pin. Every box stays editable — the map is
  /// usually right, and the customer knows best when it is not.
  ///
  /// A box is filled only while it is empty or still holds what the previous pin put there. That
  /// keeps a typed house number safe, and it also means moving the pin moves the address with it:
  /// before, the first pin's street stayed put, so a pin in Chennai sat over a Nagercoil address.
  Future<void> _pickLocation() async {
    FocusScope.of(context).unfocus();
    final picked = await showLocationPinPicker(
      context,
      initialLatitude: _pin?.latitude,
      initialLongitude: _pin?.longitude,
    );
    if (picked == null || !mounted) return;

    final street = [?picked.street, ?picked.locality].join(', ');
    setState(() {
      _pin = picked;
      _pinMissing = false;
      _fillFromPin(_addressLine1Controller, street);
      _fillFromPin(_cityController, picked.city);
      _fillFromPin(_stateController, picked.state);
      _fillFromPin(_postalCodeController, picked.postalCode);
      _coverage = null;
    });
    _coverageCheck = _checkCoverage(picked, announce: true);
  }

  void _fillFromPin(TextEditingController box, String? value) {
    final current = box.text.trim();
    final ours = current.isEmpty || current == _filledByPin[box];
    if (!ours) return; // Typed by the customer: theirs to keep.
    final next = value?.trim() ?? '';
    box.text = next;
    if (next.isEmpty) {
      _filledByPin.remove(box);
    } else {
      _filledByPin[box] = next;
    }
  }

  static const _notAvailableMessage =
      "Sorry, this service isn't available at your location yet.";

  /// Asks whether the service reaches [pin]. With [announce], a "not here" answer is also said in
  /// a message, so the customer hears it the moment they pin — not after filling in the rest.
  Future<void> _checkCoverage(
    PickedLocation pin, {
    bool announce = false,
  }) async {
    final request = ++_coverageRequest;
    final messenger = AppMessenger.of(context);
    try {
      final coverage = await ref
          .read(customerRepositoryProvider)
          .checkServiceCoverage(
            widget.service.id,
            latitude: pin.latitude,
            longitude: pin.longitude,
          );
      if (!mounted || request != _coverageRequest) return;
      setState(() => _coverage = coverage);
      if (announce && !coverage.isAvailable) {
        messenger.showInfo(_notAvailableMessage);
      }
    } catch (_) {
      // Left unknown on purpose: the booking itself is checked by the server.
    }
  }

  /// Brings [key]'s part of the form into view, where the customer can fix it.
  void _scrollTo(GlobalKey key) {
    final target = key.currentContext;
    if (target == null) return;
    Scrollable.ensureVisible(
      target,
      alignment: 0.15,
      duration: const Duration(milliseconds: 350),
      curve: Curves.easeOutCubic,
    );
  }

  /// The service does not reach the pin: say so gently, and take them to where it can be changed.
  void _explainNotAvailable(AppMessenger messenger) {
    messenger.showInfo(_notAvailableMessage);
    _scrollTo(_pinKey);
  }

  bool get _isUnavailable => _coverage?.isAvailable == false;

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();
    // Every problem is told where the customer is — in a message by the Confirm button they just
    // pressed — and the form moves to the part that needs them.
    final messenger = AppMessenger.of(context);
    if (_pin == null) {
      setState(() => _pinMissing = true);
      messenger.showInfo(_pinMissingMessage);
      _scrollTo(_pinKey);
      return;
    }
    await _coverageCheck;
    if (!mounted) return;
    if (_isUnavailable) {
      _explainNotAvailable(messenger);
      return;
    }
    // Only now: when the business cannot come here at all, marking the address boxes "Required"
    // would be noise around the one thing that matters.
    if (!_formKey.currentState!.validate()) {
      messenger.showInfo(
        'A few details are still missing — they are marked above.',
      );
      return;
    }
    if (_scheduledDate == null) {
      setState(() => _dateMissing = true);
      messenger.showInfo('Choose a date and time for the service.');
      _scrollTo(_dateKey);
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      await ref
          .read(customerBookingsProvider.notifier)
          .createBooking(
            businessServiceId: widget.service.id,
            businessServiceVariantId: widget.variant?.id,
            scheduledDate: _scheduledDate!,
            notes: _notesController.text.trim().isEmpty
                ? null
                : _notesController.text.trim(),
            addressLine1: _addressLine1Controller.text.trim(),
            addressLine2: _addressLine2Controller.text.trim().isEmpty
                ? null
                : _addressLine2Controller.text.trim(),
            city: _cityController.text.trim(),
            state: _stateController.text.trim(),
            postalCode: _postalCodeController.text.trim(),
            latitude: _pin!.latitude,
            longitude: _pin!.longitude,
            // Blank optional answers are left out rather than sent empty — an unanswered
            // question should leave no row at all, not a row saying nothing.
            answers: {
              for (final entry in _answerControllers.entries)
                if (entry.value.text.trim().isNotEmpty)
                  entry.key: entry.value.text.trim(),
            },
          );
      if (mounted) {
        context.showSuccessMessage('Booking request sent to the business.');
        Navigator.of(context).pop();
      }
    } catch (e) {
      // The server refused the area (an app that could not ask beforehand, or a business that
      // changed its districts meanwhile): ask again so the note under the pin can explain it.
      if (e.toString().contains("isn't available at your location")) {
        await _checkCoverage(_pin!);
        if (!mounted) return;
        if (_isUnavailable) {
          _explainNotAvailable(messenger);
          return;
        }
      }
      messenger.showFailure(e.toString());
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final variant = widget.variant;
    final displayName = variant?.name ?? widget.service.name;
    final price = variant?.price ?? widget.service.price;
    final priceType = variant?.priceType ?? widget.service.priceType;
    final label = priceLabel(price, priceType);

    return Scaffold(
      appBar: AppBar(title: const Text('Book Service')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              displayName,
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            Text(
                              widget.businessName,
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                            if (variant != null)
                              Text(
                                widget.service.name,
                                style: Theme.of(context).textTheme.bodySmall,
                              ),
                          ],
                        ),
                      ),
                      Text(
                        label,
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),
              OutlinedButton.icon(
                key: _dateKey,
                onPressed: _pickScheduledDate,
                style: _dateMissing
                    ? OutlinedButton.styleFrom(
                        side: BorderSide(
                          color: Theme.of(context).colorScheme.error,
                          width: 1.5,
                        ),
                      )
                    : null,
                icon: const Icon(Icons.event_outlined),
                label: Text(
                  _scheduledDate == null
                      ? 'Select date & time'
                      : '${formatDate(_scheduledDate!)} · ${formatTime(_scheduledDate!)}',
                ),
              ),
              const SizedBox(height: 16),

              // The business's own questions, drawn from whatever it typed. A service with none
              // shows nothing here and the form reads exactly as it always did.
              if (widget.service.questions.isNotEmpty) ...[
                Text(
                  'Tell them about the job',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 4),
                Text(
                  'This is what lets them send the right people.',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 12),
                for (final question in widget.service.questions) ...[
                  TextFormField(
                    controller: _answerControllers[question.id],
                    textCapitalization: TextCapitalization.sentences,
                    decoration: InputDecoration(
                      labelText: question.isRequired
                          ? question.prompt
                          : '${question.prompt} (optional)',
                      border: const OutlineInputBorder(),
                    ),
                    validator: (value) =>
                        question.isRequired && (value ?? '').trim().isEmpty
                        ? 'The business needs this to plan the job.'
                        : null,
                  ),
                  const SizedBox(height: 12),
                ],
                const SizedBox(height: 8),
              ],

              TextFormField(
                controller: _notesController,
                maxLines: 2,
                decoration: InputDecoration(
                  // Reworded once there are questions above it: "notes" alongside specific boxes
                  // reads as a second place to put the same things.
                  labelText: widget.service.questions.isEmpty
                      ? 'Notes for the business (optional)'
                      : 'Anything else? (optional)',
                  border: const OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 20),
              Text(
                'Service address',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 12),
              _JobLocationField(
                key: _pinKey,
                businessName: widget.businessName,
                pin: _pin,
                isMissing: _pinMissing,
                onPick: _pickLocation,
                unavailable: _isUnavailable ? _coverage : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _addressLine1Controller,
                decoration: const InputDecoration(
                  labelText: 'House / flat no., street',
                  border: OutlineInputBorder(),
                ),
                validator: (value) =>
                    (value == null || value.trim().isEmpty) ? 'Required' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _addressLine2Controller,
                decoration: const InputDecoration(
                  labelText: 'Landmark (optional)',
                  hintText: 'e.g. Opposite the church',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _cityController,
                      decoration: const InputDecoration(
                        labelText: 'City',
                        border: OutlineInputBorder(),
                      ),
                      validator: (value) =>
                          (value == null || value.trim().isEmpty)
                          ? 'Required'
                          : null,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextFormField(
                      controller: _stateController,
                      decoration: const InputDecoration(
                        labelText: 'State',
                        border: OutlineInputBorder(),
                      ),
                      validator: (value) =>
                          (value == null || value.trim().isEmpty)
                          ? 'Required'
                          : null,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _postalCodeController,
                keyboardType: TextInputType.number,
                maxLength: 6,
                decoration: const InputDecoration(
                  labelText: 'Pincode',
                  border: OutlineInputBorder(),
                  counterText: '',
                ),
                validator: (value) {
                  final text = (value ?? '').trim();
                  if (text.isEmpty) return 'Required';
                  if (!RegExp(r'^\d{6}$').hasMatch(text)) {
                    return 'Enter the 6-digit pincode';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 28),
              PrimaryButton(
                label: 'Confirm booking',
                onPressed: _submit,
                isLoading: _isSubmitting,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The required "where exactly" step of the address.
///
/// Before a pin: a prominent button, outlined in red once somebody tried to book without it. After:
/// the map preview with a Change button, so the customer can see the pin is on the right house.
class _JobLocationField extends StatelessWidget {
  const _JobLocationField({
    required this.businessName,
    required this.pin,
    required this.isMissing,
    required this.onPick,
    this.unavailable,
    super.key,
  });

  final String businessName;
  final PickedLocation? pin;
  final bool isMissing;
  final VoidCallback onPick;

  /// Set when the service is not offered at the pin, to say so right under it.
  final ServiceCoverage? unavailable;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final pin = this.pin;

    if (pin != null) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          JobLocationCard(
            key: const Key('bookingPinPreview'),
            latitude: pin.latitude,
            longitude: pin.longitude,
            addressLines: [pin.fullAddress ?? pin.summary],
            caption: 'Job location pinned',
            showActions: false,
          ),
          if (unavailable case final coverage?) ...[
            const SizedBox(height: 12),
            _NotAvailableNote(
              businessName: businessName,
              servedDistricts: coverage.servedDistricts,
              onChangePin: onPick,
            ),
          ] else
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                key: const Key('bookingChangePin'),
                onPressed: onPick,
                icon: const Icon(Icons.edit_location_alt_outlined, size: 18),
                label: const Text('Change pin'),
              ),
            ),
        ],
      );
    }

    final colour = isMissing
        ? theme.colorScheme.error
        : theme.colorScheme.primary;

    return InkWell(
      key: const Key('bookingPickPin'),
      onTap: onPick,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: colour.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: colour, width: isMissing ? 2 : 1.2),
        ),
        child: Row(
          children: [
            CircleAvatar(
              radius: 20,
              backgroundColor: colour,
              child: Icon(
                Icons.location_on,
                color: theme.colorScheme.onPrimary,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Pin the job location on the map',
                    style: theme.textTheme.titleSmall?.copyWith(color: colour),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    isMissing
                        ? 'Required — the worker uses this pin to find the place.'
                        : 'Use your current location or search, then drag to the exact house.',
                    style: theme.textTheme.bodySmall,
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right, color: colour),
          ],
        ),
      ),
    );
  }
}

/// What the customer sees under the pin when the business does not work there.
///
/// Worded as an apology with a way forward rather than an error: nobody did anything wrong. The
/// business simply works elsewhere, and the useful thing is to say where, and to offer the one
/// action that helps — moving the pin.
class _NotAvailableNote extends StatelessWidget {
  const _NotAvailableNote({
    required this.businessName,
    required this.servedDistricts,
    required this.onChangePin,
  });

  final String businessName;
  final List<String> servedDistricts;
  final VoidCallback onChangePin;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final where = joinPlaceNames(servedDistricts);

    return Container(
      key: const Key('bookingServiceUnavailable'),
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 6),
      decoration: BoxDecoration(
        color: scheme.primaryContainer.withValues(alpha: 0.45),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CircleAvatar(
                radius: 18,
                backgroundColor: scheme.primary.withValues(alpha: 0.12),
                child: Icon(
                  Icons.travel_explore_rounded,
                  size: 20,
                  color: scheme.primary,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "This service doesn't reach your location yet",
                      style: theme.textTheme.titleSmall?.copyWith(
                        color: scheme.onSurface,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      where.isEmpty
                          ? 'Move the pin to another address, or look for a service closer to you.'
                          : '$businessName works in $where. Move the pin to an address there, '
                                'or look for a service closer to you.',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: scheme.onSurfaceVariant,
                        height: 1.35,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton.icon(
              key: const Key('bookingChangePin'),
              onPressed: onChangePin,
              icon: const Icon(Icons.edit_location_alt_outlined, size: 18),
              label: const Text('Change location'),
            ),
          ),
        ],
      ),
    );
  }
}

/// "Kanyakumari", "Kanyakumari and Thiruvananthapuram", "A, B and C".
String joinPlaceNames(List<String> names) => switch (names.length) {
  0 => '',
  1 => names.single,
  _ => '${names.sublist(0, names.length - 1).join(', ')} and ${names.last}',
};
