import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:zuno/features/business_plan/domain/business_plan.dart';
import 'package:zuno/features/business_plan/presentation/plan_lock.dart';
import 'package:zuno/core/router/push_screen.dart';
import 'package:zuno/core/theme/app_colors.dart';
import 'package:zuno/core/utils/formatting.dart';
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
import 'package:zuno/shared/widgets/job_location_card.dart';
import 'package:zuno/shared/widgets/location_pin_picker.dart';
import 'package:zuno/shared/widgets/multi_select_sheet.dart';
import 'package:zuno/shared/widgets/sheet_drag_handle.dart';
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
}) => pushSheet<void>(
  context,
  // Through the router: the phone's back button closes the form instead of leaving the app, and
  // asks first when a change is not saved — as do a tap outside and the handle.
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
  );

  /// A product's Quantity: how many come in one item sold — 1, or 3 for a pack of 3. Not its stock.
  late final _packQuantity = TextEditingController(
    text: '${_old?.packQuantity ?? 1}',
  );
  late final _minOrder = TextEditingController(
    text: _old?.minOrderQuantity?.toString(),
  );
  late final _phone = TextEditingController(text: _old?.contactPhone);

  /// A food offer's or advert's own place — a stall, an event ground — typed and pinned on the map.
  /// Until a pin is dropped, the post is where the business is registered.
  late final _place = TextEditingController(
    text: _hasOwnPlace ? _old?.area : null,
  );
  late double? _pinLatitude = _hasOwnPlace ? _old?.latitude : null;
  late double? _pinLongitude = _hasOwnPlace ? _old?.longitude : null;
  late String? _pinDistrictId = _hasOwnPlace ? _old?.districtId : null;
  bool _findingPin = false;

  /// A saved food offer or advert keeps the place it was saved with.
  bool get _hasOwnPlace =>
      _old != null &&
      (_old.kind == MarketplacePostKind.foodOffer ||
          _old.kind == MarketplacePostKind.advertisement);

  /// Food offers and adverts take a place of their own; products and B2B lots are where the business is.
  static bool _takesOwnPlace(MarketplaceCategory? category) =>
      category?.kind == MarketplacePostKind.foodOffer ||
      category?.kind == MarketplacePostKind.advertisement;

  /// The longest place text, the same as the server's.
  static const _placeMaxLength = 120;
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

  /// A post on show (Active) or hidden from customers (Paused), as a service is Active or
  /// Inactive. Off also frees its place on the plan.
  late bool _isActive =
      _old == null || _old.status != MarketplacePostStatus.paused;

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

  /// Set by the first Save. From then on every field is checked again as it changes, so an error
  /// goes away as soon as the value is put right (it used to stay until the next Save).
  bool _submitted = false;
  String? _errorMessage;
  String? _successMessage;

  /// A colour / size just changed in its sheet: said for a moment, as the form stays open.
  String? _variantNotice;
  Timer? _variantNoticeTimer;

  void _showVariantNotice(String notice) {
    if (!mounted) return;
    setState(() => _variantNotice = notice);
    // A later change starts its own three seconds.
    _variantNoticeTimer?.cancel();
    _variantNoticeTimer = Timer(const Duration(seconds: 3), () {
      if (mounted) setState(() => _variantNotice = null);
    });
  }

  /// A colour / size saved, added or removed in its sheet. On a product already posted it is saved
  /// at once — with its photos — so Save variant is final and the product's own Save is not needed
  /// for it. A new post has no id yet: its colours and sizes go with Save post.
  /// A new post the business has started — typed in, a photo picked, a colour / size added — and
  /// not posted yet. Leaving it asks once: Save post, or Discard. A post already up never asks:
  /// its colours and sizes save on their own.
  /// Something that would be lost: a name, description, price, colour / size or stock typed, a
  /// photo picked, a colour / size added. Picking a category alone is not.
  bool get _hasContent =>
      [
        _title,
        _description,
        _price,
        _originalPrice,
        _colour,
        _size,
        _quantity,
      ].any((c) => c.text.trim().isNotEmpty) ||
      _media.hasChanges ||
      !_variants.isEmpty;

  /// What [_hasContent] was at the last build: the form rebuilds only when it changes, so Back
  /// starts (or stops) asking without a rebuild on every key.
  bool _hadContent = false;

  /// Posted, or the business chose Discard: closing asks nothing.
  bool _settled = false;

  void _markStarted() {
    if (_old == null && mounted && _hasContent != _hadContent) {
      setState(() => _hadContent = _hasContent);
    }
  }

  bool get _unsavedNewPost => _old == null && !_settled && _hasContent;

  /// Whether the form may close now. A new post not yet posted asks first, offering to post it —
  /// its colours and sizes go up with it, so leaving would lose them too. Tapping outside the
  /// question goes back to the form.
  Future<bool> _mayLeave() async {
    if (!_unsavedNewPost) return true;
    final choice = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Post not saved yet'),
        content: Text(
          _variants.isEmpty
              ? 'This product is not posted yet. Save it now, or discard it?'
              : 'This product and its colours / sizes are not posted yet. Save it now, or '
                    'discard it?',
        ),
        actions: [
          TextButton(
            key: const ValueKey('marketplace-leave-discard'),
            onPressed: () => Navigator.of(context).pop('discard'),
            child: const Text('Discard'),
          ),
          FilledButton(
            key: const ValueKey('marketplace-leave-save'),
            onPressed: () => Navigator.of(context).pop('save'),
            child: const Text('Save post'),
          ),
        ],
      ),
    );
    if (!mounted) return false;
    if (choice == 'discard') {
      _settled = true;
      return true;
    }
    if (choice == 'save') {
      // Saving closes the form itself once the post is up; a problem shows on the form.
      final categories =
          ref.read(marketplaceCategoriesProvider).value ??
          const <MarketplaceCategory>[];
      await _submit(categories.where((c) => c.id == _categoryId).firstOrNull);
    }
    return false;
  }

  @override
  void initState() {
    super.initState();
    if (_old == null) {
      SheetLeaveGuard.watch(widget, _mayLeave);
      _media.addListener(_markStarted);
    }
  }

  Future<void> _noteVariant(String change) async {
    final old = _old;
    final main = _firstVariant;
    if (old == null || !old.keepsStock || main == null) {
      // Not saved on its own: it goes up with the product. Said plainly, so it is not taken as saved.
      _showVariantNotice(
        old == null
            ? '$change — tap Save post to post it with the product.'
            : '$change — tap Save changes to save it with the product.',
      );
      return;
    }

    try {
      final repository = ref.read(marketplaceRepositoryProvider);
      final saved = await repository.replaceVariants(old.id, [
        main,
        ..._variants.items,
      ]);
      final latest = await uploadMarketplaceVariantPhotos(
        repository,
        saved,
        _variants.pendingPhotos,
      );
      // The rows as the server keeps them now: new ones have ids, photos are uploaded.
      _variants.resetFrom(
        latest.variants.skip(1).toList(),
        price: latest.price,
      );
      reloadMarketplace(ref);
      _showVariantNotice('$change — saved.');
    } catch (e) {
      if (mounted) _showError(e.toString());
    }
  }

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
    SheetLeaveGuard.forget(widget);
    for (final c in [
      _title,
      _description,
      _price,
      _originalPrice,
      _priceUnit,
      _quantity,
      _packQuantity,
      _minOrder,
      _colour,
      _size,
      _phone,
      _place,
    ]) {
      c.dispose();
    }
    _variantNoticeTimer?.cancel();
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
  /// The line under the Active switch, by what is being posted.
  String _inactiveHint(MarketplaceCategory category) => switch (category.kind) {
    MarketplacePostKind.foodOffer =>
      'Inactive food offers are hidden from customers.',
    MarketplacePostKind.advertisement =>
      'Inactive adverts are hidden from customers.',
    _ when _sellsWholesale(category) =>
      'Inactive B2B posts are hidden from buyers.',
    _ => 'Inactive products are hidden from customers.',
  };

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
      _wholeNumber(
        _packQuantity,
        key: 'marketplace-pack-quantity',
        label: 'Quantity',
        helperText: 'How many in one item sold — 1, or 3 for a pack of 3.',
        required: true,
      ),
      const SizedBox(height: 14),
      if (keepsStock) ...[
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
          onChanged: _noteVariant,
          photoSlots:
              options?.variantImageSlots ?? marketplaceDefaultVariantImageSlots,
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
          // The main product is on sale whenever the post is: its on/off is the Active switch
          // above, never a switch of its own.
          isActive: true,
          customDetails: _firstSaved?.customDetails ?? const [],
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

  /// What stops the post being placed, or null. Waits while the business's place is still being
  /// worked out — Save pressed early is not "no address". A lookup that failed asks to try again;
  /// only an address that truly cannot be placed sends the business to its profile.
  Future<String?> _placeProblem(MarketplaceCategory category) async {
    // Pinned on the map: the pin says where, whatever the business address.
    if (_takesOwnPlace(category) && _pinDistrictId != null) return null;
    try {
      await ref.read(marketplaceBusinessDistrictProvider.future);
    } on Object catch (error) {
      // An old post keeps where it was.
      if (_old?.districtId != null) return null;
      return error is BusinessPlaceUncheckedException
          ? error.toString()
          : const BusinessPlaceUncheckedException().toString();
    }
    return _placeDistrictId == null ? _noAddress : null;
  }

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
    final ownPlace = _takesOwnPlace(category);
    final pinned = ownPlace && _pinDistrictId != null;
    final typedPlace = ownPlace ? _clean(_place) : null;
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
      packQuantity: category.tracksStock
          ? int.tryParse(_packQuantity.text.trim())
          : null,
      variants: variants,
      // A food offer's usual price, or a product's MRP.
      originalPrice:
          kind == MarketplacePostKind.foodOffer || category.tracksStock
          ? double.tryParse(_originalPrice.text.trim())
          : null,
      customDetails: _customDetails.values,
      // A post's place is the business's — its pin, so "near you" works — unless a food offer or
      // advert was pinned somewhere of its own.
      latitude: pinned
          ? _pinLatitude
          : fromBusiness
          ? profile?.latitude
          : _old?.latitude,
      longitude: pinned
          ? _pinLongitude
          : fromBusiness
          ? profile?.longitude
          : _old?.longitude,
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
      districtId: pinned ? _pinDistrictId! : _placeDistrictId!,
      area: typedPlace ?? (fromBusiness ? profile?.city : _old?.area),
      attributes: _attributes.valuesFor(category.fieldsFor(_subCategoryId)),
    );
  }

  Future<void> _submit(MarketplaceCategory? category) async {
    FocusScope.of(context).unfocus();
    setState(() => _submitted = true);
    final valid = _formKey.currentState!.validate();
    final problem = category == null
        ? 'Choose a category.'
        : await _placeProblem(category);
    if (!mounted) return;
    if (!valid || problem != null || category == null) {
      setState(() => _errorMessage = problem);
      // Save is at the bottom: bring the first field in error into view, or the message at the top.
      if (!valid) {
        _showFirstFieldError();
      } else if (problem != null) {
        _showError(problem);
      }
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
      // Kept whole: its colours / sizes now have ids for their own photos.
      final saved = old == null
          ? await repository.create(input)
          : await repository.update(old.id, input);
      final id = saved.id;

      // Switched on or off: the post's status follows (paused, not deleted).
      final wasActive =
          old == null || old.status != MarketplacePostStatus.paused;
      if (_isActive != wasActive) {
        await repository.changeStatus(
          id,
          _isActive
              ? MarketplacePostStatus.active
              : MarketplacePostStatus.paused,
        );
      }

      for (var slot = 0; slot < _media.slotCount; slot++) {
        final bytes = _media.pickedImage(slot);
        if (bytes != null) {
          await repository.uploadImage(id, slot, bytes);
        } else if (_media.isImageRemoved(slot)) {
          await repository.removeImage(id, slot);
        }
      }

      // Each colour / size's own photos, now that every one has an id.
      await uploadMarketplaceVariantPhotos(
        repository,
        saved,
        _variants.pendingPhotos,
      );

      reloadMarketplace(ref);
      if (!mounted) return;
      setState(() {
        // Posted: closing now loses nothing, so it asks nothing.
        _settled = true;
        _successMessage = old == null ? 'Post added.' : 'Post updated.';
      });
      await Future<void>.delayed(const Duration(milliseconds: 900));
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      if (mounted) _showError(e.toString());
      // Refused by the plan: the lock offers the plans over the form.
      if (mounted) showLockIfPlanLimit(context, e, ListingArea.marketplace);
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

  /// Scrolls the first field that failed its check (in form order) into view, so a Save from the
  /// bottom shows what to put right — the error under "Product name" is otherwise out of sight.
  void _showFirstFieldError() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final formContext = _formKey.currentContext;
      if (!mounted || formContext == null) return;
      BuildContext? first;
      void visit(Element element) {
        if (first != null) return;
        if (element is StatefulElement &&
            element.state is FormFieldState &&
            (element.state as FormFieldState).hasError) {
          first = element;
          return;
        }
        element.visitChildren(visit);
      }

      (formContext as Element).visitChildren(visit);
      final target = first;
      if (target != null && target.mounted) {
        Scrollable.ensureVisible(
          target,
          alignment: 0.2,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final categoriesAsync = ref.watch(marketplaceCategoriesProvider);
    final categories = categoriesAsync.value ?? const <MarketplaceCategory>[];
    final category = categories.where((c) => c.id == _categoryId).firstOrNull;
    final options = ref.watch(marketplaceOptionsProvider).value;
    final theme = Theme.of(context);

    // A Stack like the rent item form's, so "Post added." shows over the form wherever it is
    // scrolled to — the business saves from the bottom. A new post not yet posted asks before it
    // closes (Save post or Discard); anything else closes at once.
    return PopScope(
      canPop: !_unsavedNewPost || _isSaving,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        final navigator = Navigator.of(context);
        if (await _mayLeave()) navigator.pop();
      },
      child: Stack(
        children: [
          _form(context, theme, categoriesAsync, categories, category, options),
          if (_successMessage == null && _variantNotice != null)
            Positioned(
              top: 12,
              right: 20,
              left: 20,
              child: ServiceFormMessageBanner(
                key: const ValueKey('marketplace-variant-saved'),
                message: _variantNotice!,
                color: theme.colorScheme.primary,
                onColor: theme.colorScheme.onPrimary,
                // A tick only when it is really saved; otherwise what to do next.
                icon: _variantNotice!.endsWith('saved.')
                    ? Icons.check_circle
                    : Icons.info_outline,
              ),
            ),
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
      ),
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
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Pulled down, it asks to close — and the form asks first when a change is not saved.
          SheetDragHandle(onDismiss: () => Navigator.maybePop(context)),
          Flexible(
            child: SingleChildScrollView(
              controller: _scroll,
              child: Form(
                key: _formKey,
                onChanged: _markStarted,
                autovalidateMode: _submitted
                    ? AutovalidateMode.always
                    : AutovalidateMode.disabled,
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
                      // An advert's banner is framed wide, as the banner strip shows it.
                      firstSlotAspectRatio:
                          category?.kind == MarketplacePostKind.advertisement
                          ? 3
                          : null,
                      hint: category?.kind == MarketplacePostKind.advertisement
                          ? 'The first photo is the advert banner: framed wide (3 : 1), as customers see it in the banner strip.'
                          : 'The first photo is the cover customers see.',
                      onError: (message) =>
                          setState(() => _errorMessage = message),
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
                              detail:
                                  c.description ?? options?.kindName(c.kind),
                            ),
                        ],
                        initialValue: _categoryId,
                        validator: (v) =>
                            v == null ? 'Choose a category.' : null,
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
                    if (category != null &&
                        category.subCategories.isNotEmpty) ...[
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
                    // As on a service: off hides the whole product (its colours and sizes too),
                    // B2B lot, food offer or advert, and counts it in its group's Inactive tile.
                    if (category != null)
                      SwitchListTile(
                        key: const ValueKey('marketplace-active'),
                        contentPadding: EdgeInsets.zero,
                        title: const Text('Active'),
                        subtitle: Text(_inactiveHint(category)),
                        value: _isActive,
                        onChanged: (value) => setState(() => _isActive = value),
                      ),
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
          ),
        ],
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
        if (wholesale)
          ..._wholesaleSection(options)
        else
          _priceRow(priceLabel: 'Price', unitHint: 'kg, dozen, piece'),
        const SizedBox(height: 14),
      ],
    ];
  }

  /// B2B, in plain words and in the order a dealer thinks of it: what it is sold in (kg for
  /// onions, piece for taps), the price for one of those, the least one buyer must order, and how
  /// much there is — then the whole of it in one line.
  List<Widget> _wholesaleSection(MarketplaceOptions? options) {
    final units = options?.wholesaleUnits ?? marketplaceDefaultWholesaleUnits;
    final chosen = _clean(_priceUnit);
    // A unit an older post was saved with stays choosable.
    final choices = [
      ...units,
      if (chosen != null && !units.contains(chosen)) chosen,
    ];
    final unit = chosen ?? 'unit';
    return [
      SelectField<String>(
        key: const ValueKey('marketplace-price-unit'),
        label: 'Sold in',
        helperText: 'kg for onions, piece for taps, box for tiles.',
        options: [for (final u in choices) SelectOption(u, u)],
        initialValue: chosen,
        validator: (v) => v == null ? 'Choose what it is sold in.' : null,
        onChanged: (v) => setState(() => _priceUnit.text = v),
      ),
      const SizedBox(height: 14),
      _money(_price, key: 'marketplace-price', label: 'Price per $unit'),
      const SizedBox(height: 14),
      _wholeNumber(
        _minOrder,
        key: 'marketplace-min-order',
        label: 'Minimum order ($unit)',
        helperText: 'The least one buyer must order, e.g. 100 $unit.',
        required: true,
      ),
      const SizedBox(height: 14),
      _wholeNumber(
        _quantity,
        key: 'marketplace-quantity',
        label: 'Stock available ($unit, optional)',
        helperText: 'How much you have to sell in all.',
        required: false,
      ),
      const SizedBox(height: 10),
      // "₹45 per kg · buyers order at least 100 kg · 2,000 kg available" — as buyers will read it.
      ListenableBuilder(
        listenable: Listenable.merge([_price, _minOrder, _quantity]),
        builder: (context, _) {
          final price = double.tryParse(_price.text.trim());
          final min = int.tryParse(_minOrder.text.trim());
          final stock = int.tryParse(_quantity.text.trim());
          final parts = [
            if (price != null) '${rupees(price)} per $unit',
            if (min != null) 'buyers order at least $min $unit',
            if (stock != null) '$stock $unit available',
          ];
          if (parts.isEmpty) return const SizedBox.shrink();
          return Text(
            parts.join(' · '),
            key: const ValueKey('marketplace-wholesale-summary'),
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
          );
        },
      ),
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
            : 'Up to $hours hours. Customers see it on the map and come to your shop.',
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
    // Pinned on the map, a food offer or advert does not need the business's own place.
    final pinned = _takesOwnPlace(category) && _pinDistrictId != null;
    // A lookup that failed is not a missing address: it can be tried again.
    final unchecked =
        !pinned && !business.isLoading && business.hasError && _old == null;
    final unplaced =
        !pinned &&
        !business.isLoading &&
        !business.hasError &&
        business.value == null &&
        _old == null;
    return [
      if (_takesOwnPlace(category)) ...[
        _placeField(category!),
        if (_pinLatitude != null && _pinLongitude != null) ...[
          const SizedBox(height: 8),
          JobLocationCard(
            key: const ValueKey('marketplace-place-map'),
            addressLines: [_place.text.trim()],
            latitude: _pinLatitude,
            longitude: _pinLongitude,
            showActions: false,
          ),
        ],
        const SizedBox(height: 14),
      ],
      if (unchecked) ...[
        Row(
          key: const ValueKey('marketplace-place-unchecked'),
          children: [
            Icon(
              Icons.wifi_off_rounded,
              size: 18,
              color: theme.colorScheme.error,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                const BusinessPlaceUncheckedException().toString(),
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.error,
                ),
              ),
            ),
            TextButton(
              key: const ValueKey('marketplace-place-retry'),
              onPressed: () {
                setState(() => _errorMessage = null);
                ref.invalidate(marketplaceBusinessDistrictProvider);
              },
              child: const Text('Retry'),
            ),
          ],
        ),
        const SizedBox(height: 14),
      ],
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

  /// Where a food offer or advert is: typed, and pinned on the same map picker the vacancy form uses.
  /// Without a pin it is where the business is registered.
  Widget _placeField(MarketplaceCategory category) {
    final pinned = _pinDistrictId != null;
    final isFood = category.kind == MarketplacePostKind.foodOffer;
    return TextFormField(
      key: const ValueKey('marketplace-place'),
      controller: _place,
      maxLength: _placeMaxLength,
      textCapitalization: TextCapitalization.words,
      decoration: InputDecoration(
        labelText: 'Location',
        hintText: isFood
            ? 'e.g. Anna Bus Stand, Nagercoil'
            : 'e.g. KP Road, Nagercoil',
        helperText: pinned
            ? 'Pinned on the map. Customers get directions to it.'
            : 'Your business address, unless you pin another place.',
        helperMaxLines: 2,
        suffixIcon: _findingPin
            ? const Padding(
                padding: EdgeInsets.all(12),
                child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              )
            : IconButton(
                key: const ValueKey('marketplace-place-pin'),
                tooltip: 'Pin on the map',
                icon: Icon(
                  pinned ? Icons.location_on : Icons.add_location_alt_outlined,
                ),
                onPressed: _pinPlace,
              ),
      ),
    );
  }

  /// Opens the map at the pin (or the business's own), and keeps the place picked — with the
  /// district it is in, which decides where customers see the post.
  Future<void> _pinPlace() async {
    final profile = ref.read(businessProfileProvider).value;
    final picked = await showLocationPinPicker(
      context,
      initialLatitude: _pinLatitude ?? profile?.latitude,
      initialLongitude: _pinLongitude ?? profile?.longitude,
      title: 'Where is it?',
    );
    if (picked == null || !mounted) return;

    setState(() => _findingPin = true);
    try {
      final district = await marketplaceDistrictAt(
        ref,
        picked.latitude,
        picked.longitude,
      );
      if (!mounted) return;
      if (district == null) {
        _showError(
          'That place is outside the districts Zuno covers. Pin a place nearer.',
        );
        return;
      }
      setState(() {
        _pinLatitude = picked.latitude;
        _pinLongitude = picked.longitude;
        _pinDistrictId = district.id;
        if (_place.text.trim().isEmpty) {
          final summary = picked.summary;
          _place.text = summary.length > _placeMaxLength
              ? summary.substring(0, _placeMaxLength)
              : summary;
        }
        _errorMessage = null;
      });
    } on BusinessPlaceUncheckedException catch (e) {
      if (mounted) _showError(e.toString());
    } finally {
      if (mounted) setState(() => _findingPin = false);
    }
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

  /// What a retail price or food offer is for — "plate", "box" — if anything. B2B picks its unit
  /// from a list instead ("Sold in").
  Widget _unitField(String hint) => TextFormField(
    key: const ValueKey('marketplace-price-unit'),
    controller: _priceUnit,
    maxLength: _limits.priceUnit,
    decoration: InputDecoration(
      labelText: 'Per (optional)',
      hintText: hint,
      border: const OutlineInputBorder(),
      counterText: '',
    ),
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
    String? helperText,
  }) => TextFormField(
    key: ValueKey(key),
    controller: controller,
    keyboardType: TextInputType.number,
    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
    decoration: InputDecoration(
      labelText: label,
      helperText: helperText,
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
