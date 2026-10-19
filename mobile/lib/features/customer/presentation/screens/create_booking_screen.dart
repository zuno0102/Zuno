import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:zuno/core/utils/formatting.dart';
import 'package:zuno/features/booking/presentation/providers/customer_bookings_notifier.dart';
import 'package:zuno/features/customer/domain/entities/customer_service.dart';
import 'package:zuno/features/customer/domain/entities/service_variant.dart';
import 'package:zuno/shared/widgets/error_banner.dart';
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

  static const _pinMissingMessage = 'Pin the job location on the map before booking.';

  bool _isSubmitting = false;
  String? _errorMessage;

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

    setState(
      () => _scheduledDate = DateTime(
        date.year,
        date.month,
        date.day,
        time.hour,
        time.minute,
      ),
    );
  }

  /// Opens the map, then fills City, State and Pincode from the pin. They stay editable — the map
  /// is usually right, and the customer knows best when it is not. The house/street line is only
  /// filled when empty, so a typed house number is never overwritten.
  Future<void> _pickLocation() async {
    FocusScope.of(context).unfocus();
    final picked = await showLocationPinPicker(
      context,
      initialLatitude: _pin?.latitude,
      initialLongitude: _pin?.longitude,
    );
    if (picked == null || !mounted) return;

    setState(() {
      _pin = picked;
      _pinMissing = false;
      if (_errorMessage == _pinMissingMessage) _errorMessage = null;
      if (picked.city case final city?) _cityController.text = city;
      if (picked.state case final state?) _stateController.text = state;
      if (picked.postalCode case final code?) _postalCodeController.text = code;
      if (_addressLine1Controller.text.trim().isEmpty) {
        final street = [?picked.street, ?picked.locality].join(', ');
        if (street.isNotEmpty) _addressLine1Controller.text = street;
      }
    });
  }

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();
    final formOk = _formKey.currentState!.validate();
    if (_pin == null) {
      setState(() {
        _pinMissing = true;
        _errorMessage = _pinMissingMessage;
      });
      return;
    }
    if (!formOk) {
      return;
    }
    if (_scheduledDate == null) {
      setState(() => _errorMessage = 'Select a date and time for the service.');
      return;
    }

    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
    });

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
      setState(() => _errorMessage = e.toString());
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
              if (_errorMessage != null) ...[
                ErrorBanner(message: _errorMessage!),
                const SizedBox(height: 16),
              ],
              OutlinedButton.icon(
                onPressed: _pickScheduledDate,
                icon: const Icon(Icons.event_outlined),
                label: Text(
                  _scheduledDate == null
                      ? 'Select date & time'
                      : '${_scheduledDate!.toLocal()}'.substring(0, 16),
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
                pin: _pin,
                isMissing: _pinMissing,
                onPick: _pickLocation,
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
    required this.pin,
    required this.isMissing,
    required this.onPick,
  });

  final PickedLocation? pin;
  final bool isMissing;
  final VoidCallback onPick;

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

    final colour = isMissing ? theme.colorScheme.error : theme.colorScheme.primary;

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
              child: Icon(Icons.location_on, color: theme.colorScheme.onPrimary),
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
