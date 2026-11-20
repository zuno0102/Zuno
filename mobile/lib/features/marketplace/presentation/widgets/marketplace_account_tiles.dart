import 'package:flutter/material.dart';
import 'package:zuno/shared/legal/help_screen.dart';
import 'package:zuno/core/router/push_screen.dart';
import 'package:zuno/features/marketplace/presentation/screens/marketplace_wishlist_screen.dart';
import 'package:zuno/shared/widgets/empty_state.dart';

/// The Marketplace account's shortcuts, two by two: Orders, Wishlist, Coupons, Help Center.
class MarketplaceAccountTiles extends StatelessWidget {
  const MarketplaceAccountTiles({required this.onOrders, super.key});

  /// Orders lives in its own tab; the shell switches to it.
  final VoidCallback onOrders;

  @override
  Widget build(BuildContext context) {
    final tiles = [
      (Icons.inventory_2_outlined, 'Orders', onOrders),
      (
        Icons.favorite_border_rounded,
        'Wishlist',
        () => pushScreen(context, const MarketplaceWishlistScreen()),
      ),
      (
        Icons.redeem_outlined,
        'Coupons',
        () => pushScreen(context, const MarketplaceCouponsScreen()),
      ),
      (
        Icons.headset_mic_outlined,
        'Help Center',
        () => pushScreen(context, const HelpScreen()),
      ),
    ];

    return Padding(
      key: const ValueKey('marketplace-account-tiles'),
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      child: GridView.count(
        crossAxisCount: 2,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        mainAxisSpacing: 12,
        crossAxisSpacing: 12,
        childAspectRatio: 3.2,
        children: [
          for (final (icon, label, onTap) in tiles)
            _Tile(icon: icon, label: label, onTap: onTap),
        ],
      ),
    );
  }
}

class _Tile extends StatelessWidget {
  const _Tile({required this.icon, required this.label, required this.onTap});

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final shape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(8),
      side: BorderSide(color: theme.colorScheme.outlineVariant),
    );
    return Material(
      key: ValueKey('marketplace-tile-$label'),
      shape: shape,
      color: theme.colorScheme.surface,
      child: InkWell(
        customBorder: shape,
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14),
          child: Row(
            children: [
              Icon(icon, color: theme.colorScheme.primary),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Coupons are not offered yet: who makes them and how they change an order's price comes later.
class MarketplaceCouponsScreen extends StatelessWidget {
  const MarketplaceCouponsScreen({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Coupons')),
    body: const EmptyState(
      icon: Icons.redeem_outlined,
      title: 'No coupons yet',
      message: 'Offers from Zuno and sellers will show here.',
    ),
  );
}
