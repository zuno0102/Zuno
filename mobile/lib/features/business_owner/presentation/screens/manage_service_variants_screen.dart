import 'package:cached_network_image/cached_network_image.dart';
import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:zuno/core/utils/formatting.dart';
import 'package:zuno/core/constants/api_constants.dart';
import 'package:zuno/features/business_owner/domain/entities/service_variant.dart';
import 'package:zuno/features/business_owner/presentation/providers/business_services_notifier.dart';
import 'package:zuno/features/business_owner/presentation/widgets/service_variant_form_sheet.dart';
import 'package:zuno/shared/widgets/error_banner.dart';
import 'package:zuno/shared/widgets/confirm_dialog.dart';

/// Lists the sub-items ("variants") under one service — e.g. Band / Chenda Melam / Panjabi
/// Band under a "Band Set" service — with add/edit/delete, mirroring BusinessServicesTab's
/// own list+FAB layout one level down. Variants are embedded on the parent BusinessService
/// (from businessServicesProvider), so this screen just finds that one service by id rather
/// than fetching its own separate list.
class ManageServiceVariantsScreen extends ConsumerWidget {
  const ManageServiceVariantsScreen({required this.serviceId, super.key});

  final String serviceId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final servicesAsync = ref.watch(businessServicesProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Manage items')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () =>
            showServiceVariantFormSheet(context, serviceId: serviceId),
        icon: const Icon(Icons.add),
        label: const Text('Add item'),
      ),
      body: servicesAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: ErrorBanner(message: error.toString()),
          ),
        ),
        data: (services) {
          final service = services.where((s) => s.id == serviceId).firstOrNull;
          final variants = service?.variants ?? const [];

          if (variants.isEmpty) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text(
                  'No items yet. Tap "Add item" to list the first one (e.g. a specific theme or band type).',
                ),
              ),
            );
          }

          return RefreshIndicator(
            onRefresh: () => ref.refresh(businessServicesProvider.future),
            child: ListView.separated(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
              itemCount: variants.length,
              separatorBuilder: (_, _) => const SizedBox(height: 10),
              itemBuilder: (context, index) =>
                  _VariantCard(serviceId: serviceId, variant: variants[index]),
            ),
          );
        },
      ),
    );
  }
}

class _VariantCard extends ConsumerWidget {
  const _VariantCard({required this.serviceId, required this.variant});

  final String serviceId;
  final ServiceVariant variant;

  Future<void> _confirmDelete(BuildContext context, WidgetRef ref) async {
    final confirmed = await showConfirmDialog(
      context,
      title: 'Remove item?',
      message: '"${variant.name}" will no longer be visible to customers.',
      confirmLabel: 'Remove',
    );

    if (confirmed) {
      await ref
          .read(businessServicesProvider.notifier)
          .deleteServiceVariant(serviceId, variant.id);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final label = priceLabel(variant.price, variant.priceType);

    return Card(
      margin: EdgeInsets.zero,
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: variant.imageUrlForSlot(0) != null
              ? CachedNetworkImage(
                  imageUrl:
                      '${ApiConstants.baseUrl}${variant.imageUrlForSlot(0)}',
                  width: 48,
                  height: 48,
                  fit: BoxFit.cover,
                  errorWidget: (context, url, error) =>
                      const Icon(Icons.broken_image_outlined),
                )
              : Container(
                  width: 48,
                  height: 48,
                  color: Theme.of(context).colorScheme.surfaceContainerHighest,
                  child: const Icon(Icons.design_services_outlined),
                ),
        ),
        title: Text(
          variant.name,
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (variant.serviceSubCategoryName case final subCategory?)
              Text(
                subCategory,
                style: TextStyle(
                  fontSize: 11.5,
                  color: Theme.of(context).colorScheme.primary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            Row(
              children: [
                Text(
                  label,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                const SizedBox(width: 10),
                if (!variant.isActive)
                  const Chip(
                    label: Text('Inactive', style: TextStyle(fontSize: 11)),
                    visualDensity: VisualDensity.compact,
                    padding: EdgeInsets.zero,
                  ),
              ],
            ),
          ],
        ),
        trailing: PopupMenuButton<String>(
          onSelected: (value) {
            if (value == 'edit') {
              showServiceVariantFormSheet(
                context,
                serviceId: serviceId,
                existing: variant,
              );
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
