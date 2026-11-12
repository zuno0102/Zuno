import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:zuno/features/marketplace/domain/entities/marketplace_post.dart';

/// One colour / size row being edited.
class _VariantRow {
  _VariantRow([MarketplaceVariant? from])
    : id = from?.id,
      colour = TextEditingController(text: from?.colour),
      size = TextEditingController(text: from?.size),
      price = TextEditingController(text: _plain(from?.price)),
      stock = TextEditingController(text: from == null ? '' : '${from.stock}');

  final String? id;
  final TextEditingController colour;
  final TextEditingController size;
  final TextEditingController price;
  final TextEditingController stock;

  /// A key that stays with the row while others are removed around it.
  final key = UniqueKey();

  static String _plain(double? v) => v == null
      ? ''
      : v == v.roundToDouble()
      ? '${v.toInt()}'
      : '$v';

  static String? _clean(TextEditingController c) =>
      c.text.trim().isEmpty ? null : c.text.trim();

  MarketplaceVariant toVariant() => MarketplaceVariant(
    id: id,
    colour: _clean(colour),
    size: _clean(size),
    price: double.tryParse(price.text.trim()),
    stock: int.tryParse(stock.text.trim()) ?? 0,
  );

  void dispose() {
    for (final c in [colour, size, price, stock]) {
      c.dispose();
    }
  }
}

/// The colours and sizes of a new product while the form is open — each with its own stock.
class MarketplaceVariantRows extends ChangeNotifier {
  MarketplaceVariantRows(List<MarketplaceVariant> saved)
    : _rows = [for (final v in saved) _VariantRow(v)];

  final List<_VariantRow> _rows;

  bool get isEmpty => _rows.isEmpty;

  List<MarketplaceVariant> get values => [for (final r in _rows) r.toVariant()];

  void add() {
    _rows.add(_VariantRow());
    notifyListeners();
  }

  void _remove(_VariantRow row) {
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

/// "Colours and sizes": a row per combination — colour, size, stock, and a price only when it
/// differs — like a shopping site's product page. Without any, the form asks one stock count.
class MarketplaceVariantsSection extends StatelessWidget {
  const MarketplaceVariantsSection({
    required this.rows,
    required this.maxQuantity,
    super.key,
  });

  final MarketplaceVariantRows rows;
  final int maxQuantity;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ListenableBuilder(
      listenable: rows,
      builder: (context, _) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Colours and sizes',
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          Text(
            rows.isEmpty
                ? 'Optional. Add one for each colour or size you sell, each with its own stock.'
                : 'Each one has its own stock. Leave the price empty to sell at the price above.',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          for (final (i, row) in rows._rows.indexed)
            Padding(
              key: row.key,
              padding: const EdgeInsets.only(top: 10),
              child: _VariantEditor(
                index: i,
                row: row,
                maxQuantity: maxQuantity,
                onRemove: () => rows._remove(row),
              ),
            ),
          const SizedBox(height: 6),
          TextButton.icon(
            key: const ValueKey('marketplace-add-variant'),
            onPressed: rows.add,
            icon: const Icon(Icons.add),
            label: const Text('Add colour / size'),
          ),
        ],
      ),
    );
  }
}

class _VariantEditor extends StatelessWidget {
  const _VariantEditor({
    required this.index,
    required this.row,
    required this.maxQuantity,
    required this.onRemove,
  });

  final int index;
  final _VariantRow row;
  final int maxQuantity;
  final VoidCallback onRemove;

  InputDecoration _box(String label) => InputDecoration(
    labelText: label,
    isDense: true,
    border: const OutlineInputBorder(),
  );

  @override
  Widget build(BuildContext context) => Card(
    margin: EdgeInsets.zero,
    child: Padding(
      padding: const EdgeInsets.fromLTRB(12, 12, 4, 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: TextFormField(
                        key: ValueKey('marketplace-variant-colour-$index'),
                        controller: row.colour,
                        maxLength: 40,
                        decoration: _box('Colour').copyWith(counterText: ''),
                        validator: (_) =>
                            row.colour.text.trim().isEmpty &&
                                row.size.text.trim().isEmpty
                            ? 'Colour or size.'
                            : null,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextFormField(
                        key: ValueKey('marketplace-variant-size-$index'),
                        controller: row.size,
                        maxLength: 20,
                        decoration: _box('Size').copyWith(counterText: ''),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: TextFormField(
                        key: ValueKey('marketplace-variant-stock-$index'),
                        controller: row.stock,
                        keyboardType: TextInputType.number,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                        ],
                        decoration: _box('Stock'),
                        validator: (v) {
                          final n = int.tryParse((v ?? '').trim());
                          if (n == null) return 'Required.';
                          return n > maxQuantity
                              ? 'At most $maxQuantity.'
                              : null;
                        },
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextFormField(
                        key: ValueKey('marketplace-variant-price-$index'),
                        controller: row.price,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        decoration: _box(
                          'Own price (optional)',
                        ).copyWith(prefixText: '₹ '),
                        validator: (v) {
                          final text = (v ?? '').trim();
                          if (text.isEmpty) return null;
                          final n = double.tryParse(text);
                          return n == null || n <= 0
                              ? 'Enter a valid price.'
                              : null;
                        },
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          IconButton(
            key: ValueKey('marketplace-variant-remove-$index'),
            tooltip: 'Remove',
            icon: const Icon(Icons.close),
            onPressed: onRemove,
          ),
        ],
      ),
    ),
  );
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
  const MarketplaceCustomDetailsSection({required this.rows, super.key});

  final MarketplaceCustomDetailRows rows;

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
                      maxLength: 40,
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
                      maxLength: 200,
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
