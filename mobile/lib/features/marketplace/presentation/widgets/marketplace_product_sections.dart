import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:zuno/core/utils/formatting.dart';
import 'package:zuno/features/marketplace/domain/entities/marketplace_post.dart';
import 'package:zuno/features/marketplace/presentation/widgets/marketplace_post_lines.dart';
import 'package:zuno/shared/widgets/confirm_dialog.dart';
import 'package:zuno/shared/widgets/primary_button.dart';

/// "449", "449.5" — a price as it is typed.
String _plain(double? v) => v == null
    ? ''
    : v == v.roundToDouble()
    ? '${v.toInt()}'
    : v.toStringAsFixed(2);

final _money = [FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))];
final _wholeNumber = [FilteringTextInputFormatter.digitsOnly];

/// A product's price, its MRP and the offer between them, kept in step: typing an offer works the
/// price out from the MRP; changing the price or the MRP works the offer out again.
class MarketplacePriceFields extends StatefulWidget {
  const MarketplacePriceFields({
    required this.price,
    required this.mrp,
    required this.highestPrice,
    super.key,
  });

  final TextEditingController price;
  final TextEditingController mrp;

  /// The dearest price it sells at, which the MRP may not be under.
  final double? Function() highestPrice;

  @override
  State<MarketplacePriceFields> createState() => _MarketplacePriceFieldsState();
}

class _MarketplacePriceFieldsState extends State<MarketplacePriceFields> {
  final _offer = TextEditingController();

  /// Set while the offer itself is being typed, so the price it writes does not write it back.
  bool _typingOffer = false;

  @override
  void initState() {
    super.initState();
    widget.price.addListener(_showOffer);
    widget.mrp.addListener(_showOffer);
    _showOffer();
  }

  @override
  void dispose() {
    widget.price.removeListener(_showOffer);
    widget.mrp.removeListener(_showOffer);
    _offer.dispose();
    super.dispose();
  }

  void _showOffer() {
    if (_typingOffer) return;
    final percent = marketplaceOfferPercent(
      double.tryParse(widget.price.text.trim()),
      double.tryParse(widget.mrp.text.trim()),
    );
    final text = percent == null ? '' : '$percent';
    if (_offer.text != text) _offer.text = text;
  }

  void _offerTyped(String text) {
    final percent = double.tryParse(text.trim());
    final mrp = double.tryParse(widget.mrp.text.trim());
    if (percent == null || mrp == null || percent <= 0 || percent >= 100) {
      return;
    }
    _typingOffer = true;
    widget.price.text = _plain(mrp * (100 - percent) / 100);
    _typingOffer = false;
  }

  InputDecoration _box(String label) =>
      InputDecoration(labelText: label, border: const OutlineInputBorder());

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: TextFormField(
              key: const ValueKey('marketplace-price'),
              controller: widget.price,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              inputFormatters: _money,
              decoration: _box('Price').copyWith(prefixText: '₹ '),
              validator: (v) {
                final n = double.tryParse((v ?? '').trim());
                return n == null || n <= 0 ? 'Enter a valid price.' : null;
              },
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: TextFormField(
              key: const ValueKey('marketplace-mrp'),
              controller: widget.mrp,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              inputFormatters: _money,
              decoration: _box(
                'MRP (optional)',
              ).copyWith(prefixText: '₹ ', errorMaxLines: 2),
              validator: (v) {
                final text = (v ?? '').trim();
                if (text.isEmpty) return null;
                final mrp = double.tryParse(text);
                if (mrp == null || mrp <= 0) return 'Enter a valid price.';
                final price = widget.highestPrice();
                return price != null && mrp < price
                    ? 'Cannot be less than the price.'
                    : null;
              },
            ),
          ),
        ],
      ),
      const SizedBox(height: 14),
      TextFormField(
        key: const ValueKey('marketplace-offer'),
        controller: _offer,
        keyboardType: TextInputType.number,
        inputFormatters: _wholeNumber,
        onChanged: _offerTyped,
        decoration: _box('Offer (optional)').copyWith(
          suffixText: '% off',
          helperText: 'Type it to work the price out from the MRP.',
        ),
        validator: (v) {
          final text = (v ?? '').trim();
          if (text.isEmpty) return null;
          if (widget.mrp.text.trim().isEmpty) return 'Enter the MRP first.';
          final n = int.tryParse(text);
          return n == null || n <= 0 || n >= 100 ? 'Between 1 and 99.' : null;
        },
      ),
    ],
  );
}

/// A new product's variants while the form is open — one per colour / size, each with its own
/// price and stock, kept as a list like a service's items.
class MarketplaceVariantList extends ChangeNotifier {
  MarketplaceVariantList(List<MarketplaceVariant> saved, {double? price})
    : _items = [
        // A variant saved without its own price sold at the post's: it shows that price now.
        for (final v in saved)
          MarketplaceVariant(
            id: v.id,
            colour: v.colour,
            size: v.size,
            price: v.price ?? price,
            stock: v.stock,
            isActive: v.isActive,
            customDetails: v.customDetails,
          ),
      ];

  final List<MarketplaceVariant> _items;

  List<MarketplaceVariant> get items => List.unmodifiable(_items);
  bool get isEmpty => _items.isEmpty;

  /// The stock of the variants on sale, added up — the product's stock. An inactive one's is
  /// not counted.
  int get totalStock =>
      _items.where((v) => v.isActive).fold(0, (sum, v) => sum + v.stock);

  /// The dearest variant, which an MRP may not be under.
  double? get highestPrice => _items
      .map((v) => v.price)
      .whereType<double>()
      .fold<double?>(null, (a, b) => a == null || b > a ? b : a);

  void put(MarketplaceVariant variant, {int? at}) {
    at == null ? _items.add(variant) : _items[at] = variant;
    notifyListeners();
  }

  void removeAt(int index) {
    _items.removeAt(index);
    notifyListeners();
  }
}

/// "Variants": a card per colour / size with its price and stock, edited or removed from its menu,
/// and "Add variant" for another — the way a service's items are managed.
class MarketplaceVariantsSection extends StatelessWidget {
  const MarketplaceVariantsSection({
    required this.variants,
    required this.alsoTaken,
    required this.mrp,
    required this.defaultPrice,
    required this.limits,
    required this.maxQuantity,
    this.title = 'More colours and sizes',
    this.hint =
        'Sold in another colour or size too? Add each with its own price and stock.',
    this.addLabel = 'Add another colour / size',
    super.key,
  });

  final MarketplaceVariantList variants;

  /// The heading, its line, and the add button's words: the form's "More colours and sizes", or
  /// "Colours and sizes" on Manage variants, where every one is listed.
  final String title;
  final String hint;
  final String addLabel;

  /// The colour / size typed on the form itself, which an added one may not repeat.
  final List<MarketplaceVariant> Function() alsoTaken;

  /// The product's MRP, for each variant's offer.
  final double? Function() mrp;

  /// What a new variant's price starts at.
  final double? Function() defaultPrice;
  final MarketplaceTextLimits limits;
  final int maxQuantity;

  Future<void> _edit(BuildContext context, {int? index}) async {
    final existing = index == null ? null : variants.items[index];
    final saved = await showMarketplaceVariantSheet(
      context,
      existing: existing,
      startPrice: existing?.price ?? defaultPrice(),
      others: [
        ...alsoTaken(),
        for (final (i, v) in variants.items.indexed)
          if (i != index) v,
      ],
      limits: limits,
      maxQuantity: maxQuantity,
    );
    if (saved != null) variants.put(saved, at: index);
  }

  Future<void> _remove(BuildContext context, int index) async {
    final confirmed = await showConfirmDialog(
      context,
      title: 'Remove variant?',
      message: '"${variants.items[index].name}" will no longer be sold.',
      confirmLabel: 'Remove',
    );
    if (confirmed) variants.removeAt(index);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ListenableBuilder(
      listenable: variants,
      builder: (context, _) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            title,
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          Text(
            hint,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          for (final (i, v) in variants.items.indexed)
            Card(
              key: ValueKey('marketplace-variant-$i'),
              margin: const EdgeInsets.only(top: 10),
              child: ListTile(
                title: Text(
                  v.name,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                // The figures, then its own details on a line of their own:
                // "Border: Zari · Blouse: With blouse".
                subtitle: Text(
                  [
                    [
                      if (!v.isActive) 'Inactive',
                      if (v.price case final price?) rupees(price),
                      '${v.stock} in stock',
                      if (marketplaceOfferPercent(v.price, mrp()) case final p?)
                        '$p% off',
                    ].join(' · '),
                    if (v.customDetails.isNotEmpty)
                      [for (final d in v.customDetails) '${d.name}: ${d.value}']
                          .join(' · '),
                  ].join('\n'),
                ),
                isThreeLine: v.customDetails.isNotEmpty,
                trailing: PopupMenuButton<String>(
                  key: ValueKey('marketplace-variant-menu-$i'),
                  onSelected: (action) => action == 'edit'
                      ? _edit(context, index: i)
                      : _remove(context, i),
                  itemBuilder: (context) => const [
                    PopupMenuItem(value: 'edit', child: Text('Edit')),
                    PopupMenuItem(value: 'remove', child: Text('Remove')),
                  ],
                ),
              ),
            ),
          const SizedBox(height: 6),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              key: const ValueKey('marketplace-add-variant'),
              onPressed: () => _edit(context),
              icon: const Icon(Icons.add),
              label: Text(addLabel),
            ),
          ),
        ],
      ),
    );
  }
}

/// Adds or edits one variant: its colour and / or size, typed in, its price and its stock. Null when
/// closed without saving.
Future<MarketplaceVariant?> showMarketplaceVariantSheet(
  BuildContext context, {
  required MarketplaceVariant? existing,
  required double? startPrice,
  required List<MarketplaceVariant> others,
  required MarketplaceTextLimits limits,
  required int maxQuantity,
}) => showModalBottomSheet<MarketplaceVariant>(
  context: context,
  isScrollControlled: true,
  builder: (_) => _VariantSheet(
    existing: existing,
    startPrice: startPrice,
    others: others,
    limits: limits,
    maxQuantity: maxQuantity,
  ),
);

class _VariantSheet extends StatefulWidget {
  const _VariantSheet({
    required this.existing,
    required this.startPrice,
    required this.others,
    required this.limits,
    required this.maxQuantity,
  });

  final MarketplaceVariant? existing;
  final double? startPrice;
  final List<MarketplaceVariant> others;
  final MarketplaceTextLimits limits;
  final int maxQuantity;

  @override
  State<_VariantSheet> createState() => _VariantSheetState();
}

class _VariantSheetState extends State<_VariantSheet> {
  final _formKey = GlobalKey<FormState>();
  late final _colour = TextEditingController(text: widget.existing?.colour);
  late final _size = TextEditingController(text: widget.existing?.size);
  late final _price = TextEditingController(text: _plain(widget.startPrice));
  late final _stock = TextEditingController(
    text: widget.existing?.stock.toString(),
  );

  /// On sale; off keeps it but hides it from customers.
  late bool _isActive = widget.existing?.isActive ?? true;

  /// Details only this colour / size has — "Border: Zari".
  late final _details = MarketplaceCustomDetailRows(
    widget.existing?.customDetails ?? const [],
  );

  @override
  void dispose() {
    for (final c in [_colour, _size, _price, _stock]) {
      c.dispose();
    }
    _details.dispose();
    super.dispose();
  }

  static String? _clean(TextEditingController c) =>
      c.text.trim().isEmpty ? null : c.text.trim();

  /// "Red · M" is listed once: the same colour and size twice cannot be told apart.
  String? _checkName(String? _) {
    final colour = _clean(_colour)?.toLowerCase();
    final size = _clean(_size)?.toLowerCase();
    if (colour == null && size == null) {
      return 'Give a colour, a size, or both.';
    }
    final twice = widget.others.any(
      (v) => v.colour?.toLowerCase() == colour && v.size?.toLowerCase() == size,
    );
    return twice ? 'This colour and size is already a variant.' : null;
  }

  void _save() {
    if (!_formKey.currentState!.validate()) return;
    Navigator.of(context).pop(
      MarketplaceVariant(
        id: widget.existing?.id,
        colour: _clean(_colour),
        size: _clean(_size),
        price: double.tryParse(_price.text.trim()),
        stock: int.parse(_stock.text.trim()),
        isActive: _isActive,
        customDetails: _details.values,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    InputDecoration box(String label, {String? hint}) => InputDecoration(
      labelText: label,
      hintText: hint,
      border: const OutlineInputBorder(),
      counterText: '',
    );
    // Scrolls once its own details make it taller than the screen.
    return SingleChildScrollView(
      child: Padding(
        padding: EdgeInsets.only(
          left: 20,
          right: 20,
          top: 20,
          bottom: MediaQuery.of(context).viewInsets.bottom + 20,
        ),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                widget.existing == null ? 'Add variant' : 'Edit variant',
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: TextFormField(
                      key: const ValueKey('marketplace-variant-colour'),
                      controller: _colour,
                      maxLength: widget.limits.colour,
                      textCapitalization: TextCapitalization.words,
                      decoration: box('Colour', hint: 'e.g. Maroon'),
                      validator: _checkName,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextFormField(
                      key: const ValueKey('marketplace-variant-size'),
                      controller: _size,
                      maxLength: widget.limits.size,
                      decoration: box('Size', hint: 'e.g. M, 6.3 m'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: TextFormField(
                      key: const ValueKey('marketplace-variant-price'),
                      controller: _price,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      inputFormatters: _money,
                      decoration: box('Price').copyWith(prefixText: '₹ '),
                      validator: (v) {
                        final n = double.tryParse((v ?? '').trim());
                        return n == null || n <= 0
                            ? 'Enter a valid price.'
                            : null;
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextFormField(
                      key: const ValueKey('marketplace-variant-stock'),
                      controller: _stock,
                      keyboardType: TextInputType.number,
                      inputFormatters: _wholeNumber,
                      decoration: box('Stock'),
                      validator: (v) {
                        final n = int.tryParse((v ?? '').trim());
                        if (n == null) return 'Required.';
                        return n > widget.maxQuantity
                            ? 'At most ${widget.maxQuantity}.'
                            : null;
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              MarketplaceCustomDetailsSection(
                rows: _details,
                limits: widget.limits,
                hint:
                    'Anything only this colour / size has, e.g. Border: Zari.',
                keyPrefix: 'marketplace-variant-detail',
                addKey: 'marketplace-variant-add-detail',
              ),
              const SizedBox(height: 8),
              // As on a service: off keeps it, but customers cannot buy it.
              SwitchListTile(
                key: const ValueKey('marketplace-variant-active'),
                contentPadding: EdgeInsets.zero,
                title: const Text('Active'),
                subtitle: const Text(
                  'Inactive colours and sizes are hidden from customers.',
                ),
                value: _isActive,
                onChanged: (value) => setState(() => _isActive = value),
              ),
              const SizedBox(height: 12),
              PrimaryButton(
                key: const ValueKey('marketplace-variant-save'),
                label: widget.existing == null ? 'Add variant' : 'Save variant',
                onPressed: _save,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// One detail the business names itself while the form is open.
class _DetailRow {
  _DetailRow([MarketplaceCustomDetail? from])
    : name = TextEditingController(text: from?.name),
      value = TextEditingController(text: from?.value);

  final TextEditingController name;
  final TextEditingController value;
  final key = UniqueKey();

  void dispose() {
    name.dispose();
    value.dispose();
  }
}

/// The business's own details while the form is open — "Leather type: Genuine".
class MarketplaceCustomDetailRows extends ChangeNotifier {
  MarketplaceCustomDetailRows(List<MarketplaceCustomDetail> saved)
    : _rows = [for (final d in saved) _DetailRow(d)];

  final List<_DetailRow> _rows;

  /// The filled-in ones, in order; a row left empty is not sent.
  List<MarketplaceCustomDetail> get values => [
    for (final r in _rows)
      if (r.name.text.trim().isNotEmpty && r.value.text.trim().isNotEmpty)
        MarketplaceCustomDetail(
          name: r.name.text.trim(),
          value: r.value.text.trim(),
        ),
  ];

  void add() {
    _rows.add(_DetailRow());
    notifyListeners();
  }

  void _remove(_DetailRow row) {
    _rows.remove(row);
    row.dispose();
    notifyListeners();
  }

  @override
  void dispose() {
    for (final r in _rows) {
      r.dispose();
    }
    super.dispose();
  }
}

/// "More details": what the category's list does not ask — the business names it and fills it in.
class MarketplaceCustomDetailsSection extends StatelessWidget {
  const MarketplaceCustomDetailsSection({
    required this.rows,
    required this.limits,
    this.hint =
        'Anything the list above does not ask, e.g. Leather type: Genuine.',
    this.keyPrefix = 'marketplace-detail',
    this.addKey = 'marketplace-add-detail',
    super.key,
  });

  final MarketplaceCustomDetailRows rows;

  /// How long a detail's name and value may be.
  final MarketplaceTextLimits limits;

  /// The line under "More details", and the keys of its boxes and add button: the form's own, or a
  /// colour / size's in its sheet.
  final String hint;
  final String keyPrefix;
  final String addKey;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ListenableBuilder(
      listenable: rows,
      builder: (context, _) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'More details',
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          Text(
            hint,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          for (final (i, row) in rows._rows.indexed)
            Padding(
              key: row.key,
              padding: const EdgeInsets.only(top: 10),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: TextFormField(
                      key: ValueKey('$keyPrefix-name-$i'),
                      controller: row.name,
                      maxLength: limits.customDetailName,
                      decoration: const InputDecoration(
                        labelText: 'Detail',
                        hintText: 'e.g. Leather type',
                        isDense: true,
                        border: OutlineInputBorder(),
                        counterText: '',
                      ),
                      validator: (v) =>
                          (v ?? '').trim().isEmpty &&
                              row.value.text.trim().isNotEmpty
                          ? 'Name it.'
                          : null,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextFormField(
                      key: ValueKey('$keyPrefix-value-$i'),
                      controller: row.value,
                      maxLength: limits.attributeValue,
                      decoration: const InputDecoration(
                        labelText: 'Value',
                        hintText: 'e.g. Genuine',
                        isDense: true,
                        border: OutlineInputBorder(),
                        counterText: '',
                      ),
                      validator: (v) =>
                          (v ?? '').trim().isEmpty &&
                              row.name.text.trim().isNotEmpty
                          ? 'Fill it in.'
                          : null,
                    ),
                  ),
                  IconButton(
                    key: ValueKey('$keyPrefix-remove-$i'),
                    tooltip: 'Remove',
                    icon: const Icon(Icons.close),
                    onPressed: () => rows._remove(row),
                  ),
                ],
              ),
            ),
          const SizedBox(height: 6),
          TextButton.icon(
            key: ValueKey(addKey),
            onPressed: rows.add,
            icon: const Icon(Icons.add),
            label: const Text('Add a detail'),
          ),
        ],
      ),
    );
  }
}
