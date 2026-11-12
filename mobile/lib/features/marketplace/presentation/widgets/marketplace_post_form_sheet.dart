import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:zuno/core/theme/app_colors.dart';
import 'package:zuno/features/business_owner/presentation/providers/business_profile_notifier.dart';
import 'package:zuno/features/business_owner/presentation/widgets/service_form_message_banner.dart';
import 'package:zuno/features/business_owner/presentation/widgets/service_media_slots.dart';
import 'package:zuno/features/catalog/domain/entities/district.dart';
import 'package:zuno/features/catalog/domain/entities/location_state.dart';
import 'package:zuno/features/catalog/presentation/providers/catalog_providers.dart';
import 'package:zuno/features/marketplace/data/marketplace_api.dart';
import 'package:zuno/features/marketplace/domain/entities/marketplace_post.dart';
import 'package:zuno/features/marketplace/presentation/providers/marketplace_providers.dart';
import 'package:zuno/features/marketplace/presentation/widgets/marketplace_category_fields_section.dart';
import 'package:zuno/features/marketplace/presentation/widgets/marketplace_product_sections.dart';
import 'package:zuno/shared/widgets/date_time_field.dart';
import 'package:zuno/shared/widgets/error_banner.dart';
import 'package:zuno/shared/widgets/location_pin_picker.dart';
import 'package:zuno/shared/widgets/multi_select_sheet.dart';
import 'package:zuno/shared/widgets/primary_button.dart';
import 'package:zuno/shared/widgets/select_field.dart';

/// Photo slots per post until the server's own number has loaded — `Marketplace:ImageSlots`.
const marketplaceDefaultImageSlots = 5;

/// Shows the add/edit sheet for a post. Pass [existing] to edit, omit it to add one; [categoryId]
/// starts a new post in that main category.
Future<void> showMarketplacePostFormSheet(
  BuildContext context, {
  MarketplacePost? existing,
  String? categoryId,
}) => showModalBottomSheet<void>(
  context: context,
  isScrollControlled: true,
  builder: (context) =>
      MarketplacePostFormSheet(existing: existing, categoryId: categoryId),
);

/// The post form: photos, category, then what that category's kind asks — a price for a listing,
/// usual and offer price, portions and hours for a food offer, a run of dates for an advertisement —
/// then the category's own details and where it is.
class MarketplacePostFormSheet extends ConsumerStatefulWidget {
  const MarketplacePostFormSheet({this.existing, this.categoryId, super.key});

  final MarketplacePost? existing;

  /// The main category a new post starts in — the square the business tapped. They can still
  /// change it; ignored when editing.
  final String? categoryId;

  @override
  ConsumerState<MarketplacePostFormSheet> createState() =>
      _MarketplacePostFormSheetState();
}

class _MarketplacePostFormSheetState
    extends ConsumerState<MarketplacePostFormSheet> {
  final _formKey = GlobalKey<FormState>();
  final _scroll = ScrollController();

  late final MarketplacePost? _old = widget.existing;
  late final _title = TextEditingController(text: _old?.title);
  late final _description = TextEditingController(text: _old?.description);
  late final _price = TextEditingController(text: _plain(_old?.price));
  late final _originalPrice = TextEditingController(
    text: _plain(_old?.originalPrice),
  );
  late final _priceUnit = TextEditingController(text: _old?.priceUnit);
  late final _quantity = TextEditingController(
    text: _old?.quantity?.toString(),
  );
  late final _minOrder = TextEditingController(
    text: _old?.minOrderQuantity?.toString(),
  );
  late final _area = TextEditingController(text: _old?.area);
  late final _phone = TextEditingController(text: _old?.contactPhone);
  late final _attributes = MarketplaceAttributeValues(
    _old?.attributes ?? const {},
  );

  late String? _categoryId = _old?.categoryId ?? widget.categoryId;
  late String? _subCategoryId = _old?.subCategoryId;
  late String? _stateId = _old?.stateId;
  late String? _districtId = _old?.districtId;
  late String _tradeType = _old?.tradeType ?? MarketplaceTradeType.retail;

  /// New or Used, in a category that keeps stock (Products).
  late String? _condition = _old?.condition;
  late DateTime? _startsAt = _old?.startsAt;
  late DateTime? _endsAt = _old?.endsAt;

  /// A new product's colours and sizes, and the business's own details.
  late final _variants = MarketplaceVariantRows(_old?.variants ?? const [])
    ..addListener(_rebuild);
  late final _customDetails = MarketplaceCustomDetailRows(
    _old?.customDetails ?? const [],
  );

  /// Where the product is: a street line, and the pin from the map or the phone.
  late final _addressLine = TextEditingController(text: _old?.addressLine);
  late double? _latitude = _old?.latitude;
  late double? _longitude = _old?.longitude;

  /// A product ships anywhere, or only to the districts chosen.
  late bool _deliversEverywhere = _old?.deliversEverywhere ?? true;
  late Set<String> _deliveryDistrictIds = {...?_old?.deliveryDistrictIds};

  /// A new post starts from the business's registered address, once.
  bool _prefilledAddress = false;

  void _rebuild() {
    if (mounted) setState(() {});
  }

  late final _media = ServiceMediaSelection(
    slotCount:
        ref.read(marketplaceOptionsProvider).value?.imageSlots ??
        marketplaceDefaultImageSlots,
    savedImageUrl: _old?.imageUrlForSlot,
  );

  bool _isSaving = false;
  String? _errorMessage;
  String? _successMessage;

  static String _plain(double? value) {
    if (value == null) return '';
    return value == value.roundToDouble()
        ? value.toInt().toString()
        : value.toString();
  }

  static String? _clean(TextEditingController c) =>
      c.text.trim().isEmpty ? null : c.text.trim();

  @override
  void dispose() {
    for (final c in [
      _title,
      _description,
      _price,
      _originalPrice,
      _priceUnit,
      _quantity,
      _minOrder,
      _area,
      _phone,
      _addressLine,
    ]) {
      c.dispose();
    }
    _variants.dispose();
    _customDetails.dispose();
    _attributes.dispose();
    _media.dispose();
    _scroll.dispose();
    super.dispose();
  }

  /// Whether this post sells in bulk: always in a wholesale-only category (B2B), by choice in an
  /// either-way one.
  bool _sellsWholesale(MarketplaceCategory category) =>
      category.isWholesaleOnly ||
      (category.sellsEitherWay && _tradeType == MarketplaceTradeType.wholesale);

  /// A new item in a category that keeps stock: the form asks how many are in stock.
  bool _keepsStock(MarketplaceCategory category) =>
      category.tracksStock && _condition == MarketplaceItemCondition.newItem;

  /// New or Used — from the server's table — then, for a new item, its stock. A used item is a
  /// single piece: it has no stock and is marked sold from the post's menu.
  List<Widget> _stockSection(
    MarketplaceCategory category,
    MarketplaceOptions? options,
  ) => [
    SelectField<String>(
      key: const ValueKey('marketplace-condition'),
      label: 'Condition',
      options: [
        for (final c in options?.conditions ?? const <MarketplaceOption>[])
          SelectOption(c.code, c.name, detail: c.detail),
      ],
      initialValue: _condition,
      validator: (v) => v == null ? 'Choose New or Used.' : null,
      onChanged: (v) => setState(() => _condition = v),
    ),
    const SizedBox(height: 14),
    // MRP: what it usually sells for, shown struck through beside the price.
    TextFormField(
      key: const ValueKey('marketplace-mrp'),
      controller: _originalPrice,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))],
      decoration: const InputDecoration(
        labelText: 'MRP (optional)',
        prefixText: '₹ ',
        border: OutlineInputBorder(),
      ),
      validator: (v) {
        final text = (v ?? '').trim();
        if (text.isEmpty) return null;
        final mrp = double.tryParse(text);
        if (mrp == null || mrp <= 0) return 'Enter a valid price.';
        final price = double.tryParse(_price.text.trim());
        return price != null && mrp < price
            ? 'Cannot be less than the price.'
            : null;
      },
    ),
    const SizedBox(height: 14),
    if (_keepsStock(category)) ...[
      // One stock count, until the product has colours or sizes: then each has its own.
      if (_variants.isEmpty) ...[
        _wholeNumber(
          _quantity,
          key: 'marketplace-stock',
          label: 'Stock available',
          required: true,
          min: 0,
        ),
        const SizedBox(height: 14),
      ],
      MarketplaceVariantsSection(
        rows: _variants,
        maxQuantity: options?.maxQuantity ?? marketplaceDefaultMaxQuantity,
      ),
      const SizedBox(height: 14),
    ],
  ];

  MarketplacePostInput _input(MarketplaceCategory category) {
    final kind = category.kind;
    final wholesale = _sellsWholesale(category);
    return MarketplacePostInput(
      categoryId: category.id,
      subCategoryId: category.subCategories.isEmpty ? null : _subCategoryId,
      title: _title.text.trim(),
      description: _clean(_description),
      price: kind == MarketplacePostKind.advertisement
          ? null
          : double.tryParse(_price.text.trim()),
      priceUnit: kind == MarketplacePostKind.advertisement
          ? null
          : _clean(_priceUnit),
      tradeType: wholesale
          ? MarketplaceTradeType.wholesale
          : MarketplaceTradeType.retail,
      minOrderQuantity: wholesale ? int.tryParse(_minOrder.text.trim()) : null,
      condition: category.tracksStock ? _condition : null,
      // With colours and sizes the server adds their stock up; otherwise the one count.
      quantity:
          kind == MarketplacePostKind.foodOffer ||
              wholesale ||
              (_keepsStock(category) && _variants.isEmpty)
          ? int.tryParse(_quantity.text.trim())
          : null,
      variants: _keepsStock(category) ? _variants.values : const [],
      // A food offer's usual price, or a product's MRP.
      originalPrice:
          kind == MarketplacePostKind.foodOffer || category.tracksStock
          ? double.tryParse(_originalPrice.text.trim())
          : null,
      customDetails: _customDetails.values,
      addressLine: _clean(_addressLine),
      latitude: _latitude,
      longitude: _longitude,
      deliversEverywhere: !category.tracksStock || _deliversEverywhere,
      deliveryDistrictIds: category.tracksStock && !_deliversEverywhere
          ? [..._deliveryDistrictIds]
          : const [],
      startsAt: kind == MarketplacePostKind.listing ? null : _startsAt,
      endsAt: kind == MarketplacePostKind.listing ? null : _endsAt,
      contactPhone: kind == MarketplacePostKind.advertisement
          ? _clean(_phone)
          : null,
      districtId: _districtId!,
      area: _clean(_area),
      attributes: _attributes.valuesFor(category.fieldsFor(_subCategoryId)),
    );
  }

  Future<void> _submit(MarketplaceCategory? category) async {
    FocusScope.of(context).unfocus();
    final valid = _formKey.currentState!.validate();
    final problem = category == null
        ? 'Choose a category.'
        : _districtId == null
        ? 'Choose the district.'
        : null;
    if (!valid || problem != null || category == null) {
      setState(() => _errorMessage = problem);
      return;
    }

    setState(() {
      _isSaving = true;
      _errorMessage = null;
    });

    final repository = ref.read(marketplaceRepositoryProvider);
    final old = _old;
    try {
      // The post first: a new one has no id to upload its photos against until it exists.
      final input = _input(category);
      final id = old == null
          ? (await repository.create(input)).id
          : (await repository.update(old.id, input)).id;

      for (var slot = 0; slot < _media.slotCount; slot++) {
        final bytes = _media.pickedImage(slot);
        if (bytes != null) {
          await repository.uploadImage(id, slot, bytes);
        } else if (_media.isImageRemoved(slot)) {
          await repository.removeImage(id, slot);
        }
      }

      reloadMarketplace(ref);
      if (!mounted) return;
      setState(
        () => _successMessage = old == null ? 'Post added.' : 'Post updated.',
      );
      await Future<void>.delayed(const Duration(milliseconds: 900));
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      if (mounted) _showError(e.toString());
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  /// The server's reason sits at the top of the form; the business pressed Save at the bottom,
  /// so the form scrolls up to show it.
  void _showError(String message) {
    setState(() => _errorMessage = message);
    if (_scroll.hasClients) {
      _scroll.animateTo(
        0,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final categoriesAsync = ref.watch(marketplaceCategoriesProvider);
    final categories = categoriesAsync.value ?? const <MarketplaceCategory>[];
    final category = categories.where((c) => c.id == _categoryId).firstOrNull;
    final options = ref.watch(marketplaceOptionsProvider).value;
    final theme = Theme.of(context);

    // A Stack like the rent item form's, so "Post added." shows over the form wherever it is
    // scrolled to — the business saves from the bottom.
    return Stack(
      children: [
        _form(context, theme, categoriesAsync, categories, category, options),
        if (_successMessage case final message?)
          Positioned(
            top: 12,
            right: 20,
            child: ServiceFormMessageBanner(
              key: const ValueKey('marketplace-post-saved'),
              message: message,
              color: theme.colorScheme.primary,
              onColor: theme.colorScheme.onPrimary,
              icon: Icons.check_circle,
            ),
          ),
      ],
    );
  }

  Widget _form(
    BuildContext context,
    ThemeData theme,
    AsyncValue<List<MarketplaceCategory>> categoriesAsync,
    List<MarketplaceCategory> categories,
    MarketplaceCategory? category,
    MarketplaceOptions? options,
  ) {
    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      child: SingleChildScrollView(
        controller: _scroll,
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                _old == null ? 'Add post' : 'Edit post',
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),
              if (_errorMessage case final message?) ...[
                ServiceFormMessageBanner(
                  message: message,
                  color: AppColors.error,
                  onColor: theme.colorScheme.onError,
                  icon: Icons.error_outline,
                ),
                const SizedBox(height: 16),
              ],
              ServiceMediaSlots(
                media: _media,
                mediaBaseUrl: MarketplaceApi.baseUrl,
                allowVideo: false,
                hint: category?.kind == MarketplacePostKind.advertisement
                    ? 'The first photo is the advert banner.'
                    : 'The first photo is the cover customers see.',
                onError: (message) => setState(() => _errorMessage = message),
              ),
              const SizedBox(height: 16),
              if (categoriesAsync.hasError && categories.isEmpty)
                ErrorBanner(
                  message:
                      'Failed to load categories: ${categoriesAsync.error}',
                )
              else
                SelectField<String>(
                  key: const ValueKey('marketplace-category'),
                  label: 'Category',
                  options: [
                    for (final c in categories)
                      SelectOption(
                        c.id,
                        c.name,
                        detail: c.description ?? options?.kindName(c.kind),
                      ),
                  ],
                  initialValue: _categoryId,
                  validator: (v) => v == null ? 'Choose a category.' : null,
                  onChanged: (id) => setState(() {
                    // The details and sub-category belong to one category, so they cannot survive
                    // a change of it.
                    if (id != _categoryId) {
                      _attributes.clear();
                      _subCategoryId = null;
                    }
                    _categoryId = id;
                  }),
                ),
              if (category != null && category.subCategories.isNotEmpty) ...[
                const SizedBox(height: 14),
                _subCategoryField(category),
              ],
              const SizedBox(height: 14),
              TextFormField(
                key: const ValueKey('marketplace-title'),
                controller: _title,
                maxLength: 120,
                decoration: const InputDecoration(
                  labelText: 'Title',
                  hintText: 'e.g. Swift VXi 2019, 10 cents land, Veg biryani',
                  border: OutlineInputBorder(),
                  counterText: '',
                ),
                validator: (v) =>
                    (v ?? '').trim().isEmpty ? 'Title is required.' : null,
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: _description,
                maxLines: 3,
                maxLength: 2000,
                decoration: const InputDecoration(
                  labelText: 'Description (optional)',
                  border: OutlineInputBorder(),
                  counterText: '',
                ),
              ),
              const SizedBox(height: 14),
              if (category != null) ..._kindSection(category, options),
              if (category != null)
                MarketplaceCategoryFieldsSection(
                  fields: category.fieldsFor(_subCategoryId),
                  values: _attributes,
                  onChanged: () => setState(() {}),
                ),
              if (category != null) ...[
                MarketplaceCustomDetailsSection(rows: _customDetails),
                const SizedBox(height: 14),
              ],
              ..._placeSection(category),
              const SizedBox(height: 20),
              PrimaryButton(
                label: _old == null ? 'Save post' : 'Save changes',
                isLoading: _isSaving,
                onPressed: _isSaving ? null : () => _submit(category),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// What the category's kind asks: a price, an offer, or a run of dates.
  List<Widget> _kindSection(
    MarketplaceCategory category,
    MarketplaceOptions? options,
  ) => switch (category.kind) {
    MarketplacePostKind.foodOffer => _foodSection(options),
    MarketplacePostKind.advertisement => _adSection(options),
    _ => _listingSection(category, options),
  };

  List<Widget> _listingSection(
    MarketplaceCategory category,
    MarketplaceOptions? options,
  ) {
    final wholesale = _sellsWholesale(category);
    return [
      if (category.tracksStock) ..._stockSection(category, options),
      if (category.sellsEitherWay) ...[
        SelectField<String>(
          key: const ValueKey('marketplace-trade-type'),
          label: 'Sell as',
          options: const [
            SelectOption(
              MarketplaceTradeType.retail,
              'Retail',
              detail: 'To customers, any amount',
            ),
            SelectOption(
              MarketplaceTradeType.wholesale,
              'Wholesale',
              detail: 'To businesses, in bulk',
            ),
          ],
          initialValue: _tradeType,
          onChanged: (v) => setState(() => _tradeType = v),
        ),
        const SizedBox(height: 14),
      ],
      _priceRow(
        priceLabel: wholesale ? 'Price per unit' : 'Price',
        unitHint: 'kg, dozen, piece',
        unitRequired: wholesale,
      ),
      if (wholesale) ...[
        const SizedBox(height: 14),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: _wholeNumber(
                _minOrder,
                key: 'marketplace-min-order',
                label: 'Smallest order',
                required: true,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _wholeNumber(
                _quantity,
                key: 'marketplace-quantity',
                label: 'Quantity for sale (optional)',
                required: false,
              ),
            ),
          ],
        ),
      ],
      const SizedBox(height: 14),
    ];
  }

  List<Widget> _foodSection(MarketplaceOptions? options) {
    final hours = options?.maxFoodOfferHours;
    return [
      Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: _money(
              _originalPrice,
              key: 'marketplace-original-price',
              label: 'Usual price',
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _money(
              _price,
              key: 'marketplace-price',
              label: 'Offer price',
              extra: (offer) {
                final usual = double.tryParse(_originalPrice.text.trim());
                return usual != null && offer >= usual
                    ? 'Must be less than the usual price.'
                    : null;
              },
            ),
          ),
        ],
      ),
      const SizedBox(height: 14),
      Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: _wholeNumber(
              _quantity,
              key: 'marketplace-quantity',
              label: 'Portions',
              required: true,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(child: _unitField('plate, box')),
        ],
      ),
      const SizedBox(height: 14),
      ..._window(
        withTime: true,
        helper: hours == null
            ? null
            : 'Up to $hours hours. Customers reserve and pay at your shop.',
      ),
    ];
  }

  List<Widget> _adSection(MarketplaceOptions? options) {
    final days = options?.maxAdDays;
    return [
      ..._window(
        withTime: false,
        helper: days == null ? null : 'Up to $days days.',
      ),
      TextFormField(
        key: const ValueKey('marketplace-contact-phone'),
        controller: _phone,
        keyboardType: TextInputType.phone,
        inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9+]'))],
        maxLength: 15,
        decoration: const InputDecoration(
          labelText: 'Contact phone (optional)',
          border: OutlineInputBorder(),
          counterText: '',
        ),
        validator: (v) {
          final text = (v ?? '').trim();
          return text.isEmpty || RegExp(r'^\+?[0-9]{10,15}$').hasMatch(text)
              ? null
              : 'Enter 10 to 15 digits.';
        },
      ),
      const SizedBox(height: 14),
    ];
  }

  /// When a food offer or advert starts and ends. An advert runs whole days: from the start of its
  /// first day to the end of its last.
  List<Widget> _window({required bool withTime, String? helper}) {
    final today = DateTime.now();
    final first = DateTime(today.year, today.month, today.day);
    final last = first.add(const Duration(days: 400));
    return [
      DateTimeField(
        key: const ValueKey('marketplace-starts-at'),
        label: 'Starts',
        withTime: withTime,
        firstDate: first,
        lastDate: last,
        initialValue: _startsAt,
        validator: (v) => v == null ? 'Choose when it starts.' : null,
        onChanged: (v) => setState(
          () => _startsAt = withTime ? v : DateTime(v.year, v.month, v.day),
        ),
      ),
      const SizedBox(height: 14),
      DateTimeField(
        key: const ValueKey('marketplace-ends-at'),
        label: 'Ends',
        withTime: withTime,
        helperText: helper,
        firstDate: first,
        lastDate: last,
        initialValue: _endsAt,
        validator: (v) {
          if (v == null) return 'Choose when it ends.';
          final start = _startsAt;
          return start != null && !v.isAfter(start)
              ? 'Must be after the start.'
              : null;
        },
        onChanged: (v) => setState(
          () =>
              _endsAt = withTime ? v : DateTime(v.year, v.month, v.day, 23, 59),
        ),
      ),
      const SizedBox(height: 14),
    ];
  }

  /// A new post starts where the business is registered: its street, town, state and pin. Once,
  /// when both the profile and the states have loaded; anything typed since is never overwritten.
  void _prefillFromBusiness(List<LocationState> states) {
    if (_old != null || _prefilledAddress) return;
    final profile = ref.watch(businessProfileProvider).value;
    if (profile == null || states.isEmpty) return;
    _prefilledAddress = true;
    final street = [
      profile.addressLine1,
      profile.addressLine2,
    ].where((p) => p != null && p.trim().isNotEmpty).join(', ');
    if (_addressLine.text.isEmpty && street.isNotEmpty) {
      _addressLine.text = street;
    }
    if (_area.text.isEmpty && (profile.city?.isNotEmpty ?? false)) {
      _area.text = profile.city!;
    }
    _latitude ??= profile.latitude;
    _longitude ??= profile.longitude;
    _stateId ??= _stateNamed(states, profile.state);
  }

  static String? _stateNamed(List<LocationState> states, String? name) {
    final wanted = name?.trim().toLowerCase();
    if (wanted == null || wanted.isEmpty) return null;
    return states.where((s) => s.name.toLowerCase() == wanted).firstOrNull?.id;
  }

  /// Pins the product on a map — from search, or the phone's position — and fills the street and
  /// town from it where they are still empty.
  Future<void> _pickLocation(
    List<LocationState> states, {
    required bool fromCurrentLocation,
  }) async {
    FocusScope.of(context).unfocus();
    final picked = await showLocationPinPicker(
      context,
      title: 'Where is the product?',
      // Starting without a point makes the picker go to the phone's position first.
      initialLatitude: fromCurrentLocation ? null : _latitude,
      initialLongitude: fromCurrentLocation ? null : _longitude,
    );
    if (picked == null || !mounted) return;
    setState(() {
      _latitude = picked.latitude;
      _longitude = picked.longitude;
      if (_addressLine.text.trim().isEmpty) {
        _addressLine.text = picked.street ?? picked.summary;
      }
      if (_area.text.trim().isEmpty) {
        _area.text = picked.locality ?? picked.city ?? '';
      }
      final pickedState = _stateNamed(states, picked.state);
      if (pickedState != null && pickedState != _stateId) {
        _stateId = pickedState;
        _districtId = null;
      }
    });
  }

  Future<void> _pickDeliveryDistricts(List<District> districts) async {
    final picked = await showMultiSelectSheet(
      context: context,
      title: 'Ships to',
      options: [
        for (final d in districts) MultiSelectOption(id: d.id, label: d.name),
      ],
      initialSelectedIds: _deliveryDistrictIds,
    );
    if (picked != null && mounted) {
      setState(() => _deliveryDistrictIds = picked);
    }
  }

  List<Widget> _placeSection(MarketplaceCategory? category) {
    final theme = Theme.of(context);
    final states = ref.watch(locationStatesProvider).value ?? const [];
    _prefillFromBusiness(states);
    final stateId = _stateId;
    final districtsAsync = stateId == null
        ? null
        : ref.watch(districtsForStatesProvider(stateId));
    final districts = districtsAsync?.value ?? const [];
    // The districts come from the server after a state is picked: until they are here the field
    // stays locked and says so, rather than opening an empty list.
    final districtHelp = stateId == null
        ? 'Choose the state first.'
        : districtsAsync!.isLoading && districts.isEmpty
        ? 'Loading districts…'
        : districtsAsync.hasError && districts.isEmpty
        ? 'Could not load districts. Choose the state again.'
        : null;
    final hasPin = _latitude != null && _longitude != null;
    return [
      Text(
        'Where it is',
        style: theme.textTheme.titleSmall?.copyWith(
          fontWeight: FontWeight.w600,
        ),
      ),
      const SizedBox(height: 4),
      Text(
        _old == null
            ? 'Starts from your registered business address. Change it if the product is elsewhere.'
            : 'Where the product is kept.',
        style: theme.textTheme.bodySmall?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
        ),
      ),
      const SizedBox(height: 10),
      TextFormField(
        key: const ValueKey('marketplace-address'),
        controller: _addressLine,
        maxLength: 200,
        decoration: const InputDecoration(
          labelText: 'Street address (optional)',
          hintText: 'e.g. 12 Main Road, near the bus stand',
          border: OutlineInputBorder(),
          counterText: '',
        ),
      ),
      const SizedBox(height: 8),
      Wrap(
        spacing: 8,
        runSpacing: 4,
        children: [
          ActionChip(
            key: const ValueKey('marketplace-search-location'),
            avatar: const Icon(Icons.search, size: 18),
            label: const Text('Search on map'),
            onPressed: () => _pickLocation(states, fromCurrentLocation: false),
          ),
          ActionChip(
            key: const ValueKey('marketplace-current-location'),
            avatar: const Icon(Icons.my_location, size: 18),
            label: const Text('Current location'),
            onPressed: () => _pickLocation(states, fromCurrentLocation: true),
          ),
          if (hasPin)
            InputChip(
              key: const ValueKey('marketplace-pin-set'),
              avatar: Icon(
                Icons.check_circle,
                size: 18,
                color: theme.colorScheme.primary,
              ),
              label: const Text('Exact pin set'),
              onPressed: () =>
                  _pickLocation(states, fromCurrentLocation: false),
              onDeleted: () => setState(() {
                _latitude = null;
                _longitude = null;
              }),
            ),
        ],
      ),
      const SizedBox(height: 14),
      SelectField<String>(
        key: const ValueKey('marketplace-state'),
        label: 'State',
        options: [for (final s in states) SelectOption(s.id, s.name)],
        initialValue: _stateId,
        validator: (v) => v == null ? 'Choose the state.' : null,
        onChanged: (id) => setState(() {
          if (id != _stateId) _districtId = null;
          // The same state again is how a failed district list is asked for once more.
          if (id == _stateId) ref.invalidate(districtsForStatesProvider(id));
          _stateId = id;
        }),
      ),
      const SizedBox(height: 14),
      SelectField<String>(
        key: ValueKey('marketplace-district-$_stateId'),
        label: 'District',
        options: [for (final d in districts) SelectOption(d.id, d.name)],
        initialValue: _districtId,
        helperText: districtHelp,
        validator: (v) => v == null ? 'Choose the district.' : null,
        onChanged: districts.isEmpty
            ? null
            : (id) => setState(() => _districtId = id),
      ),
      const SizedBox(height: 14),
      TextFormField(
        controller: _area,
        maxLength: 120,
        decoration: const InputDecoration(
          labelText: 'Town or area (optional)',
          hintText: 'e.g. Marthandam',
          border: OutlineInputBorder(),
          counterText: '',
        ),
      ),
      if (category?.tracksStock ?? false) ...[
        const SizedBox(height: 4),
        SelectField<bool>(
          key: const ValueKey('marketplace-ships-to'),
          label: 'Ships to',
          options: const [
            SelectOption(true, 'All areas', detail: 'Anyone can order it'),
            SelectOption(
              false,
              'Chosen districts only',
              detail: 'Only customers in the districts you pick',
            ),
          ],
          initialValue: _deliversEverywhere,
          onChanged: (v) => setState(() => _deliversEverywhere = v),
        ),
        if (!_deliversEverywhere) ...[
          const SizedBox(height: 14),
          FormField<Set<String>>(
            key: ValueKey('marketplace-delivery-districts-$_stateId'),
            validator: (_) => _deliveryDistrictIds.isEmpty
                ? 'Choose at least one district.'
                : null,
            builder: (field) => InkWell(
              onTap: districts.isEmpty
                  ? null
                  : () => _pickDeliveryDistricts([...districts]),
              borderRadius: BorderRadius.circular(12),
              child: InputDecorator(
                isEmpty: _deliveryDistrictIds.isEmpty,
                decoration: InputDecoration(
                  labelText: 'Districts it ships to',
                  helperText: districtHelp ?? 'From the state above.',
                  errorText: field.errorText,
                  suffixIcon: const Icon(Icons.keyboard_arrow_down_rounded),
                ),
                child: Text(
                  [
                    for (final d in districts)
                      if (_deliveryDistrictIds.contains(d.id)) d.name,
                  ].join(', '),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ),
          ),
        ],
      ],
    ];
  }

  Widget _priceRow({
    required String priceLabel,
    required String unitHint,
    bool unitRequired = false,
  }) => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Expanded(
        child: _money(_price, key: 'marketplace-price', label: priceLabel),
      ),
      const SizedBox(width: 12),
      Expanded(child: _unitField(unitHint, required: unitRequired)),
    ],
  );

  /// What the price is for — "kg", "plate". Required for wholesale: "₹45" means nothing in bulk.
  Widget _unitField(String hint, {bool required = false}) => TextFormField(
    key: const ValueKey('marketplace-price-unit'),
    controller: _priceUnit,
    maxLength: 20,
    decoration: InputDecoration(
      labelText: required ? 'Per' : 'Per (optional)',
      hintText: hint,
      border: const OutlineInputBorder(),
      counterText: '',
    ),
    validator: required
        ? (v) => (v ?? '').trim().isEmpty ? 'e.g. kg' : null
        : null,
  );

  /// Which kind within the category — Sarees, Fruits, Biryani & meals. Changing it drops the
  /// details only the old one asked for.
  Widget _subCategoryField(MarketplaceCategory category) {
    final subs = [
      for (final s in category.subCategories)
        if (s.isActive) s,
    ]..sort((a, b) => a.displayOrder.compareTo(b.displayOrder));
    return SelectField<String>(
      key: const ValueKey('marketplace-sub-category'),
      label: 'Sub-category',
      options: [for (final s in subs) SelectOption(s.id, s.name)],
      initialValue: _subCategoryId,
      validator: (v) => v == null ? 'Choose what kind it is.' : null,
      onChanged: (id) => setState(() {
        if (id != _subCategoryId) {
          _attributes.clearKeys([
            for (final f in category.fieldsFor(_subCategoryId))
              if (f.subCategoryId != null) f.key,
          ]);
        }
        _subCategoryId = id;
      }),
    );
  }

  Widget _money(
    TextEditingController controller, {
    required String key,
    required String label,
    String? Function(double value)? extra,
  }) => TextFormField(
    key: ValueKey(key),
    controller: controller,
    keyboardType: const TextInputType.numberWithOptions(decimal: true),
    inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))],
    decoration: InputDecoration(
      labelText: label,
      prefixText: '₹ ',
      // Half-width boxes: a rule like "Must be less than the usual price." wraps, not cut off.
      errorMaxLines: 2,
      border: const OutlineInputBorder(),
    ),
    validator: (v) {
      final parsed = double.tryParse((v ?? '').trim());
      if (parsed == null || parsed <= 0) return 'Enter a valid price.';
      return extra?.call(parsed);
    },
  );

  Widget _wholeNumber(
    TextEditingController controller, {
    required String key,
    required String label,
    required bool required,
    int min = 1,
  }) => TextFormField(
    key: ValueKey(key),
    controller: controller,
    keyboardType: TextInputType.number,
    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
    decoration: InputDecoration(
      labelText: label,
      border: const OutlineInputBorder(),
    ),
    validator: (v) {
      final text = (v ?? '').trim();
      if (text.isEmpty) return required ? 'Required.' : null;
      final parsed = int.tryParse(text);
      return parsed == null || parsed < min ? 'At least $min.' : null;
    },
  );
}
