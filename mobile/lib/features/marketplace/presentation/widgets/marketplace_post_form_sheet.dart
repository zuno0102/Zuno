import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:zuno/core/theme/app_colors.dart';
import 'package:zuno/features/business_owner/presentation/widgets/service_form_message_banner.dart';
import 'package:zuno/features/business_owner/presentation/widgets/service_media_slots.dart';
import 'package:zuno/features/catalog/presentation/providers/catalog_providers.dart';
import 'package:zuno/features/marketplace/data/marketplace_api.dart';
import 'package:zuno/features/marketplace/domain/entities/marketplace_post.dart';
import 'package:zuno/features/marketplace/presentation/providers/marketplace_providers.dart';
import 'package:zuno/features/marketplace/presentation/widgets/marketplace_category_fields_section.dart';
import 'package:zuno/shared/widgets/date_time_field.dart';
import 'package:zuno/shared/widgets/error_banner.dart';
import 'package:zuno/shared/widgets/primary_button.dart';
import 'package:zuno/shared/widgets/select_field.dart';

/// Photo slots per post until the server's own number has loaded — `Marketplace:ImageSlots`.
const marketplaceDefaultImageSlots = 5;

/// Shows the add/edit sheet for a post. Pass [existing] to edit, omit it to add one.
Future<void> showMarketplacePostFormSheet(
  BuildContext context, {
  MarketplacePost? existing,
}) => showModalBottomSheet<void>(
  context: context,
  isScrollControlled: true,
  builder: (context) => MarketplacePostFormSheet(existing: existing),
);

/// The post form: photos, category, then what that category's kind asks — a price for a listing,
/// usual and offer price, portions and hours for a food offer, a run of dates for an advertisement —
/// then the category's own details and where it is.
class MarketplacePostFormSheet extends ConsumerStatefulWidget {
  const MarketplacePostFormSheet({this.existing, super.key});

  final MarketplacePost? existing;

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

  late String? _categoryId = _old?.categoryId;
  late String? _stateId = _old?.stateId;
  late String? _districtId = _old?.districtId;
  late String _tradeType = _old?.tradeType ?? MarketplaceTradeType.retail;
  late DateTime? _startsAt = _old?.startsAt;
  late DateTime? _endsAt = _old?.endsAt;

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
    ]) {
      c.dispose();
    }
    _attributes.dispose();
    _media.dispose();
    _scroll.dispose();
    super.dispose();
  }

  MarketplacePostInput _input(MarketplaceCategory category) {
    final kind = category.kind;
    final wholesale =
        category.allowsWholesale &&
        _tradeType == MarketplaceTradeType.wholesale;
    return MarketplacePostInput(
      categoryId: category.id,
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
      quantity: kind == MarketplacePostKind.foodOffer || wholesale
          ? int.tryParse(_quantity.text.trim())
          : null,
      originalPrice: kind == MarketplacePostKind.foodOffer
          ? double.tryParse(_originalPrice.text.trim())
          : null,
      startsAt: kind == MarketplacePostKind.listing ? null : _startsAt,
      endsAt: kind == MarketplacePostKind.listing ? null : _endsAt,
      contactPhone: kind == MarketplacePostKind.advertisement
          ? _clean(_phone)
          : null,
      districtId: _districtId!,
      area: _clean(_area),
      attributes: _attributes.valuesFor(category.fields),
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
                        detail: options?.kindName(c.kind),
                      ),
                  ],
                  initialValue: _categoryId,
                  validator: (v) => v == null ? 'Choose a category.' : null,
                  onChanged: (id) => setState(() {
                    // The details belong to one category, so they cannot survive a change of it.
                    if (id != _categoryId) _attributes.clear();
                    _categoryId = id;
                  }),
                ),
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
                  fields: category.fields,
                  values: _attributes,
                  onChanged: () => setState(() {}),
                ),
              ..._placeSection(),
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
    _ => _listingSection(category),
  };

  List<Widget> _listingSection(MarketplaceCategory category) {
    final wholesale =
        category.allowsWholesale &&
        _tradeType == MarketplaceTradeType.wholesale;
    return [
      if (category.allowsWholesale) ...[
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
      _priceRow(priceLabel: 'Price', unitHint: 'kg, sq ft, piece'),
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

  List<Widget> _placeSection() {
    final states = ref.watch(locationStatesProvider).value ?? const [];
    final stateId = _stateId;
    final districts = stateId == null
        ? const []
        : ref.watch(districtsForStatesProvider(stateId)).value ?? const [];
    return [
      SelectField<String>(
        key: const ValueKey('marketplace-state'),
        label: 'State',
        options: [for (final s in states) SelectOption(s.id, s.name)],
        initialValue: _stateId,
        validator: (v) => v == null ? 'Choose the state.' : null,
        onChanged: (id) => setState(() {
          if (id != _stateId) _districtId = null;
          _stateId = id;
        }),
      ),
      const SizedBox(height: 14),
      SelectField<String>(
        key: ValueKey('marketplace-district-$_stateId'),
        label: 'District',
        options: [for (final d in districts) SelectOption(d.id, d.name)],
        initialValue: _districtId,
        validator: (v) => v == null ? 'Choose the district.' : null,
        onChanged: stateId == null
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
    ];
  }

  Widget _priceRow({required String priceLabel, required String unitHint}) =>
      Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: _money(_price, key: 'marketplace-price', label: priceLabel),
          ),
          const SizedBox(width: 12),
          Expanded(child: _unitField(unitHint)),
        ],
      );

  Widget _unitField(String hint) => TextFormField(
    key: const ValueKey('marketplace-price-unit'),
    controller: _priceUnit,
    maxLength: 20,
    decoration: InputDecoration(
      labelText: 'Per (optional)',
      hintText: hint,
      border: const OutlineInputBorder(),
      counterText: '',
    ),
  );

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
      return parsed == null || parsed < 1 ? 'At least 1.' : null;
    },
  );
}
