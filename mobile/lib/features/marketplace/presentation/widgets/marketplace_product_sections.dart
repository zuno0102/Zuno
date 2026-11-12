import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:zuno/features/marketplace/domain/entities/marketplace_post.dart';

/// One price and one stock being typed — the product's own, or one colour / size's.
class MarketplacePriceStock {
  MarketplacePriceStock({this.id, double? price, int? stock})
    : price = TextEditingController(text: _plain(price)),
      stock = TextEditingController(text: stock?.toString());

  /// The saved colour / size this row edits; null for a new one.
  final String? id;
  final TextEditingController price;
  final TextEditingController stock;

  double? get priceValue => double.tryParse(price.text.trim());
  int? get stockValue => int.tryParse(stock.text.trim());

  static String _plain(double? v) => v == null
      ? ''
      : v == v.roundToDouble()
      ? '${v.toInt()}'
      : '$v';

  void dispose() {
    price.dispose();
    stock.dispose();
  }
}

/// A colour and a size it comes in — either may be absent, never both.
typedef MarketplaceCombination = ({String? colour, String? size});

/// A new product's price and stock while the form is open: one of each, or one per colour / size
/// combination, like a shopping site. The colours and sizes are picked once; every combination of
/// them is a row, and a combination not sold is left out with ×.
class MarketplaceVariantGrid extends ChangeNotifier {
  MarketplaceVariantGrid({
    List<MarketplaceVariant> saved = const [],
    double? price,
    int? stock,
  }) : single = MarketplacePriceStock(
         price: saved.isEmpty ? price : null,
         stock: saved.isEmpty ? stock : null,
       ) {
    for (final v in saved) {
      if (v.colour case final c? when !_has(colours, c)) colours.add(c);
      if (v.size case final s? when !_has(sizes, s)) sizes.add(s);
      _rows[_key((colour: v.colour, size: v.size))] = MarketplacePriceStock(
        id: v.id,
        price: v.price ?? price,
        stock: v.stock,
      );
    }
    // A combination the product was saved without stays left out.
    for (final c in _allCombinations) {
      if (!_rows.containsKey(_key(c))) _removed.add(_key(c));
    }
  }

  /// Chosen colours and sizes, in the order picked.
  final colours = <String>[];
  final sizes = <String>[];

  /// The one price and stock of a product without colours or sizes.
  final MarketplacePriceStock single;

  final _rows = <String, MarketplacePriceStock>{};
  final _removed = <String>{};

  bool get hasVariants => colours.isNotEmpty || sizes.isNotEmpty;

  static bool _has(List<String> list, String value) =>
      list.any((v) => v.toLowerCase() == value.toLowerCase());

  static String _key(MarketplaceCombination c) =>
      '${c.colour?.toLowerCase() ?? ''}\u0000${c.size?.toLowerCase() ?? ''}';

  List<MarketplaceCombination> get _allCombinations => [
    if (colours.isNotEmpty && sizes.isNotEmpty)
      for (final c in colours)
        for (final s in sizes) (colour: c, size: s)
    else if (colours.isNotEmpty)
      for (final c in colours) (colour: c, size: null)
    else
      for (final s in sizes) (colour: null, size: s),
  ];

  /// The rows shown: every combination of the chosen colours and sizes not left out.
  List<MarketplaceCombination> get combinations => [
    for (final c in _allCombinations)
      if (!_removed.contains(_key(c))) c,
  ];

  MarketplacePriceStock rowFor(MarketplaceCombination c) =>
      _rows.putIfAbsent(_key(c), MarketplacePriceStock.new);

  bool isColourChosen(String colour) => _has(colours, colour);
  bool isSizeChosen(String size) => _has(sizes, size);

  void toggleColour(String colour) => _toggle(colours, colour);
  void toggleSize(String size) => _toggle(sizes, size);

  void _toggle(List<String> list, String value) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) return;
    if (_has(list, trimmed)) {
      list.removeWhere((v) => v.toLowerCase() == trimmed.toLowerCase());
    } else {
      list.add(trimmed);
      // Picking a colour or size again brings back its combinations.
      _removed.removeWhere(
        (k) => k.split('\u0000').contains(trimmed.toLowerCase()),
      );
    }
    notifyListeners();
  }

  /// Leaves out one combination that is not sold, e.g. Red in XXL.
  void leaveOut(MarketplaceCombination c) {
    _removed.add(_key(c));
    notifyListeners();
  }

  /// Copies one price and stock into every row shown; an empty value leaves that column alone.
  void applyToAll({required String price, required String stock}) {
    for (final c in combinations) {
      final row = rowFor(c);
      if (price.trim().isNotEmpty) row.price.text = price.trim();
      if (stock.trim().isNotEmpty) row.stock.text = stock.trim();
    }
    notifyListeners();
  }

  /// What the server is sent: a row per combination shown, each with its own price and stock.
  List<MarketplaceVariant> get variants => [
    for (final c in combinations)
      if (rowFor(c) case final row)
        MarketplaceVariant(
          id: row.id,
          colour: c.colour,
          size: c.size,
          price: row.priceValue,
          stock: row.stockValue ?? 0,
        ),
  ];

  /// The post's own price and stock, when it has no colours or sizes.
  double? get price => hasVariants ? null : single.priceValue;
  int? get stock => hasVariants ? null : single.stockValue;

  /// The dearest price it sells at, which an MRP may not be under.
  double? get highestPrice {
    final prices = hasVariants
        ? [for (final v in variants) ?v.price]
        : [?single.priceValue];
    return prices.isEmpty ? null : prices.reduce((a, b) => a > b ? a : b);
  }

  @override
  void dispose() {
    single.dispose();
    for (final r in _rows.values) {
      r.dispose();
    }
    super.dispose();
  }
}

/// "Price and stock": the colours and sizes to tap (from the server's list, or the business's
/// own), then a price and stock for each combination — or one of each when there are none.
class MarketplaceVariantEditor extends StatefulWidget {
  const MarketplaceVariantEditor({
    required this.grid,
    required this.colourOptions,
    required this.sizeOptions,
    required this.maxQuantity,
    required this.limits,
    super.key,
  });

  final MarketplaceVariantGrid grid;
  final List<String> colourOptions;
  final List<String> sizeOptions;
  final int maxQuantity;

  /// The longest colour and size the server takes.
  final MarketplaceTextLimits limits;

  @override
  State<MarketplaceVariantEditor> createState() =>
      _MarketplaceVariantEditorState();
}

class _MarketplaceVariantEditorState extends State<MarketplaceVariantEditor> {
  final _sameStock = TextEditingController();
  final _samePrice = TextEditingController();

  @override
  void dispose() {
    _sameStock.dispose();
    _samePrice.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final grid = widget.grid;
    return ListenableBuilder(
      listenable: grid,
      builder: (context, _) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Price and stock',
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          Text(
            grid.hasVariants
                ? 'A price and stock for each. Tap × on any you do not sell.'
                : 'Sold in colours or sizes? Tap them below.',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 10),
          _ChoiceChips(
            what: 'colour',
            label: 'Colours',
            options: widget.colourOptions,
            chosen: grid.colours,
            isChosen: grid.isColourChosen,
            onToggle: grid.toggleColour,
            maxLength: widget.limits.colour,
          ),
          const SizedBox(height: 10),
          _ChoiceChips(
            what: 'size',
            label: 'Sizes',
            options: widget.sizeOptions,
            chosen: grid.sizes,
            isChosen: grid.isSizeChosen,
            onToggle: grid.toggleSize,
            maxLength: widget.limits.size,
          ),
          const SizedBox(height: 14),
          if (!grid.hasVariants)
            _PriceStockRow(
              row: grid.single,
              maxQuantity: widget.maxQuantity,
              priceKey: 'marketplace-price',
              stockKey: 'marketplace-stock',
            )
          else ...[
            _sameForAll(),
            FormField<void>(
              key: ValueKey(
                'marketplace-variant-rows-${grid.combinations.length}',
              ),
              validator: (_) => grid.combinations.isEmpty
                  ? 'Keep at least one colour / size.'
                  : null,
              builder: (field) => Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (final (i, c) in grid.combinations.indexed)
                    _combinationCard(i, c),
                  if (field.errorText case final error?)
                    Text(
                      error,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.error,
                      ),
                    ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  /// One price and stock typed once and copied into every row.
  Widget _sameForAll() => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Expanded(
        child: TextField(
          key: const ValueKey('marketplace-same-price'),
          controller: _samePrice,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          inputFormatters: [
            FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
          ],
          decoration: const InputDecoration(
            labelText: 'Same price',
            prefixText: '₹ ',
            isDense: true,
            border: OutlineInputBorder(),
          ),
        ),
      ),
      const SizedBox(width: 8),
      Expanded(
        child: TextField(
          key: const ValueKey('marketplace-same-stock'),
          controller: _sameStock,
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          decoration: const InputDecoration(
            labelText: 'Same stock',
            isDense: true,
            border: OutlineInputBorder(),
          ),
        ),
      ),
      TextButton(
        key: const ValueKey('marketplace-apply-all'),
        onPressed: () => widget.grid.applyToAll(
          price: _samePrice.text,
          stock: _sameStock.text,
        ),
        child: const Text('Fill all'),
      ),
    ],
  );

  Widget _combinationCard(int i, MarketplaceCombination c) {
    final theme = Theme.of(context);
    return Card(
      key: ValueKey('marketplace-variant-${c.colour}-${c.size}'),
      margin: const EdgeInsets.only(top: 10),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 4, 4, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    [?c.colour, ?c.size].join(' · '),
                    style: theme.textTheme.titleSmall,
                  ),
                ),
                IconButton(
                  key: ValueKey('marketplace-variant-remove-$i'),
                  tooltip: 'Not sold',
                  icon: const Icon(Icons.close),
                  onPressed: () => widget.grid.leaveOut(c),
                ),
              ],
            ),
            _PriceStockRow(
              row: widget.grid.rowFor(c),
              maxQuantity: widget.maxQuantity,
              priceKey: 'marketplace-variant-price-$i',
              stockKey: 'marketplace-variant-stock-$i',
            ),
          ],
        ),
      ),
    );
  }
}

/// A price and its stock, side by side; both required.
class _PriceStockRow extends StatelessWidget {
  const _PriceStockRow({
    required this.row,
    required this.maxQuantity,
    required this.priceKey,
    required this.stockKey,
  });

  final MarketplacePriceStock row;
  final int maxQuantity;
  final String priceKey;
  final String stockKey;

  @override
  Widget build(BuildContext context) => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Expanded(
        child: TextFormField(
          key: ValueKey(priceKey),
          controller: row.price,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          inputFormatters: [
            FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
          ],
          decoration: const InputDecoration(
            labelText: 'Price',
            prefixText: '₹ ',
            border: OutlineInputBorder(),
          ),
          validator: (v) {
            final n = double.tryParse((v ?? '').trim());
            return n == null || n <= 0 ? 'Enter a valid price.' : null;
          },
        ),
      ),
      const SizedBox(width: 8),
      Expanded(
        child: TextFormField(
          key: ValueKey(stockKey),
          controller: row.stock,
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          decoration: const InputDecoration(
            labelText: 'Stock',
            border: OutlineInputBorder(),
          ),
          validator: (v) {
            final n = int.tryParse((v ?? '').trim());
            if (n == null) return 'Required.';
            return n > maxQuantity ? 'At most $maxQuantity.' : null;
          },
        ),
      ),
    ],
  );
}

/// The colours (or sizes) to tap — the server's list, then any the business typed itself — and a
/// box to add one more.
class _ChoiceChips extends StatefulWidget {
  const _ChoiceChips({
    required this.what,
    required this.label,
    required this.options,
    required this.chosen,
    required this.isChosen,
    required this.onToggle,
    required this.maxLength,
  });

  final String what;
  final String label;
  final List<String> options;
  final List<String> chosen;
  final bool Function(String) isChosen;
  final ValueChanged<String> onToggle;
  final int maxLength;

  @override
  State<_ChoiceChips> createState() => _ChoiceChipsState();
}

class _ChoiceChipsState extends State<_ChoiceChips> {
  final _own = TextEditingController();

  @override
  void dispose() {
    _own.dispose();
    super.dispose();
  }

  void _addOwn() {
    final value = _own.text.trim();
    if (value.isEmpty) return;
    if (!widget.isChosen(value)) widget.onToggle(value);
    _own.clear();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final offered = {for (final o in widget.options) o.toLowerCase()};
    final all = [
      ...widget.options,
      for (final c in widget.chosen)
        if (!offered.contains(c.toLowerCase())) c,
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(widget.label, style: theme.textTheme.labelLarge),
        const SizedBox(height: 4),
        Wrap(
          spacing: 6,
          runSpacing: 2,
          children: [
            for (final o in all)
              FilterChip(
                key: ValueKey('marketplace-${widget.what}-$o'),
                label: Text(o),
                selected: widget.isChosen(o),
                onSelected: (_) => widget.onToggle(o),
              ),
          ],
        ),
        TextField(
          key: ValueKey('marketplace-${widget.what}-own'),
          controller: _own,
          maxLength: widget.maxLength,
          textInputAction: TextInputAction.done,
          onSubmitted: (_) => _addOwn(),
          decoration: InputDecoration(
            hintText: 'Another ${widget.what}',
            isDense: true,
            counterText: '',
            suffixIcon: IconButton(
              key: ValueKey('marketplace-${widget.what}-add'),
              tooltip: 'Add',
              icon: const Icon(Icons.add),
              onPressed: _addOwn,
            ),
          ),
        ),
      ],
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
    super.key,
  });

  final MarketplaceCustomDetailRows rows;

  /// How long a detail's name and value may be.
  final MarketplaceTextLimits limits;

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
            'Anything the list above does not ask, e.g. Leather type: Genuine.',
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
                      key: ValueKey('marketplace-detail-name-$i'),
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
                      key: ValueKey('marketplace-detail-value-$i'),
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
                    key: ValueKey('marketplace-detail-remove-$i'),
                    tooltip: 'Remove',
                    icon: const Icon(Icons.close),
                    onPressed: () => rows._remove(row),
                  ),
                ],
              ),
            ),
          const SizedBox(height: 6),
          TextButton.icon(
            key: const ValueKey('marketplace-add-detail'),
            onPressed: rows.add,
            icon: const Icon(Icons.add),
            label: const Text('Add a detail'),
          ),
        ],
      ),
    );
  }
}
