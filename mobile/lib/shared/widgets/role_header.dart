import 'package:flutter/material.dart';
import 'package:zuno/core/theme/app_colors.dart';

/// The gradient banner at the top of a role's dashboard.
///
/// Carries the role's colour, who is signed in, and the one or two figures worth seeing before
/// anything else. Sitting above the content rather than inside it means those figures survive
/// scrolling away and never compete with the list below for attention.
class RoleHeader extends StatelessWidget {
  const RoleHeader({
    required this.role,
    required this.greeting,
    required this.name,
    this.subtitle,
    this.stats = const [],
    this.actions = const [],
    super.key,
  });

  final ZunoRole role;

  /// "Good morning", "Welcome back" — the softer half of the line.
  final String greeting;
  final String name;
  final String? subtitle;
  final List<HeaderStat> stats;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final (from, to) = AppColors.gradientFor(role);

    return Container(
      padding: EdgeInsets.fromLTRB(
        20,
        MediaQuery.of(context).padding.top + 16,
        20,
        20,
      ),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [from, to],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(24)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      greeting,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: AppColors.onMedia.withValues(alpha: 0.78),
                      ),
                    ),
                    Text(
                      name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleLarge?.copyWith(
                        color: AppColors.onMedia,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    if (subtitle != null)
                      Text(
                        subtitle!,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: AppColors.onMedia.withValues(alpha: 0.78),
                        ),
                      ),
                  ],
                ),
              ),
              ...actions,
            ],
          ),
          if (stats.isNotEmpty) ...[
            const SizedBox(height: 18),
            Row(
              children: [
                for (var i = 0; i < stats.length; i++) ...[
                  if (i > 0) const SizedBox(width: 12),
                  Expanded(child: _StatCard(stat: stats[i])),
                ],
              ],
            ),
          ],
        ],
      ),
    );
  }
}

/// One figure on the header — a count, a total, a balance.
class HeaderStat {
  const HeaderStat({required this.label, required this.value, this.icon});

  final String label;
  final String value;
  final IconData? icon;
}

class _StatCard extends StatelessWidget {
  const _StatCard({required this.stat});

  final HeaderStat stat;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        // Translucent white rather than a fixed colour, so one card works on every gradient.
        color: AppColors.onMedia.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.onMedia.withValues(alpha: 0.22)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (stat.icon != null) ...[
                Icon(
                  stat.icon,
                  size: 14,
                  color: AppColors.onMedia.withValues(alpha: 0.85),
                ),
                const SizedBox(width: 5),
              ],
              Flexible(
                child: Text(
                  stat.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: AppColors.onMedia.withValues(alpha: 0.85),
                    fontSize: 11.5,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            stat.value,
            style: theme.textTheme.headlineSmall?.copyWith(
              color: AppColors.onMedia,
              fontWeight: FontWeight.w700,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        ],
      ),
    );
  }
}
