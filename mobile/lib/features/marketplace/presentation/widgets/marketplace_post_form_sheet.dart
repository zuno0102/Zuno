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

  /// A product's first colour / size: asked on the form itself, the rest added as variants.
  late final MarketplaceVariant? _firstSaved = _old?.variants.firstOrNull;
  late final _price = TextEditingController(
    text: _plain(_firstSaved?.price ?? _old?.price),
  );
  late final _colour = TextEditingController(text: _firstSaved?.colour);
  late final _size = TextEditingController(text: _firstSaved?.size);
  late final _originalPrice = TextEditingController(
    text: _plain(_old?.originalPrice),
  );
  late final _priceUnit = TextEditingController(text: _old?.priceUnit);
  late final _quantity = TextEditingController(
    text: (_firstSaved?.stock ?? _old?.quantity)?.toString(),
  )..addListener(_rebuild);
  late final _minOrder = TextEditingController(
    text: _old?.minOrderQuantity?.toString(),
  );
  late final _phone = TextEditingController(text: _old?.contactPhone);
  late final _attributes = MarketplaceAttributeValues(
    _old?.attributes ?? const {},
  );

  late String? _categoryId = _old?.categoryId ?? widget.categoryId;
  late String? _subCategoryId = _old?.subCategoryId;
  late String _tradeType = _old?.tradeType ?? MarketplaceTradeType.retail;

  /// New or Used, in a category that keeps stock (Products). A new post starts as New, so its
  /// quantity, colour, size and stock are on the form at once.
  late String? _condition = _old == null
      ? MarketplaceItemCondition.newItem
      : _old.condition;
  late DateTime? _startsAt = _old?.startsAt;
  late DateTime? _endsAt = _old?.endsAt;

  /// A new product's further colours / sizes, each with its own price and stock — and the
  /// business's own details.
  late final _variants = MarketplaceVariantList(
    _old?.variants.skip(1).toList() ?? const [],
    price: _old?.price,
  )..addListener(_rebuild);
  late final _customDetails = MarketplaceCustomDetailRows(
    _old?.customDetails ?? const [],
  );

  /// Where a product ships: all of India, a whole state, or some districts of that state.
  late MarketplaceShipsTo _shipsTo =
      _old?.shipsTo ?? MarketplaceShipsTo.allIndia;
  late String? _shipStateId = _old?.deliveryStateId;
  late Set<String> _deliveryDistrictIds = {...?_old?.deliveryDistrictIds};

  late final _media = ServiceMediaSelection(
    slotCount:
        ref.read(marketplaceOptionsProvider).value?.imageSlots ??
        marketplaceDefaultImageSlots,
    savedImageUrl: _old?.imageUrlForSlot,
  );

  /// The first variant hides the one price and quantity; the last one brings them back.
  void _rebuild() {
    if (mounted) setState(() {});
  }

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
      _colour,
      _size,
      _phone,
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

  /// New or Used — from the server's table — then the basics a product is sold by: price, MRP and
  /// offer; for a new item its quantity, colour, size and stock on the form itself, and any further
  /// colour / size added below with its own price and stock. A used item is a single piece: it has
  /// no stock and is marked sold from the post's menu.
  List<Widget> _stockSection(
    MarketplaceCategory category,
    MarketplaceOptions? options,
  ) {
    final keepsStock = _keepsStock(category);
    return [
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
      MarketplacePriceFields(
        price: _price,
        mrp: _originalPrice,
        highestPrice: () =>
            [double.tryParse(_price.text.trim()), _variants.highestPrice]
                .whereType<double>()
                .fold<double?>(null, (a, b) => a == null || b > a ? b : a),
      ),
      const SizedBox(height: 14),
      if (keepsStock) ...[
        // The total: this colour / size's stock and every other one's, added up.
        InputDecorator(
          key: const ValueKey('marketplace-quantity-total'),
          decoration: const InputDecoration(
            labelText: 'Quantity',
            helperText: 'Every colour and size in stock, added up.',
            border: OutlineInputBorder(),
          ),
          child: Text(
            '${(int.tryParse(_quantity.text.trim()) ?? 0) + _variants.totalStock}',
          ),
        ),
        const SizedBox(height: 14),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: _variantText(_colour, 'colour', _limits.colour)),
            const SizedBox(width: 12),
            Expanded(child: _variantText(_size, 'size', _limits.size)),
          ],
        ),
        const SizedBox(height: 14),
        _wholeNumber(
          _quantity,
          key: 'marketplace-stock',
          label: 'Stock',
          required: true,
          min: 0,
        ),
        const SizedBox(height: 14),
        MarketplaceVariantsSection(
          variants: _variants,
          alsoTaken: () => [?_firstVariant],
          mrp: () => double.tryParse(_originalPrice.text.trim()),
          defaultPrice: () => double.tryParse(_price.text.trim()),
          limits: _limits,
          maxQuantity: options?.maxQuantity ?? marketplaceDefaultMaxQuantity,
        ),
        const SizedBox(height: 14),
      ],
    ];
  }

  /// Colour or Size on the form. Optional while it is the only one; once another colour / size is
  /// added, this one needs one of the two so the variants can be told apart.
  Widget _variantText(
    TextEditingController controller,
    String what,
    int maxLength,
  ) => TextFormField(
    key: ValueKey('marketplace-$what'),
    controller: controller,
    maxLength: maxLength,
    textCapitalization: TextCapitalization.words,
    decoration: InputDecoration(
      labelText: what == 'colour' ? 'Colour' : 'Size',
      hintText: what == 'colour' ? 'e.g. Maroon' : 'e.g. M, 6.3 m',
      border: const OutlineInputBorder(),
      counterText: '',
    ),
    validator: (_) =>
        what == 'colour' &&
            !_variants.isEmpty &&
            _clean(_colour) == null &&
            _clean(_size) == null
        ? 'Give this one a colour or size too.'
        : null,
  );

  /// The colour / size typed on the form, as a variant; null when neither is given.
  MarketplaceVariant? get _firstVariant =>
      _clean(_colour) == null && _clean(_size) == null
      ? null
      : MarketplaceVariant(
          id: _firstSaved?.id,
          colour: _clean(_colour),
          size: _clean(_size),
          price: double.tryParse(_price.text.trim()),
          stock: int.tryParse(_quantity.text.trim()) ?? 0,
        );

  /// How long each text may be, from the server's options.
  MarketplaceTextLimits get _limits =>
      ref.watch(marketplaceOptionsProvider).value?.textLimits ??
      const MarketplaceTextLimits();

  /// The business's district, when its registered address says it.
  District? get _businessDistrict =>
      ref.read(marketplaceBusinessDistrictProvider).value;

  /// Where the post is: where the business is registered. An old post the address cannot place
  /// keeps where it was.
  String? get _placeDistrictId => _businessDistrict?.id ?? _old?.districtId;

  MarketplacePostInput _input(MarketplaceCategory category) {
    final kind = category.kind;
    final wholesale = _sellsWholesale(category);
    final keepsStock = _keepsStock(category);
    // The colour / size on the form, then each one added below.
    final variants = keepsStock
        ? [?_firstVariant, ..._variants.items]
        : const <MarketplaceVariant>[];
    final byVariant = variants.isNotEmpty;
    final fromBusiness = _businessDistrict != null;
    final profile = ref.read(businessProfileProvider).value;
    final shipsTo = category.tracksStock
        ? _shipsTo
        : MarketplaceShipsTo.allIndia;
    return MarketplacePostInput(
      categoryId: category.id,
      subCategoryId: category.subCategories.isEmpty ? null : _subCategoryId,
      title: _title.text.trim(),
      description: _clean(_description),
      // A product with variants is priced by them; the server takes the lowest.
      price: kind == MarketplacePostKind.advertisement || byVariant
          ? null
          : double.tryParse(_price.text.trim()),
      // A product sells by the piece.
      priceUnit:
          kind == MarketplacePostKind.advertisement || category.tracksStock
          ? null
          : _clean(_priceUnit),
      tradeType: wholesale
          ? MarketplaceTradeType.wholesale
          : MarketplaceTradeType.retail,
      minOrderQuantity: wholesale ? int.tryParse(_minOrder.text.trim()) : null,
      condition: category.tracksStock ? _condition : null,
      // With colours and sizes the server adds their stock up; otherwise the one count.
      quantity: byVariant
          ? null
          : keepsStock || kind == MarketplacePostKind.foodOffer || wholesale
          ? int.tryParse(_quantity.text.trim())
          : null,
      variants: variants,
      // A food offer's usual price, or a product's MRP.
      originalPrice:
          kind == MarketplacePostKind.foodOffer || category.tracksStock
          ? double.tryParse(_originalPrice.text.trim())
          : null,
      customDetails: _customDetails.values,
      // A post's place is the business's: its pin, so "near you" works.
      latitude: fromBusiness ? profile?.latitude : _old?.latitude,
      longitude: fromBusiness ? profile?.longitude : _old?.longitude,
      deliversEverywhere: shipsTo == MarketplaceShipsTo.allIndia,
      deliveryStateId: shipsTo == MarketplaceShipsTo.allIndia
          ? null
          : _shipStateId,
      deliveryDistrictIds: shipsTo == MarketplaceShipsTo.districts
          ? [..._deliveryDistrictIds]
          : const [],
      startsAt: kind == MarketplacePostKind.listing ? null : _startsAt,
      endsAt: kind == MarketplacePostKind.listing ? null : _endsAt,
      contactPhone: kind == MarketplacePostKind.advertisement
          ? _clean(_phone)
          : null,
      districtId: _placeDistrictId!,
      area: fromBusiness ? profile?.city : _old?.area,
      attributes: _attributes.valuesFor(category.fieldsFor(_subCategoryId)),
    );
  }

  Future<void> _submit(MarketplaceCategory? category) async {
    FocusScope.of(context).unfocus();
    final valid = _formKey.currentState!.validate();
    final problem = category == null
        ? 'Choose a category.'
        : _placeDistrictId == null
        ? _noAddress
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
    // A product is named and described as one; other posts keep their title.
    final isProduct = category?.tracksStock ?? false;
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
                maxLength: _limits.title,
                decoration: InputDecoration(
                  labelText: isProduct ? 'Product name' : 'Title',
                  hintText: isProduct
                      ? 'e.g. Silk saree, Cotton shirt, Swift VXi 2019'
                      : 'e.g. 10 kg bananas, Veg biryani, Cricket tournament',
                  border: const OutlineInputBorder(),
                  counterText: '',
                ),
                validator: (v) => (v ?? '').trim().isEmpty
                    ? '${isProduct ? 'Product name' : 'Title'} is required.'
                    : null,
              ),
              const SizedBox(height: 14),
              TextFormField(
                key: const ValueKey('marketplace-description'),
                controller: _description,
                maxLines: 3,
                maxLength: _limits.description,
                decoration: InputDecoration(
                  labelText: isProduct
                      ? 'Product description (optional)'
                      : 'Description (optional)',
                  border: const OutlineInputBorder(),
                  counterText: '',
                ),
              ),
              const SizedBox(height: 14),
              if (category != null) ..._kindSection(category, options),
              if (category != null)
                MarketplaceCategoryFieldsSection(
                  fields: category.fieldsFor(_subCategoryId),
                  values: _attributes,
                  maxValueLength: _limits.attributeValue,
                  onChanged: () => setState(() {}),
                ),
              if (category != null) ...[
                MarketplaceCustomDetailsSection(
                  rows: _customDetails,
                  limits: _limits,
                ),
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
      // A product is priced above, with its MRP and offer — sold by the piece, no "Per".
      if (!category.tracksStock) ...[
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
      ],
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
        maxLength: _limits.contactPhoneMaxDigits + 1,
        decoration: const InputDecoration(
          labelText: 'Contact phone (optional)',
          border: OutlineInputBorder(),
          counterText: '',
        ),
        validator: (v) {
          final text = (v ?? '').trim();
          return text.isEmpty || _limits.isContactPhone(text)
              ? null
              : 'Enter ${_limits.contactPhoneMinDigits} to ${_limits.contactPhoneMaxDigits} digits.';
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
    // As far ahead as a start may be, plus the longest run an advert may have.
    final options = ref.watch(marketplaceOptionsProvider).value;
    final last = first.add(
      Duration(
        days:
            (options?.maxStartDaysAhead ??
                MarketplaceTextLimits.fallbackStartDaysAhead) +
            (options?.maxAdDays ?? 0),
      ),
    );
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

  /// Why a district list cannot open yet: no state, still loading, or failed. The field stays
  /// locked and says so, rather than opening an empty list.
  static String? _districtHelp(
    String? stateId,
    AsyncValue<List<District>>? districtsAsync,
  ) {
    final empty = districtsAsync?.value?.isEmpty ?? true;
    if (stateId == null) return 'Choose the state first.';
    if (districtsAsync!.isLoading && empty) return 'Loading districts…';
    if (districtsAsync.hasError && empty) {
      return 'Could not load districts. Choose the state again.';
    }
    return null;
  }

  /// A state list where picking the same state again asks once more for a district list that
  /// failed to load.
  Widget _stateField({
    required Key key,
    required List<LocationState> states,
    required String? value,
    required String requiredMessage,
    required ValueChanged<String> onPicked,
  }) => SelectField<String>(
    key: key,
    label: 'State',
    options: [for (final s in states) SelectOption(s.id, s.name)],
    initialValue: value,
    validator: (v) => v == null ? requiredMessage : null,
    onChanged: (id) => setState(() {
      if (id == value) ref.invalidate(districtsForStatesProvider(id));
      onPicked(id);
    }),
  );

  /// Said when the business's registered address does not tell its district.
  static const _noAddress =
      'Add your business address in your profile. Your posts are shown where your business is.';

  /// Where a post is comes from the business's registered address, so the form never asks. It
  /// only says so when that address cannot place the business. A product then says where it ships.
  List<Widget> _placeSection(MarketplaceCategory? category) {
    final theme = Theme.of(context);
    final business = ref.watch(marketplaceBusinessDistrictProvider);
    // Kept loaded: the post takes its town and pin from the profile when saved.
    ref.watch(businessProfileProvider);
    final unplaced =
        !business.isLoading && business.value == null && _old == null;
    return [
      if (unplaced) ...[
        Row(
          key: const ValueKey('marketplace-no-business-address'),
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.info_outline, size: 18, color: theme.colorScheme.error),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                _noAddress,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.error,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
      ],
      if (category?.tracksStock ?? false)
        ..._shipsToSection(ref.watch(locationStatesProvider).value ?? const []),
    ];
  }

  /// "Ships to": All India; a whole state; or a state and the districts in it.
  List<Widget> _shipsToSection(List<LocationState> states) {
    final stateId = _shipStateId;
    final districtsAsync =
        _shipsTo == MarketplaceShipsTo.districts && stateId != null
        ? ref.watch(districtsForStatesProvider(stateId))
        : null;
    final districts = districtsAsync?.value ?? const <District>[];
    return [
      SelectField<MarketplaceShipsTo>(
        key: const ValueKey('marketplace-ships-to'),
        label: 'Ships to',
        options: const [
          SelectOption(
            MarketplaceShipsTo.allIndia,
            'All India',
            detail: 'Anyone in India can order it',
          ),
          SelectOption(
            MarketplaceShipsTo.state,
            'State',
            detail: 'The whole state, e.g. all of Tamil Nadu',
          ),
          SelectOption(
            MarketplaceShipsTo.districts,
            'State + districts',
            detail: 'Only the districts you pick in one state',
          ),
        ],
        initialValue: _shipsTo,
        // No state is picked for the business: it chooses where it ships.
        onChanged: (v) => setState(() => _shipsTo = v),
      ),
      if (_shipsTo != MarketplaceShipsTo.allIndia) ...[
        const SizedBox(height: 14),
        _stateField(
          key: const ValueKey('marketplace-ships-state'),
          states: states,
          value: _shipStateId,
          requiredMessage: 'Choose the state it ships in.',
          onPicked: (id) {
            if (id != _shipStateId) _deliveryDistrictIds = {};
            _shipStateId = id;
          },
        ),
      ],
      if (_shipsTo == MarketplaceShipsTo.districts) ...[
        const SizedBox(height: 14),
        FormField<Set<String>>(
          key: ValueKey('marketplace-delivery-districts-$stateId'),
          validator: (_) => _deliveryDistrictIds.isEmpty
              ? 'Choose at least one district.'
              : null,
          builder: (field) => InkWell(
            onTap: districts.isEmpty
                ? null
                : () => _pickDeliveryDistricts(districts),
            borderRadius: BorderRadius.circular(12),
            child: InputDecorator(
              isEmpty: _deliveryDistrictIds.isEmpty,
              decoration: InputDecoration(
                labelText: 'Districts it ships to',
                helperText:
                    _districtHelp(stateId, districtsAsync) ??
                    'In the state above.',
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
    maxLength: _limits.priceUnit,
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
