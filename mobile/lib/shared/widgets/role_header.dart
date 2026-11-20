import 'package:flutter/material.dart';
import 'package:zuno/core/theme/app_colors.dart';
import 'package:zuno/core/theme/app_theme.dart';

/// The block of colour at the top of a role's dashboard.
///
/// A flat field of the role's deep colour — laterite for a business, turmeric for a worker,
/// backwater teal for a customer — with the name set large and the one or two figures worth
/// seeing before anything else. Sitting above the content rather than inside it means those
/// figures survive scrolling away and never compete with the list below for attention. The
/// role's brighter shade draws the line under it, so the block reads as the role's own.
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
    final (deep, bright) = AppColors.gradientFor(role);
    final muted = AppColors.onMediaMuted;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: deep,
        border: Border(bottom: BorderSide(color: bright, width: 4)),
      ),
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          20,
          MediaQuery.of(context).padding.top + 14,
          20,
          20,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        greeting,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: muted,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        name,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.headlineMedium?.copyWith(
                          color: AppColors.onMedia,
                        ),
                      ),
                      if (subtitle != null) ...[
                        const SizedBox(height: 2),
                        Text(
                          subtitle!,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: muted,
                          ),
                        ),
                      ],
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
                    if (i > 0) const SizedBox(width: 10),
                    Expanded(child: _StatCard(stat: stats[i])),
                  ],
                ],
              ),
            ],
          ],
        ),
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
    final muted = AppColors.onMediaMuted;
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      decoration: BoxDecoration(
        // Translucent white rather than a fixed colour, so one panel works on every role's block.
        color: AppColors.onMedia.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            stat.value,
            style: theme.textTheme.headlineSmall?.copyWith(
              color: AppColors.onMedia,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 2),
          Row(
            children: [
              if (stat.icon != null) ...[
                ExcludeSemantics(
                  child: Icon(stat.icon, size: 14, color: muted),
                ),
                const SizedBox(width: 5),
              ],
              Flexible(
                child: Text(
                  stat.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.labelSmall?.copyWith(color: muted),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
