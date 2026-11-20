import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:zuno/core/error/app_exceptions.dart';
import 'package:zuno/core/router/push_screen.dart';
import 'package:zuno/core/utils/formatting.dart';
import 'package:zuno/features/business_plan/domain/business_plan.dart';
import 'package:zuno/features/business_plan/presentation/business_plan_providers.dart';
import 'package:zuno/features/business_plan/presentation/business_plans_screen.dart';
import 'package:zuno/shared/widgets/primary_button.dart';
import 'package:zuno/shared/widgets/sheet_drag_handle.dart';

/// Opens the add form [open] when the business's plan allows one more live listing in [area]; else
/// the lock sheet. When the plan cannot be read just now, the form opens and the server decides.
Future<void> openIfPlanAllows(
  BuildContext context,
  WidgetRef ref,
  ListingArea area,
  VoidCallback open,
) async {
  BusinessPlan? plan;
  try {
    plan = await ref.read(businessPlanProvider.future);
  } catch (_) {
    plan = null;
  }
  if (!context.mounted) return;
  final usage = plan?.usage(area);
  if (plan != null && usage != null && !usage.canAdd) {
    await showPlanLockSheet(context, area, reason: usage.reason, plan: plan);
    return;
  }
  open();
}

/// When [error] is the server refusing a listing for the plan, shows the lock sheet and says so.
bool showLockIfPlanLimit(BuildContext context, Object error, ListingArea area) {
  if (error is! PlanLimitAppException) return false;
  showPlanLockSheet(context, area, reason: error.message);
  return true;
}

/// Why [area] is locked, the cheapest plan that opens it, and the way to the plans.
Future<void> showPlanLockSheet(
  BuildContext context,
  ListingArea area, {
  String? reason,
  BusinessPlan? plan,
}) => pushSheet<void>(
  context,
  _PlanLockSheet(area: area, reason: reason, plan: plan),
);

class _PlanLockSheet extends StatelessWidget {
  const _PlanLockSheet({required this.area, this.reason, this.plan});

  final ListingArea area;
  final String? reason;
  final BusinessPlan? plan;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cheapest = plan?.cheapestFor(area);
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
        child: Column(
          key: const ValueKey('plan-lock-sheet'),
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SheetDragHandle(onDismiss: () => Navigator.of(context).maybePop()),
            Row(
              children: [
                Icon(Icons.lock_rounded, color: theme.colorScheme.primary),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '${area.label} is locked',
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              reason ??
                  'The Basic plan allows 1 live listing in total. Get a plan with ${area.label} to add more.',
              style: theme.textTheme.bodyMedium,
            ),
            if (cheapest != null) ...[
              const SizedBox(height: 14),
              Card(
                margin: EdgeInsets.zero,
                child: ListTile(
                  title: Text(
                    cheapest.name,
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  subtitle: Text(
                    'Unlimited ${area.label.toLowerCase()} listings',
                  ),
                  trailing: Text(
                    '${rupees(cheapest.price)}/mo',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ),
            ],
            const SizedBox(height: 16),
            PrimaryButton(
              key: const ValueKey('plan-lock-see-plans'),
              label: 'See plans',
              onPressed: () {
                Navigator.of(context).pop();
                pushScreen(context, const BusinessPlansScreen());
              },
            ),
            TextButton(
              onPressed: () => Navigator.of(context).maybePop(),
              child: const Text('Not now'),
            ),
          ],
        ),
      ),
    );
  }
}

/// "Basic · 1 of 1 used", "All 3 · till 20 Dec": the plan at a glance; opens the plans.
class BusinessPlanChip extends ConsumerWidget {
  const BusinessPlanChip({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final plan = ref.watch(businessPlanProvider).value;
    if (plan == null) return const SizedBox.shrink();
    final theme = Theme.of(context);
    final label = plan.isBasic
        ? '${plan.planName} · ${plan.totalLive ?? '–'} of ${plan.basicLimit} used'
        : '${plan.planName} · till ${formatDayMonth(plan.endsAt!)}';
    return ActionChip(
      key: const ValueKey('business-plan-chip'),
      avatar: Icon(
        plan.isBasic
            ? Icons.workspace_premium_outlined
            : Icons.workspace_premium,
        size: 18,
        color: theme.colorScheme.primary,
      ),
      label: Text(label),
      onPressed: () => pushScreen(context, const BusinessPlansScreen()),
    );
  }
}

/// The plan under the business profile on Home: name, use or end date, and the way to the plans.
class BusinessPlanCard extends ConsumerWidget {
  const BusinessPlanCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final plan = ref.watch(businessPlanProvider).value;
    final subtitle = plan == null
        ? 'See what you can list and the plans'
        : plan.isBasic
        ? '${plan.totalLive ?? '–'} of ${plan.basicLimit} free live listing${plan.basicLimit == 1 ? '' : 's'} used. Get a plan for more.'
        : 'Active till ${formatDate(plan.endsAt!)}';
    return Card(
      key: const ValueKey('business-plan-card'),
      margin: EdgeInsets.zero,
      child: ListTile(
        leading: const Icon(Icons.workspace_premium_outlined),
        title: Text(
          plan == null ? 'Your plan' : 'Plan · ${plan.planName}',
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
        subtitle: Text(subtitle),
        trailing: const Icon(Icons.chevron_right),
        onTap: () => pushScreen(context, const BusinessPlansScreen()),
      ),
    );
  }
}
