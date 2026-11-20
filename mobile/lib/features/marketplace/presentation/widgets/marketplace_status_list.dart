import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:zuno/shared/widgets/error_banner.dart';
import 'package:zuno/shared/widgets/filter_chip_bar.dart';

/// Status chips over a list of cards, with pull to refresh, loading, error and empty states.
class MarketplaceStatusList<T> extends StatelessWidget {
  const MarketplaceStatusList({
    super.key,
    required this.chips,
    required this.items,
    required this.onRefresh,
    required this.onRetry,
    required this.empty,
    required this.itemBuilder,
  });

  final List<Widget> chips;
  final AsyncValue<List<T>> items;
  final Future<void> Function() onRefresh;
  final VoidCallback onRetry;
  final Widget empty;
  final Widget Function(T item) itemBuilder;

  @override
  Widget build(BuildContext context) => RefreshIndicator(
    onRefresh: onRefresh,
    child: ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.only(bottom: 32),
      children: [
        FilterChipBar(chips: chips),
        ...items.when(
          loading: () => const [
            Padding(
              padding: EdgeInsets.all(32),
              child: Center(child: CircularProgressIndicator()),
            ),
          ],
          error: (error, _) => [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  ErrorBanner(message: error.toString()),
                  TextButton.icon(
                    onPressed: onRetry,
                    icon: const Icon(Icons.refresh),
                    label: const Text('Try again'),
                  ),
                ],
              ),
            ),
          ],
          data: (list) => list.isEmpty
              ? [empty]
              : [
                  for (final item in list)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
                      child: itemBuilder(item),
                    ),
                ],
        ),
      ],
    ),
  );
}
