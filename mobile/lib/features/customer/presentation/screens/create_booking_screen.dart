import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:zuno/core/utils/formatting.dart';
import 'package:zuno/features/booking/presentation/providers/customer_bookings_notifier.dart';
import 'package:zuno/features/customer/domain/entities/customer_service.dart';
import 'package:zuno/features/customer/domain/entities/service_variant.dart';
import 'package:zuno/shared/widgets/error_banner.dart';
import 'package:zuno/shared/widgets/primary_button.dart';
import 'package:zuno/shared/widgets/app_messages.dart';

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

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();
    if (!_formKey.currentState!.validate()) {
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
              TextFormField(
                controller: _addressLine1Controller,
                decoration: const InputDecoration(
                  labelText: 'Address line 1',
                  border: OutlineInputBorder(),
                ),
                validator: (value) =>
                    (value == null || value.trim().isEmpty) ? 'Required' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _addressLine2Controller,
                decoration: const InputDecoration(
                  labelText: 'Address line 2',
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
                decoration: const InputDecoration(
                  labelText: 'Postal code',
                  border: OutlineInputBorder(),
                ),
                validator: (value) =>
                    (value == null || value.trim().isEmpty) ? 'Required' : null,
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
