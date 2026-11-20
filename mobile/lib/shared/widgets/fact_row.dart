import 'package:flutter/material.dart';
import 'package:zuno/core/constants/api_constants.dart';

/// One fact on an item's page — an icon, a small label and the value under it ("Delivers to ·
/// Kanyakumari"). Rent and Marketplace item pages list their facts with it.
class FactRow extends StatelessWidget {
  const FactRow({
    required this.icon,
    required this.label,
    required this.value,
    super.key,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: theme.colorScheme.primary),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                Text(value, style: theme.textTheme.bodyMedium),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Who offers an item — a verified business, as customers are only shown verified businesses'.
class VerifiedBusinessCard extends StatelessWidget {
  const VerifiedBusinessCard({required this.name, this.logoPath, super.key});

  final String name;

  /// A path on the Service server, where business profiles (and logos) live.
  final String? logoPath;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final logo = logoPath;
    final hasLogo = logo != null && logo.isNotEmpty;
    return Card(
      margin: EdgeInsets.zero,
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: theme.colorScheme.primaryContainer,
          backgroundImage: hasLogo
              ? NetworkImage('${ApiConstants.baseUrl}$logo')
              : null,
          child: hasLogo
              ? null
              : Icon(
                  Icons.storefront_outlined,
                  color: theme.colorScheme.onPrimaryContainer,
                ),
        ),
        title: Text(
          name.isEmpty ? 'Business' : name,
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
        subtitle: Row(
          children: [
            Icon(Icons.verified, size: 15, color: theme.colorScheme.primary),
            const SizedBox(width: 4),
            const Text('Verified business'),
          ],
        ),
      ),
    );
  }
}
