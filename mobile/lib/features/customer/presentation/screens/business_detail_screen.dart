import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:zuno/core/theme/app_colors.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:zuno/core/utils/formatting.dart';
import 'package:zuno/core/constants/api_constants.dart';
import 'package:zuno/features/customer/domain/entities/business_detail.dart';
import 'package:zuno/features/customer/domain/entities/customer_service.dart';
import 'package:zuno/features/customer/domain/entities/service_variant.dart';
import 'package:zuno/features/customer/presentation/providers/customer_providers.dart';
import 'package:zuno/features/customer/presentation/screens/create_booking_screen.dart';
import 'package:zuno/shared/widgets/error_banner.dart';
import 'package:zuno/core/router/push_screen.dart';

class BusinessDetailScreen extends ConsumerWidget {
  const BusinessDetailScreen({required this.businessId, super.key});

  final String businessId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final detailAsync = ref.watch(businessDetailProvider(businessId));

    return Scaffold(
      appBar: AppBar(title: const Text('Business Details')),
      body: detailAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: ErrorBanner(message: error.toString()),
          ),
        ),
        data: (business) => _BusinessDetailBody(business: business),
      ),
    );
  }
}

class _BusinessDetailBody extends StatelessWidget {
  const _BusinessDetailBody({required this.business});

  final BusinessDetail business;

  @override
  Widget build(BuildContext context) {
    final addressParts = [
      business.addressLine1,
      business.city,
      business.state,
      business.country,
    ].where((part) => part != null && part.isNotEmpty).join(', ');

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CircleAvatar(
              radius: 32,
              backgroundColor: Theme.of(context).colorScheme.primaryContainer,
              backgroundImage: business.logoUrl != null
                  ? NetworkImage(business.logoUrl!)
                  : null,
              child: business.logoUrl == null
                  ? Text(
                      business.businessName.isNotEmpty
                          ? business.businessName[0].toUpperCase()
                          : '?',
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onPrimaryContainer,
                        fontSize: 22,
                      ),
                    )
                  : null,
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    business.businessName,
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  if (addressParts.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      addressParts,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
        if (business.description != null &&
            business.description!.isNotEmpty) ...[
          const SizedBox(height: 16),
          Text(business.description!),
        ],
        const SizedBox(height: 24),
        Text('Services', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 12),
        if (business.services.isEmpty)
          const Text('This business has not listed any services yet.')
        else
          ...business.services.map(
            (service) => _ServiceTile(
              businessName: business.businessName,
              service: service,
            ),
          ),
      ],
    );
  }
}

class _ServiceTile extends StatelessWidget {
  const _ServiceTile({required this.businessName, required this.service});

  final String businessName;
  final CustomerService service;

  Future<void> _open(BuildContext context) async {
    if (service.variants.isEmpty) {
      pushScreen(
        context,
        CreateBookingScreen(businessName: businessName, service: service),
      );
      return;
    }

    final selected = await showModalBottomSheet<ServiceVariant>(
      context: context,
      isScrollControlled: true,
      builder: (context) => _VariantPickerSheet(service: service),
    );

    if (selected != null && context.mounted) {
      pushScreen(
        context,
        CreateBookingScreen(
          businessName: businessName,
          service: service,
          variant: selected,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final lowestVariantPrice = service.lowestVariantPrice;
    final label = lowestVariantPrice != null
        ? 'From ${rupees(lowestVariantPrice)}'
        : priceLabel(service.price, service.priceType);
    final thumbnailUrl = service.imageUrlForSlot(0);

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: ListTile(
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
        subtitle: Text(service.serviceCategoryName),
        trailing: Text(
          label,
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        onTap: () => _open(context),
      ),
    );
  }
}

class _VariantPickerSheet extends StatelessWidget {
  const _VariantPickerSheet({required this.service});

  final CustomerService service;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
            child: Text(
              'Choose an option',
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
            ),
          ),
          Flexible(
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: service.variants.length,
              itemBuilder: (context, index) {
                final variant = service.variants[index];
                final variantLabel = priceLabel(
                  variant.price,
                  variant.priceType,
                );

                return ListTile(
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
                            color: Theme.of(
                              context,
                            ).colorScheme.surfaceContainerHighest,
                            child: const Icon(Icons.design_services_outlined),
                          ),
                  ),
                  title: Text(
                    variant.name,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  subtitle: variant.description != null
                      ? Text(variant.description!)
                      : null,
                  trailing: Text(
                    variantLabel,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  onTap: () => Navigator.of(context).pop(variant),
                );
              },
            ),
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}
