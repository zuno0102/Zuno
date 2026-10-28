import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:zuno/features/business_owner/domain/entities/business_service.dart';
import 'package:zuno/features/business_owner/presentation/providers/business_services_notifier.dart';
import 'package:zuno/shared/widgets/error_banner.dart';

/// Titles a hiring post by picking one of the business's own services, rather than free
/// text. Selecting one also carries that service's description into the form.
///
/// A post edited before this existed may carry a title that matches no current service
/// (or the service may since have been renamed or removed); that title is offered as an
/// extra option so editing such a post does not silently blank its title.
class HiringPostServiceTitlePicker extends ConsumerWidget {
  const HiringPostServiceTitlePicker({
    required this.selectedTitle,
    required this.onSelected,
    super.key,
  });

  final String? selectedTitle;

  /// Passes the whole service, not just its name: the post takes its description from it and
  /// filters the kinds of work on offer by its category.
  final void Function(String title, BusinessService? service) onSelected;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final servicesAsync = ref.watch(businessServicesProvider);

    return servicesAsync.when(
      loading: () => const InputDecorator(
        decoration: InputDecoration(
          labelText: 'Service',
          border: OutlineInputBorder(),
        ),
        child: Row(
          children: [
            SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
            SizedBox(width: 10),
            Text('Loading your services…'),
          ],
        ),
      ),
      error: (error, _) => ErrorBanner(message: error.toString()),
      data: (services) {
        if (services.isEmpty && selectedTitle == null) {
          return const _NoServicesNotice();
        }

        final byName = <String, BusinessService>{
          for (final service in services) service.name: service,
        };

        // Keep an unrecognised existing title selectable so editing never drops it.
        final titles = <String>[
          if (selectedTitle != null && !byName.containsKey(selectedTitle))
            selectedTitle!,
          ...byName.keys,
        ];

        return DropdownButtonFormField<String>(
          initialValue: selectedTitle,
          isExpanded: true,
          decoration: const InputDecoration(
            labelText: 'Service',
            helperText: 'Picks the title and fills in the description',
            border: OutlineInputBorder(),
          ),
          items: titles
              .map(
                (title) => DropdownMenuItem(
                  value: title,
                  child: Text(title, overflow: TextOverflow.ellipsis),
                ),
              )
              .toList(),
          onChanged: (title) {
            if (title == null) return;
            onSelected(title, byName[title]);
          },
          validator: (value) => (value == null || value.trim().isEmpty)
              ? 'Choose the service you are hiring for.'
              : null,
        );
      },
    );
  }
}

/// A business with no services yet cannot title a hiring post, so say so plainly
/// instead of presenting an empty dropdown.
class _NoServicesNotice extends StatelessWidget {
  const _NoServicesNotice();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.colorScheme.errorContainer.withValues(alpha: 0.35),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.info_outline, size: 18, color: theme.colorScheme.error),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Add a service under the Services tab first — a hiring post is titled '
              'by the service you need workers for.',
              style: theme.textTheme.bodySmall,
            ),
          ),
        ],
      ),
    );
  }
}
