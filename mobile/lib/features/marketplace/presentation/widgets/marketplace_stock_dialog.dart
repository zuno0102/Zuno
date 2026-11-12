import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Asks how many of a new item are left — the post menu's "Update stock" — and returns the count,
/// or null when cancelled. 0 is allowed: the item shows Out of stock until it is restocked.
///
/// Laid out like [showConfirmDialog]: Cancel on the left, Save on the right; − and + step the count
/// for the usual "sold one" or "two came in".
Future<int?> showMarketplaceStockDialog(
  BuildContext context, {
  required String title,
  required int current,
  required int max,
}) => showDialog<int>(
  context: context,
  builder: (_) => _StockDialog(title: title, current: current, max: max),
);

class _StockDialog extends StatefulWidget {
  const _StockDialog({
    required this.title,
    required this.current,
    required this.max,
  });

  final String title;
  final int current;
  final int max;

  @override
  State<_StockDialog> createState() => _StockDialogState();
}

class _StockDialogState extends State<_StockDialog> {
  late final _count = TextEditingController(text: '${widget.current}');
  final _formKey = GlobalKey<FormState>();

  @override
  void dispose() {
    _count.dispose();
    super.dispose();
  }

  int get _value => int.tryParse(_count.text.trim()) ?? 0;

  void _step(int by) {
    final next = (_value + by).clamp(0, widget.max);
    setState(() => _count.text = '$next');
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(widget.title),
    content: Form(
      key: _formKey,
      child: TextFormField(
        key: const ValueKey('marketplace-stock-count'),
        controller: _count,
        autofocus: true,
        keyboardType: TextInputType.number,
        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
        textAlign: TextAlign.center,
        decoration: InputDecoration(
          labelText: 'Stock available',
          helperText: '0 shows it as out of stock',
          border: const OutlineInputBorder(),
          prefixIcon: IconButton(
            key: const ValueKey('marketplace-stock-less'),
            tooltip: 'One less',
            icon: const Icon(Icons.remove),
            onPressed: () => _step(-1),
          ),
          suffixIcon: IconButton(
            key: const ValueKey('marketplace-stock-more'),
            tooltip: 'One more',
            icon: const Icon(Icons.add),
            onPressed: () => _step(1),
          ),
        ),
        validator: (v) {
          final parsed = int.tryParse((v ?? '').trim());
          if (parsed == null) return 'Enter a number.';
          return parsed > widget.max ? 'At most ${widget.max}.' : null;
        },
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Cancel'),
      ),
      FilledButton(
        key: const ValueKey('marketplace-stock-save'),
        onPressed: () {
          if (_formKey.currentState!.validate()) {
            Navigator.pop(context, _value);
          }
        },
        child: const Text('Save'),
      ),
    ],
  );
}
