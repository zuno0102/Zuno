import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:zuno/features/marketplace/presentation/providers/marketplace_customer_providers.dart';
import 'package:zuno/features/marketplace/presentation/widgets/marketplace_post_card.dart';
import 'package:zuno/shared/widgets/empty_state.dart';
import 'package:zuno/shared/widgets/error_banner.dart';

/// What the customer saved with the heart, newest first. Kept on the server, so it follows them to
/// another phone. A post no longer on sale stays, greyed "Not available", until they take it off.
class MarketplaceWishlistScreen extends ConsumerWidget {
  const MarketplaceWishlistScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final saved = ref.watch(marketplaceFavouritesProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Wishlist')),
      body: RefreshIndicator(
        onRefresh: () => ref.refresh(marketplaceFavouritesProvider.future),
        child: saved.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, _) => ListView(
            padding: const EdgeInsets.all(16),
            children: [ErrorBanner(message: error.toString())],
          ),
          data: (page) => page.items.isEmpty
              ? ListView(
                  children: const [
                    EmptyState(
                      icon: Icons.favorite_border_rounded,
                      title: 'Nothing saved yet',
                      message:
                          'Tap the heart on anything in Marketplace to keep it here.',
                    ),
                  ],
                )
              : GridView.builder(
                  key: const ValueKey('marketplace-wishlist'),
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.all(16),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    mainAxisSpacing: 12,
                    crossAxisSpacing: 12,
                    childAspectRatio: 0.72,
                  ),
                  itemCount: page.items.length,
                  itemBuilder: (_, i) =>
                      MarketplacePostCard(card: page.items[i]),
                ),
        ),
      ),
    );
  }
}
