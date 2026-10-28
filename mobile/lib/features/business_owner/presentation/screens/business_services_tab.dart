import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:zuno/core/theme/app_colors.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:zuno/core/utils/formatting.dart';
import 'package:zuno/core/constants/api_constants.dart';
import 'package:zuno/features/business_owner/domain/entities/business_service.dart';
import 'package:zuno/features/business_owner/presentation/providers/business_services_notifier.dart';
import 'package:zuno/features/business_owner/presentation/screens/manage_service_variants_screen.dart';
import 'package:zuno/features/business_owner/presentation/widgets/business_service_form_sheet.dart';
import 'package:zuno/shared/widgets/error_banner.dart';
import 'package:zuno/core/router/push_screen.dart';
import 'package:zuno/shared/widgets/confirm_dialog.dart';

class BusinessServicesTab extends ConsumerWidget {
  const BusinessServicesTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final servicesAsync = ref.watch(businessServicesProvider);

    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => showBusinessServiceFormSheet(context),
        icon: const Icon(Icons.add),
        label: const Text('Add service'),
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
          if (services.isEmpty) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text(
                  'No services yet. Tap "Add service" to list your first offering.',
                ),
              ),
            );
          }

          return RefreshIndicator(
            onRefresh: () => ref.refresh(businessServicesProvider.future),
            child: ListView.separated(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
              itemCount: services.length,
              separatorBuilder: (_, _) => const SizedBox(height: 10),
              itemBuilder: (context, index) =>
                  _ServiceCard(service: services[index]),
            ),
          );
        },
      ),
    );
  }
}

class _ServiceCard extends ConsumerWidget {
  const _ServiceCard({required this.service});

  final BusinessService service;

  Future<void> _confirmDelete(BuildContext context, WidgetRef ref) async {
    final confirmed = await showConfirmDialog(
      context,
      title: 'Remove service?',
      message: '"${service.name}" will no longer be visible to customers.',
      confirmLabel: 'Remove',
    );

    if (confirmed) {
      await ref
          .read(businessServicesProvider.notifier)
          .deleteService(service.id);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final label = priceLabel(service.price, service.priceType);
    final thumbnailUrl = service.imageUrlForSlot(0);

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
                      imageUrl: '${ApiConstants.baseUrl}$thumbnailUrl',
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
                      child: const Icon(Icons.design_services_outlined),
                    ),
              if (service.video != null)
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
          service.name,
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Text(service.serviceCategoryName),
            const SizedBox(height: 4),
            Row(
              children: [
                Text(
                  label,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                const SizedBox(width: 10),
                if (!service.isActive)
                  const Chip(
                    label: Text('Inactive', style: TextStyle(fontSize: 11)),
                    visualDensity: VisualDensity.compact,
                    padding: EdgeInsets.zero,
                  ),
              ],
            ),
            if (service.variants.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(
                '${service.variants.length} item${service.variants.length == 1 ? '' : 's'} inside',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ],
        ),
        isThreeLine: true,
        trailing: PopupMenuButton<String>(
          onSelected: (value) {
            if (value == 'edit') {
              showBusinessServiceFormSheet(context, existing: service);
            } else if (value == 'variants') {
              pushScreen(
                context,
                ManageServiceVariantsScreen(serviceId: service.id),
              );
            } else if (value == 'delete') {
              _confirmDelete(context, ref);
            }
          },
          itemBuilder: (context) => const [
            PopupMenuItem(value: 'edit', child: Text('Edit')),
            PopupMenuItem(value: 'variants', child: Text('Manage variants')),
            PopupMenuItem(value: 'delete', child: Text('Remove')),
          ],
        ),
      ),
    );
  }
}
