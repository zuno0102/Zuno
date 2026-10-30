import 'package:cached_network_image/cached_network_image.dart';
import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:zuno/core/theme/app_colors.dart';
import 'package:zuno/core/utils/formatting.dart';
import 'package:zuno/features/rental/data/rental_api.dart';
import 'package:zuno/features/rental/domain/entities/rental_item.dart';
import 'package:zuno/features/rental/presentation/providers/rental_providers.dart';
import 'package:zuno/features/rental/presentation/widgets/rental_item_form_sheet.dart';
import 'package:zuno/shared/widgets/app_messages.dart';
import 'package:zuno/shared/widgets/confirm_dialog.dart';
import 'package:zuno/shared/widgets/error_banner.dart';

/// "₹12/day · 200 in stock" — the rate and how many the business has. The "/day" is the rate
/// table's suffix for the item's type; until that list loads the price shows on its own.
String rentalRateAndStock(
  RentalItem item,
  List<RentalPriceTypeOption> priceTypes,
) => '${rentalRate(item, priceTypes)} · ${item.quantityOwned} in stock';

/// "₹12/day" — the rate with the rate table's suffix for the item's type.
String rentalRate(RentalItem item, List<RentalPriceTypeOption> priceTypes) {
  final suffix =
      priceTypes
          .firstWhereOrNull((o) => o.code == item.priceType)
          ?.unitSuffix ??
      '';
  return '${rupees(item.price)}$suffix';
}

/// The items a business rents out — a cutting machine, two hundred chairs — in the same cards as
/// its services.
///
/// With [isAvailable] set it shows only the items on (true) or switched off (false): what a Rent
/// tile on the home screen opens. That view lists, edits and removes, but adds from the Rent tab.
class BusinessRentalsTab extends ConsumerWidget {
  const BusinessRentalsTab({this.isAvailable, super.key});

  final bool? isAvailable;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final filter = isAvailable;
    final itemsAsync = filter == null
        ? ref.watch(businessRentalsProvider)
        : ref.watch(rentalItemsByAvailabilityProvider(filter));

    void reload() => filter == null
        ? ref.invalidate(businessRentalsProvider)
        : ref.invalidate(rentalItemsByAvailabilityProvider(filter));

    return Scaffold(
      floatingActionButton: filter != null
          ? null
          : FloatingActionButton.extended(
              onPressed: () => showRentalItemFormSheet(context),
              icon: const Icon(Icons.add),
              label: const Text('Add rent item'),
            ),
      body: itemsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ErrorBanner(message: error.toString()),
                const SizedBox(height: 12),
                TextButton.icon(
                  onPressed: reload,
                  icon: const Icon(Icons.refresh),
                  label: const Text('Try again'),
                ),
              ],
            ),
          ),
        ),
        data: (items) {
          if (items.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(switch (filter) {
                  null =>
                    'Nothing to rent yet. Tap "Add rent item" to list chairs, '
                        'tents, tools or anything else you rent out.',
                  true => 'No items are available to rent right now.',
                  false => 'Every item is available — none is switched off.',
                }, textAlign: TextAlign.center),
              ),
            );
          }

          return RefreshIndicator(
            onRefresh: () async {
              reloadRentals(ref);
              await (filter == null
                  ? ref.read(businessRentalsProvider.future)
                  : ref.read(rentalItemsByAvailabilityProvider(filter).future));
            },
            child: ListView.separated(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
              itemCount: items.length,
              separatorBuilder: (_, _) => const SizedBox(height: 10),
              itemBuilder: (context, index) => _RentalCard(item: items[index]),
            ),
          );
        },
      ),
    );
  }
}

class _RentalCard extends ConsumerWidget {
  const _RentalCard({required this.item});

  final RentalItem item;

  Future<void> _confirmDelete(BuildContext context, WidgetRef ref) async {
    final confirmed = await showConfirmDialog(
      context,
      title: 'Remove rent item?',
      message: '"${item.name}" will be taken off your Rent list.',
      confirmLabel: 'Remove',
    );
    if (!confirmed || !context.mounted) return;

    // Before the await, as the app's messages need: the screen's colours and its messenger.
    final messenger = AppMessenger.of(context);
    try {
      await ref.read(rentalRepositoryProvider).delete(item.id);
      reloadRentals(ref);
      messenger.showSuccess('${item.name} removed.');
    } catch (e) {
      messenger.showFailure(e.toString());
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final thumbnailUrl = item.imageUrlForSlot(0);
    final priceTypes =
        ref.watch(rentalPriceTypesProvider).value ??
        const <RentalPriceTypeOption>[];

    return Card(
      margin: EdgeInsets.zero,
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: Stack(
            children: [
              thumbnailUrl != null
                  ? CachedNetworkImage(
                      imageUrl: RentApi.mediaUrl(thumbnailUrl),
                      width: 48,
                      height: 48,
                      fit: BoxFit.cover,
                      errorWidget: (context, url, error) =>
                          const Icon(Icons.broken_image_outlined),
                    )
                  : Container(
                      width: 48,
                      height: 48,
                      color: Theme.of(
                        context,
                      ).colorScheme.surfaceContainerHighest,
                      child: const Icon(Icons.inventory_2_outlined),
                    ),
              if (item.video != null)
                Positioned(
                  right: 2,
                  bottom: 2,
                  child: Icon(
                    Icons.videocam,
                    size: 14,
                    color: AppColors.onMedia,
                    shadows: const [Shadow(blurRadius: 3)],
                  ),
                ),
            ],
          ),
        ),
        title: Text(
          item.name,
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Text(
              item.categoryLine,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 4),
            Wrap(
              spacing: 10,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Text(
                  rentalRateAndStock(item, priceTypes),
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                if (!item.isAvailable)
                  const Chip(
                    label: Text('Unavailable', style: TextStyle(fontSize: 11)),
                    visualDensity: VisualDensity.compact,
                    padding: EdgeInsets.zero,
                  ),
              ],
            ),
          ],
        ),
        isThreeLine: true,
        trailing: PopupMenuButton<String>(
          onSelected: (value) {
            if (value == 'edit') {
              showRentalItemFormSheet(context, existing: item);
            } else if (value == 'delete') {
              _confirmDelete(context, ref);
            }
          },
          itemBuilder: (context) => const [
            PopupMenuItem(value: 'edit', child: Text('Edit')),
            PopupMenuItem(value: 'delete', child: Text('Remove')),
          ],
        ),
      ),
    );
  }
}
