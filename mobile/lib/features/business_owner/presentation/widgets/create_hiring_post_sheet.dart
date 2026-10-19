import 'package:collection/collection.dart';
import 'package:zuno/features/booking/presentation/providers/business_bookings_notifier.dart';
import 'package:zuno/features/booking/presentation/widgets/order_code.dart';
import 'package:zuno/core/utils/formatting.dart';
import 'dart:typed_data';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:zuno/core/constants/api_constants.dart';
import 'package:zuno/features/booking/domain/entities/booking.dart';
import 'package:zuno/features/business_owner/domain/entities/business_service.dart';
import 'package:zuno/features/business_owner/presentation/providers/business_services_notifier.dart';
import 'package:zuno/features/hiring_post/domain/entities/hiring_post.dart';
import 'package:zuno/features/hiring_post/presentation/providers/business_hiring_posts_notifier.dart';
import 'package:zuno/shared/widgets/error_banner.dart';
import 'package:zuno/shared/widgets/job_location_card.dart';
import 'package:zuno/shared/widgets/location_pin_picker.dart';
import 'package:zuno/shared/widgets/primary_button.dart';

/// Opens the hiring-post form.
///
/// Pass [post] to edit an existing one. Pass [booking] to hire against a customer order: the
/// form arrives knowing the service, the date and the address, and every worker who accepts is
/// put on that order automatically.
///
/// What it does not fill in is how many people are wanted, how long the work runs, or the wage.
/// An order says nothing about any of those — they are the business's judgement, and a number
/// pre-filled is a number nobody stops to check.
Future<void> showCreateHiringPostSheet(
  BuildContext context, {
  HiringPost? post,
  Booking? booking,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (context) => _CreateHiringPostSheet(post: post, booking: booking),
  );
}

class _CreateHiringPostSheet extends ConsumerStatefulWidget {
  const _CreateHiringPostSheet({this.post, this.booking});

  final HiringPost? post;

  /// The order this crew is for, when the form was opened from a booking.
  final Booking? booking;

  @override
  ConsumerState<_CreateHiringPostSheet> createState() =>
      _CreateHiringPostSheetState();
}

class _CreateHiringPostSheetState
    extends ConsumerState<_CreateHiringPostSheet> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _titleController;
  late final TextEditingController _descriptionController;
  late final TextEditingController _locationController;
  late final TextEditingController _workersNeededController;
  late final TextEditingController _durationController;
  late final TextEditingController _salaryController;

  late String _salaryUnit;
  DateTime? _eventDate;
  Uint8List? _pickedImageBytes;
  bool _isSaving = false;
  String? _errorMessage;

  /// The order this post is being raised for. Set when the sheet was opened from a booking, or
  /// chosen here. Null means a standalone post for the business's own event.
  Booking? _linkedBooking;

  bool _isLoadingBookings = false;

  /// The point the business pinned for a post that is not using an order's own pin. Sent only when
  /// it was set or changed here, so editing a post's wording never moves it on the map.
  double? _pinLatitude;
  double? _pinLongitude;
  bool _pinChanged = false;

  /// The linked order already carries the customer's exact pin, which the server copies onto the
  /// post. Nothing to ask the business for.
  bool get _usesOrderPin =>
      !_isEditing && _linkedBooking?.latitude != null && _linkedBooking?.longitude != null;

  bool get _hasOwnPin => _pinLatitude != null && _pinLongitude != null;

  /// The kind of work this post is for — "Interior wall painting" rather than just "Painting".
  /// The single most useful thing on a post for a worker deciding whether to apply.
  String? _subCategoryId;

  HiringPost? get _post => widget.post;
  bool get _isEditing => _post != null;

  /// Once a worker is confirmed the advertised salary is contractually locked: it may be
  /// raised but never cut, and its unit is fixed. Enforced server-side in
  /// UpdateHiringPostCommandHandler — the UI only surfaces the rule earlier.
  bool get _isSalaryLocked => _post?.isSalaryLocked ?? false;

  @override
  void initState() {
    super.initState();
    final post = _post;
    final booking = widget.booking;

    _titleController = TextEditingController(
      text: post?.title ?? booking?.serviceName ?? '',
    );
    _descriptionController = TextEditingController(
      text: post?.description ?? '',
    );
    // The order already knows what kind of work it is — the package the customer chose carries
    // it — so the post starts from that rather than asking the business the same question.
    _subCategoryId = post?.serviceSubCategoryId ?? booking?.serviceSubCategoryId;

    // The order names a service, and the service knows its own description. Fetched after the
    // first frame because the services may not be loaded when the sheet opens.
    if (post == null && booking != null) {
      WidgetsBinding.instance.addPostFrameCallback(
        (_) => _applyBookingService(booking),
      );
    }
    _locationController = TextEditingController(
      text: post?.location ?? _bookingAddress(booking) ?? '',
    );
    // Left blank on a new post, even when it came from an order. How many people the job takes
    // and how long it runs are the business's judgement — an order says nothing about either,
    // and a number filled in for them is a number they will not stop to think about.
    _workersNeededController = TextEditingController(
      text: post == null ? '' : '${post.workersNeeded}',
    );
    _durationController = TextEditingController(
      text: post == null ? '' : '${post.durationMinutes}',
    );
    // Salary is left blank on purpose: it is the one thing an order cannot tell us.
    _salaryController = TextEditingController(
      text: post == null || post.salaryAmount == 0
          ? ''
          : trimAmount(post.salaryAmount),
    );
    _salaryUnit = post?.salaryUnit ?? 'PerEvent';
    _eventDate = post?.eventDate.toLocal() ?? booking?.scheduledDate.toLocal();
    _linkedBooking = booking;
    if (post != null && post.hasPosition) {
      _pinLatitude = post.latitude;
      _pinLongitude = post.longitude;
    }
  }

  /// Pins the job on a map — from search, or the phone's current location — and fills the
  /// location text from it when the business has not written their own directions there.
  Future<void> _pickLocation({required bool fromCurrentLocation}) async {
    FocusScope.of(context).unfocus();
    final picked = await showLocationPinPicker(
      context,
      title: 'Where is the job?',
      // Starting without a point makes the picker go to the phone's position first.
      initialLatitude: fromCurrentLocation ? null : _pinLatitude,
      initialLongitude: fromCurrentLocation ? null : _pinLongitude,
    );
    if (picked == null || !mounted) return;
    setState(() {
      _pinLatitude = picked.latitude;
      _pinLongitude = picked.longitude;
      _pinChanged = true;
      if (_locationController.text.trim().isEmpty) {
        _locationController.text = picked.summary;
      }
    });
  }

  void _clearPin() => setState(() {
    _pinLatitude = null;
    _pinLongitude = null;
    _pinChanged = false;
  });

  /// Chooses which customer order this crew is for, and fills in everything the order knows.
  Future<void> _pickBooking() async {
    List<Booking> bookings;

    setState(() => _isLoadingBookings = true);
    try {
      // Awaited rather than read from the cache. This provider is auto-disposed and only the
      // Bookings tab watches it, so opening this sheet from the hire-posts tab used to find an
      // empty cache and wrongly announce that no orders were waiting for crew.
      bookings = await ref.read(businessBookingsProvider.future);
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoadingBookings = false;
          _errorMessage = 'Could not load your orders. $e';
        });
      }
      return;
    }

    if (!mounted) return;
    setState(() => _isLoadingBookings = false);

    // Any confirmed order that is still live. Deliberately not filtered by a headcount: an
    // order has no crew requirement, so "already full" is not a thing that can be true of one.
    final hireable = bookings
        .where((b) => b.isConfirmed || b.isAssigned)
        .toList();

    // A one-field record rather than a bare Booking?, so "swiped the sheet away" (null) stays
    // distinct from "deliberately chose not to link" ((null,)).
    final choice = await showModalBottomSheet<(Booking?,)>(
      context: context,
      isScrollControlled: true,
      builder: (context) => _BookingPickerSheet(
        bookings: hireable,
        selectedId: _linkedBooking?.id,
      ),
    );

    if (choice == null || !mounted) return;

    final chosen = choice.$1;

    setState(() {
      _linkedBooking = chosen;
      // A pin belongs to the job it was placed for; switching orders starts over.
      _pinLatitude = null;
      _pinLongitude = null;
      _pinChanged = false;

      if (chosen == null) {
        // Unlinking drops the kind of work with it — it was the order's, not the post's.
        _subCategoryId = null;
        return;
      }

      _titleController.text = chosen.serviceName;
      _eventDate = chosen.scheduledDate.toLocal();
      _locationController.text = _bookingAddress(chosen) ?? '';
      // The kind of work comes with the order, from the package the customer chose.
      _subCategoryId = chosen.serviceSubCategoryId;
    });

    // The order names a service; its description and category come from that.
    if (chosen != null) {
      await _applyBookingService(chosen);
    }
  }

  static String? _bookingAddress(Booking? booking) {
    if (booking == null) return null;
    final parts = [
      booking.addressLine1,
      booking.city,
      booking.state,
    ].whereType<String>().where((s) => s.isNotEmpty);
    return parts.isEmpty ? null : parts.join(', ');
  }

  static String trimAmount(double value) => value.truncateToDouble() == value
      ? value.toStringAsFixed(0)
      : value.toStringAsFixed(2);

  /// Echoes the minutes back as hours and the finish time, so "150" reads as something
  /// a person can sanity-check rather than a number they have to divide in their head.
  String get _durationSuffix {
    final minutes = int.tryParse(_durationController.text.trim());
    if (minutes == null || minutes < 1) return '';
    final label = minutes >= 60
        ? '${minutes ~/ 60}h${minutes % 60 == 0 ? '' : ' ${minutes % 60}m'}'
        : '${minutes}m';
    final start = _eventDate;
    if (start == null) return label;
    final end = start.add(Duration(minutes: minutes));
    return '$label · ends '
        '${end.hour.toString().padLeft(2, '0')}:'
        '${end.minute.toString().padLeft(2, '0')}';
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _locationController.dispose();
    _workersNeededController.dispose();
    _durationController.dispose();
    _salaryController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final picked = await ImagePicker().pickImage(source: ImageSource.gallery);
    if (picked == null) return;

    try {
      final rawBytes = await picked.readAsBytes();
      final compressed = await FlutterImageCompress.compressWithList(
        rawBytes,
        format: CompressFormat.jpeg,
        quality: 85,
        minWidth: 1600,
        minHeight: 1600,
      );
      setState(() => _pickedImageBytes = compressed);
    } catch (e) {
      setState(
        () => _errorMessage =
            'Could not process the selected image. Please try a different photo.',
      );
    }
  }

  Future<void> _pickEventDate() async {
    final existing = _eventDate;
    final now = DateTime.now();
    final date = await showDatePicker(
      context: context,
      initialDate: existing ?? now.add(const Duration(days: 1)),
      // An event already in the past must stay selectable when editing an older post.
      firstDate: existing != null && existing.isBefore(now) ? existing : now,
      lastDate: now.add(const Duration(days: 365)),
    );
    if (date == null || !mounted) return;

    final time = await showTimePicker(
      context: context,
      initialTime: existing == null
          ? TimeOfDay.now()
          : TimeOfDay(hour: existing.hour, minute: existing.minute),
    );
    if (time == null) return;

    setState(() {
      _eventDate = DateTime(
        date.year,
        date.month,
        date.day,
        time.hour,
        time.minute,
      );
    });
  }

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();
    if (!_formKey.currentState!.validate()) {
      return;
    }
    if (_eventDate == null) {
      setState(() => _errorMessage = 'Select an event date and time.');
      return;
    }

    setState(() {
      _isSaving = true;
      _errorMessage = null;
    });

    final title = _titleController.text.trim();
    final description = _descriptionController.text.trim();
    final location = _locationController.text.trim();
    final workersNeeded = int.parse(_workersNeededController.text.trim());
    final durationMinutes = int.parse(_durationController.text.trim());
    final salaryAmount = double.parse(_salaryController.text.trim());
    final notifier = ref.read(businessHiringPostsProvider.notifier);
    // The order's own pin is copied by the server; only a point placed on this form is sent.
    final sendPin = !_usesOrderPin && _hasOwnPin && _pinChanged;

    try {
      final postId = _isEditing
          ? (await notifier.updatePost(
              id: _post!.id,
              title: title,
              description: description.isEmpty ? null : description,
              eventDate: _eventDate!,
              location: location.isEmpty ? null : location,
              latitude: sendPin ? _pinLatitude : null,
              longitude: sendPin ? _pinLongitude : null,
              locationPrecision: sendPin ? 'Pinned' : null,
              serviceSubCategoryId: _subCategoryId,
              workersNeeded: workersNeeded,
              durationMinutes: durationMinutes,
              salaryAmount: salaryAmount,
              salaryUnit: _salaryUnit,
            )).id
          : (await notifier.createPost(
              bookingId: _linkedBooking?.id,
              title: title,
              description: description.isEmpty ? null : description,
              eventDate: _eventDate!,
              location: location.isEmpty ? null : location,
              latitude: sendPin ? _pinLatitude : null,
              longitude: sendPin ? _pinLongitude : null,
              locationPrecision: sendPin ? 'Pinned' : null,
              serviceSubCategoryId: _subCategoryId,
              workersNeeded: workersNeeded,
              durationMinutes: durationMinutes,
              salaryAmount: salaryAmount,
              salaryUnit: _salaryUnit,
            )).id;

      if (_pickedImageBytes != null) {
        await notifier.uploadImage(postId, _pickedImageBytes!);
      }

      if (mounted) {
        Navigator.of(context).pop();
      }
    } catch (e) {
      setState(() => _errorMessage = e.toString());
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  /// Picking a service names the post and pulls that service's own description across,
  /// so a business does not retype the same blurb for every event. The description stays
  /// editable afterwards — this fills it in, it does not lock it.
  /// Fills the description and category from the service the order was placed against.
  ///
  /// A convenience, so a failure here is swallowed: the business can still type everything.
  Future<void> _applyBookingService(Booking booking) async {
    try {
      final services = await ref.read(businessServicesProvider.future);
      final service = services.firstWhereOrNull(
        (s) => s.id == booking.businessServiceId,
      );
      if (service == null || !mounted) return;

      setState(() {
        final description = service.description?.trim();
        if (description != null &&
            description.isNotEmpty &&
            _descriptionController.text.trim().isEmpty) {
          _descriptionController.text = description;
        }
      });
    } catch (_) {
      // Leaving the fields blank is a perfectly usable outcome.
    }
  }

  void _applyService(String title, BusinessService? service) {
    setState(() {
      _titleController.text = title;

      final description = service?.description?.trim();
      if (description != null && description.isNotEmpty) {
        _descriptionController.text = description;
      }
    });
  }

  String? _validateSalary(String? value) {
    final parsed = double.tryParse((value ?? '').trim());
    if (parsed == null || parsed <= 0) {
      return 'Enter a salary greater than 0.';
    }
    if (_isSalaryLocked && parsed < _post!.salaryAmount) {
      return 'Cannot go below ${rupees(_post!.salaryAmount)} — '
          'workers are already confirmed at that rate.';
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    // When hiring against an order, the picture the post will be saved with is the order's —
    // shown here so the slot does not look empty when it is in fact already filled.
    final existingImageUrl = _post?.imageUrl ?? _linkedBooking?.imageUrl;

    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      child: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _isEditing ? 'Edit hiring post' : 'Post for hire',
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),
              if (_errorMessage != null) ...[
                ErrorBanner(message: _errorMessage!),
                const SizedBox(height: 16),
              ],
              // Which order this crew is for. Choosing one fills in the date, the address and
              // how many people are still missing — and puts everyone who accepts straight onto
              // that booking, so nobody has to be added by hand afterwards.
              if (!_isEditing) ...[
                InkWell(
                  borderRadius: BorderRadius.circular(4),
                  onTap: _isLoadingBookings ? null : _pickBooking,
                  child: InputDecorator(
                    decoration: const InputDecoration(
                      labelText: 'For which order?',
                      border: OutlineInputBorder(),
                      helperText: 'Workers who accept join that order.',
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: _linkedBooking == null
                              ? Text(
                                  'Not linked — my own event',
                                  style: TextStyle(
                                    color: theme.colorScheme.onSurfaceVariant,
                                  ),
                                )
                              : Row(
                                  children: [
                                    OrderCode(
                                      code: _linkedBooking!.reference,
                                      compact: true,
                                    ),
                                    const SizedBox(width: 8),
                                    Flexible(
                                      child: Text(
                                        _linkedBooking!.serviceName,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ],
                                ),
                        ),
                        if (_isLoadingBookings)
                          const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        else
                          const Icon(Icons.arrow_drop_down),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
              ],
              GestureDetector(
                onTap: _pickImage,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    width: 96,
                    height: 96,
                    color: theme.colorScheme.surfaceContainerHighest,
                    child: _pickedImageBytes != null
                        ? Image.memory(_pickedImageBytes!, fit: BoxFit.cover)
                        : existingImageUrl != null
                        ? CachedNetworkImage(
                            imageUrl:
                                '${ApiConstants.baseUrl}$existingImageUrl',
                            fit: BoxFit.cover,
                          )
                        : Icon(
                            Icons.add_a_photo_outlined,
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                  ),
                ),
              ),
              const SizedBox(height: 14),
              _ServiceTitlePicker(
                selectedTitle: _titleController.text.trim().isEmpty
                    ? null
                    : _titleController.text.trim(),
                onSelected: _applyService,
              ),
              const SizedBox(height: 14),
              // Shown, not chosen. The kind of work belongs to the package the customer booked,
              // so a post raised from an order inherits it rather than asking again.
              if (_linkedBooking?.serviceSubCategoryName case final kind?) ...[
                InputDecorator(
                  decoration: const InputDecoration(
                    labelText: 'Kind of work',
                    helperText: 'Taken from the order — what a worker reads first',
                    border: OutlineInputBorder(),
                  ),
                  child: Text(kind),
                ),
                const SizedBox(height: 14),
              ],
              TextFormField(
                controller: _descriptionController,
                maxLines: 2,
                decoration: const InputDecoration(
                  labelText: 'Description',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 14),
              InkWell(
                borderRadius: BorderRadius.circular(4),
                onTap: _pickEventDate,
                child: InputDecorator(
                  decoration: const InputDecoration(
                    labelText: 'Event date & time',
                    border: OutlineInputBorder(),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        _eventDate == null
                            ? 'Select date & time'
                            : _eventDate!.toLocal().toString().substring(0, 16),
                        style: _eventDate == null
                            ? TextStyle(
                                color: theme.colorScheme.onSurfaceVariant,
                              )
                            : null,
                      ),
                      const Icon(Icons.edit_calendar_outlined),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 14),
              if (_usesOrderPin) ...[
                // The customer pinned this order's door; the crew goes there. Shown, not asked.
                JobLocationCard(
                  key: const Key('hirePostOrderPin'),
                  latitude: _linkedBooking!.latitude,
                  longitude: _linkedBooking!.longitude,
                  caption: 'From the order · exact pin (set automatically)',
                  addressLines: [
                    _linkedBooking!.addressLine1,
                    _linkedBooking!.addressLine2,
                    _linkedBooking!.city,
                    _linkedBooking!.state,
                    _linkedBooking!.postalCode,
                  ],
                  showActions: false,
                ),
                const SizedBox(height: 10),
              ],
              TextFormField(
                controller: _locationController,
                maxLines: 2,
                decoration: InputDecoration(
                  labelText: _usesOrderPin
                      ? 'Directions for the crew (optional)'
                      : 'Location details',
                  hintText: 'e.g. Hall behind the church, gate 2',
                  border: const OutlineInputBorder(),
                ),
              ),
              if (!_usesOrderPin) ...[
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 4,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    ActionChip(
                      key: const Key('hirePostSearchLocation'),
                      avatar: const Icon(Icons.search, size: 18),
                      label: const Text('Search location'),
                      onPressed: () => _pickLocation(fromCurrentLocation: false),
                    ),
                    ActionChip(
                      key: const Key('hirePostCurrentLocation'),
                      avatar: const Icon(Icons.my_location, size: 18),
                      label: const Text('Current location'),
                      onPressed: () => _pickLocation(fromCurrentLocation: true),
                    ),
                    if (_hasOwnPin)
                      InputChip(
                        key: const Key('hirePostPinSet'),
                        avatar: Icon(
                          Icons.check_circle,
                          size: 18,
                          color: theme.colorScheme.primary,
                        ),
                        label: const Text('Exact pin set'),
                        onPressed: () => _pickLocation(fromCurrentLocation: false),
                        onDeleted: _clearPin,
                      ),
                  ],
                ),
                if (!_hasOwnPin)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      'Pin it so nearby workers see the job and how far it is.',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
              ],
              const SizedBox(height: 14),
              TextFormField(
                controller: _durationController,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: 'How long the work runs (minutes)',
                  suffixText: _durationSuffix,
                  helperText:
                      'Used to stop a worker being booked for two jobs at once.',
                  border: const OutlineInputBorder(),
                ),
                onChanged: (_) => setState(() {}),
                validator: (value) {
                  final parsed = int.tryParse((value ?? '').trim());
                  return (parsed == null || parsed < 15 || parsed > 1440)
                      ? 'Enter between 15 and 1440 minutes.'
                      : null;
                },
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: _workersNeededController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Workers needed',
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  final parsed = int.tryParse((value ?? '').trim());
                  if (parsed == null || parsed < 1) {
                    return 'Enter at least 1.';
                  }
                  final confirmed = _post?.confirmedCount ?? 0;
                  if (parsed < confirmed) {
                    return 'Cannot be fewer than the $confirmed already confirmed.';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 14),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    flex: 3,
                    child: TextFormField(
                      controller: _salaryController,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      decoration: const InputDecoration(
                        labelText: 'Salary per worker',
                        prefixText: '₹ ',
                        border: OutlineInputBorder(),
                      ),
                      validator: _validateSalary,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: DropdownButtonFormField<String>(
                      initialValue: _salaryUnit,
                      decoration: const InputDecoration(
                        labelText: 'Per',
                        border: OutlineInputBorder(),
                      ),
                      items: const [
                        DropdownMenuItem(
                          value: 'PerEvent',
                          child: Text('Event'),
                        ),
                        DropdownMenuItem(value: 'PerDay', child: Text('Day')),
                        DropdownMenuItem(value: 'PerHour', child: Text('Hour')),
                      ],
                      // Fixed once anyone is confirmed — changing it would silently
                      // reprice work that has already been agreed.
                      onChanged: _isSalaryLocked
                          ? null
                          : (value) =>
                                setState(() => _salaryUnit = value ?? _salaryUnit),
                    ),
                  ),
                ],
              ),
              if (_isSalaryLocked) ...[
                const SizedBox(height: 10),
                _SalaryLockNotice(post: _post!),
              ],
              const SizedBox(height: 20),
              PrimaryButton(
                label: _isEditing ? 'Save changes' : 'Post',
                onPressed: _submit,
                isLoading: _isSaving,
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }
}

/// Titles a hiring post by picking one of the business's own services, rather than free
/// text. Selecting one also carries that service's description into the form.
///
/// A post edited before this existed may carry a title that matches no current service
/// (or the service may since have been renamed or removed); that title is offered as an
/// extra option so editing such a post does not silently blank its title.
class _ServiceTitlePicker extends ConsumerWidget {
  const _ServiceTitlePicker({
    required this.selectedTitle,
    required this.onSelected,
  });

  final String? selectedTitle;
  /// Passes the whole service, not just its name: the post takes its description from it and
  /// filters the kinds of work on offer by its category.
  final void Function(String title, BusinessService? service) onSelected;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final servicesAsync = ref.watch(businessServicesProvider);

    return servicesAsync.when(
      loading: () => const InputDecorator(
        decoration: InputDecoration(
          labelText: 'Service',
          border: OutlineInputBorder(),
        ),
        child: Row(
          children: [
            SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
            SizedBox(width: 10),
            Text('Loading your services…'),
          ],
        ),
      ),
      error: (error, _) => ErrorBanner(message: error.toString()),
      data: (services) {
        if (services.isEmpty && selectedTitle == null) {
          return const _NoServicesNotice();
        }

        final byName = <String, BusinessService>{
          for (final service in services) service.name: service,
        };

        // Keep an unrecognised existing title selectable so editing never drops it.
        final titles = <String>[
          if (selectedTitle != null && !byName.containsKey(selectedTitle))
            selectedTitle!,
          ...byName.keys,
        ];

        return DropdownButtonFormField<String>(
          initialValue: selectedTitle,
          isExpanded: true,
          decoration: const InputDecoration(
            labelText: 'Service',
            helperText: 'Picks the title and fills in the description',
            border: OutlineInputBorder(),
          ),
          items: titles
              .map(
                (title) => DropdownMenuItem(
                  value: title,
                  child: Text(title, overflow: TextOverflow.ellipsis),
                ),
              )
              .toList(),
          onChanged: (title) {
            if (title == null) return;
            onSelected(title, byName[title]);
          },
          validator: (value) => (value == null || value.trim().isEmpty)
              ? 'Choose the service you are hiring for.'
              : null,
        );
      },
    );
  }
}

/// A business with no services yet cannot title a hiring post, so say so plainly
/// instead of presenting an empty dropdown.
class _NoServicesNotice extends StatelessWidget {
  const _NoServicesNotice();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.colorScheme.errorContainer.withValues(alpha: 0.35),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.info_outline, size: 18, color: theme.colorScheme.error),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Add a service under the Services tab first — a hiring post is titled '
              'by the service you need workers for.',
              style: theme.textTheme.bodySmall,
            ),
          ),
        ],
      ),
    );
  }
}

/// Explains, inside the form, why the salary controls behave differently on a post that
/// already has confirmed workers.
class _SalaryLockNotice extends StatelessWidget {
  const _SalaryLockNotice({required this.post});

  final HiringPost post;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.colorScheme.secondaryContainer.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.lock_outline, size: 18, color: theme.colorScheme.primary),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              '${post.confirmedCount} worker(s) confirmed at ${post.salaryLabel}. '
              'You can raise the salary, but not lower it or change the unit.',
              style: theme.textTheme.bodySmall,
            ),
          ),
        ],
      ),
    );
  }
}

/// Picks the customer order a hiring post is being raised for.
///
/// Shows only orders that can still take crew, with how many people each is short — the number
/// the business is about to advertise for.
class _BookingPickerSheet extends StatelessWidget {
  const _BookingPickerSheet({required this.bookings, this.selectedId});

  final List<Booking> bookings;
  final String? selectedId;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 6),
            child: Text(
              'Hire for which order?',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          Flexible(
            child: ListView(
              shrinkWrap: true,
              children: [
                ListTile(
                  leading: const Icon(Icons.event_note_outlined),
                  title: const Text('Not linked'),
                  subtitle: const Text('Hiring for my own event'),
                  trailing: selectedId == null
                      ? Icon(Icons.check, color: theme.colorScheme.primary)
                      : null,
                  onTap: () => Navigator.of(context).pop((null,)),
                ),
                if (bookings.isEmpty)
                  const Padding(
                    padding: EdgeInsets.fromLTRB(20, 8, 20, 20),
                    child: Text(
                      'No confirmed orders are waiting for crew. Confirm a booking first, or '
                      'leave this unlinked.',
                    ),
                  )
                else
                  for (final booking in bookings)
                    ListTile(
                      title: Row(
                        children: [
                          OrderCode(code: booking.reference, compact: true),
                          const SizedBox(width: 8),
                          Flexible(
                            child: Text(
                              booking.variantName ?? booking.serviceName,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                      subtitle: Text(
                        '${booking.customerName} · '
                        '${formatDate(booking.scheduledDate.toLocal())}\n'
                        // A crew size of 0 means it has not been agreed yet, so there is no
                        // "how many more" to state — subtracting would print a negative.
                        '${booking.requiredWorkerCount < 1 ? 'Crew size to be agreed' : 'Needs ${booking.requiredWorkerCount - booking.activeWorkerCount} more of ${booking.requiredWorkerCount}'}',
                      ),
                      isThreeLine: true,
                      trailing: booking.id == selectedId
                          ? Icon(Icons.check, color: theme.colorScheme.primary)
                          : null,
                      onTap: () => Navigator.of(context).pop((booking,)),
                    ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

