import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:zuno/core/theme/app_colors.dart';
import 'package:zuno/features/marketplace/data/marketplace_api.dart';
import 'package:zuno/features/marketplace/domain/entities/marketplace_post.dart';
import 'package:zuno/features/marketplace/presentation/providers/marketplace_providers.dart';
import 'package:zuno/features/marketplace/presentation/widgets/marketplace_post_form_sheet.dart';
import 'package:zuno/features/marketplace/presentation/widgets/marketplace_post_lines.dart';
import 'package:zuno/shared/widgets/app_messages.dart';
import 'package:zuno/shared/widgets/confirm_dialog.dart';
import 'package:zuno/shared/widgets/empty_state.dart';
import 'package:zuno/shared/widgets/error_banner.dart';
import 'package:zuno/shared/widgets/filter_chip_bar.dart';
import 'package:zuno/shared/widgets/media_list_card.dart';
import 'package:zuno/shared/widgets/status_pill.dart';

/// The status pill for [status], named and coloured from the server's status table.
StatusPill marketplaceStatusPill(MarketplaceOptions? options, String status) {
  final option = options?.status(status);
  return StatusPill(
    label: option?.name ?? status,
    tone: StatusTone.values.asNameMap()[option?.tone] ?? StatusTone.waiting,
    compact: true,
  );
}

/// What the business puts up on the Marketplace — listings, food offers and advertisements — with
/// its plan's room at the top and a filter by kind.
///
/// With [status] set it shows only the posts in that state: what a Marketplace tile on the home
/// screen opens. That view lists and changes posts, but adds from the Marketplace tab.
class BusinessMarketplaceTab extends ConsumerStatefulWidget {
  const BusinessMarketplaceTab({this.status, super.key});

  final String? status;

  @override
  ConsumerState<BusinessMarketplaceTab> createState() =>
      _BusinessMarketplaceTabState();
}

class _BusinessMarketplaceTabState
    extends ConsumerState<BusinessMarketplaceTab> {
  /// The kind chosen on the filter bar; null for all.
  String? _kind;

  @override
  Widget build(BuildContext context) {
    final status = widget.status;
    final postsAsync = ref.watch(
      businessMarketplacePostsProvider(status: status),
    );
    final summary = ref.watch(marketplaceSummaryProvider).value;
    final options = ref.watch(marketplaceOptionsProvider).value;

    return Scaffold(
      floatingActionButton: status != null
          ? null
          : FloatingActionButton.extended(
              key: const ValueKey('marketplace-add-post'),
              onPressed: () => _addPost(summary),
              icon: Icon(
                summary == null || summary.plan.canAddActivePost
                    ? Icons.add
                    : Icons.lock_outline,
              ),
              label: const Text('Add post'),
            ),
      body: postsAsync.when(
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
                  onPressed: () => ref.invalidate(
                    businessMarketplacePostsProvider(status: status),
                  ),
                  icon: const Icon(Icons.refresh),
                  label: const Text('Try again'),
                ),
              ],
            ),
          ),
        ),
        data: (posts) => _list(posts, summary, options),
      ),
    );
  }

  Widget _list(
    List<MarketplacePost> posts,
    MarketplaceSummary? summary,
    MarketplaceOptions? options,
  ) {
    final shown = _kind == null
        ? posts
        : posts.where((p) => p.kind == _kind).toList();
    final kinds = options?.kinds ?? const <MarketplaceOption>[];

    return RefreshIndicator(
      onRefresh: () async {
        reloadMarketplace(ref);
        await ref.read(
          businessMarketplacePostsProvider(status: widget.status).future,
        );
      },
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.only(bottom: 96),
        children: [
          if (widget.status == null && summary != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
              child: MarketplacePlanBanner(plan: summary.plan),
            ),
          if (posts.isNotEmpty && kinds.isNotEmpty)
            FilterChipBar(
              chips: [
                CountChip(
                  key: const ValueKey('marketplace-kind-all'),
                  label: 'All',
                  count: posts.length,
                  selected: _kind == null,
                  onSelected: () => setState(() => _kind = null),
                ),
                for (final k in kinds)
                  CountChip(
                    key: ValueKey('marketplace-kind-${k.code}'),
                    label: k.name,
                    count: posts.where((p) => p.kind == k.code).length,
                    selected: _kind == k.code,
                    onSelected: () => setState(() => _kind = k.code),
                  ),
              ],
            ),
          if (shown.isEmpty)
            EmptyState(
              icon: Icons.storefront_outlined,
              title: posts.isEmpty ? 'Nothing posted yet' : 'None of this kind',
              message: widget.status != null
                  ? 'No posts here right now.'
                  : posts.isEmpty
                  ? 'Tap "Add post" to list a vehicle, property, products, farm produce, '
                        'a food offer or an advertisement.'
                  : 'Choose another kind above, or tap "Add post".',
            )
          else
            for (final post in shown)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
                child: MarketplacePostCard(post: post),
              ),
        ],
      ),
    );
  }

  /// Opens the form — unless the plan has no room, when it says why instead.
  void _addPost(MarketplaceSummary? summary) {
    final plan = summary?.plan;
    if (plan != null && !plan.canAddActivePost) {
      AppMessenger.of(context).showInfo(marketplacePlanFullMessage(plan));
      return;
    }
    showMarketplacePostFormSheet(context);
  }
}

/// "Your Free plan allows 1 active post. Pause or close one to put up another."
String marketplacePlanFullMessage(MarketplacePlan plan) =>
    'Your ${plan.name} plan allows ${plan.maxActivePosts} active '
    'post${plan.maxActivePosts == 1 ? '' : 's'}. Pause or close one to put up another.';

/// The plan and how much of it is used, over the post list.
class MarketplacePlanBanner extends StatelessWidget {
  const MarketplacePlanBanner({required this.plan, super.key});

  final MarketplacePlan plan;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final full = !plan.canAddActivePost;
    return Card(
      key: const ValueKey('marketplace-plan-banner'),
      margin: EdgeInsets.zero,
      child: ListTile(
        leading: Icon(
          Icons.workspace_premium_outlined,
          color: AppColors.status(
            full ? StatusTone.progress : StatusTone.success,
            theme.brightness,
          ),
        ),
        title: Text(
          '${plan.name} plan · ${plan.usedActivePosts} of ${plan.maxActivePosts} '
          'active post${plan.maxActivePosts == 1 ? '' : 's'} used',
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        subtitle: Text(
          full
              ? 'Pause or close a post to put up a new one. More plans are coming soon.'
              : 'Paused, closed and expired posts do not count.',
        ),
      ),
    );
  }
}

/// One post in the business's list: photo, title, the lines its kind needs, and a menu of the
/// moves the server allows from its status.
class MarketplacePostCard extends ConsumerWidget {
  const MarketplacePostCard({required this.post, super.key});

  final MarketplacePost post;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final options = ref.watch(marketplaceOptionsProvider).value;
    final categories =
        ref.watch(marketplaceCategoriesProvider).value ??
        const <MarketplaceCategory>[];
    final cover = post.imageUrlForSlot(0);
    final price = marketplacePriceLine(post);
    final quantity = marketplaceQuantityLine(post);
    final window = marketplaceWindowLine(post);
    final details = marketplaceDetailsLine(post, categories);

    return MediaListCard(
      key: ValueKey('marketplace-post-${post.id}'),
      thumbnailUrl: cover == null ? null : MarketplaceApi.mediaUrl(cover),
      placeholderIcon: Icons.storefront_outlined,
      title: post.title,
      lines: [
        Text(
          '${post.categoryName} · ${post.placeLine}',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        Wrap(
          spacing: 10,
          runSpacing: 4,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            if (price != null)
              Text(price, style: const TextStyle(fontWeight: FontWeight.w600)),
            marketplaceStatusPill(options, post.status),
          ],
        ),
        if (quantity != null) Text(quantity),
        if (window != null) Text(window),
        if (details != null)
          Text(details, maxLines: 1, overflow: TextOverflow.ellipsis),
      ],
      menu: [
        if (post.status != MarketplacePostStatus.closed) ('edit', 'Edit'),
        for (final action in post.actions)
          ('status:${action.toStatus}', action.name),
        ('delete', 'Remove'),
      ],
      onMenuSelected: (value) => _onMenu(context, ref, value),
    );
  }

  Future<void> _onMenu(BuildContext context, WidgetRef ref, String value) {
    if (value == 'edit') {
      return showMarketplacePostFormSheet(context, existing: post);
    }
    if (value == 'delete') return _remove(context, ref);
    final action = post.actions.firstWhere(
      (a) => 'status:${a.toStatus}' == value,
    );
    return _move(context, ref, action);
  }

  Future<void> _move(
    BuildContext context,
    WidgetRef ref,
    MarketplacePostAction action,
  ) async {
    if (action.needsConfirm) {
      final confirmed = await showConfirmDialog(
        context,
        title: '${action.name}?',
        message:
            '"${post.title}" will no longer be shown, and cannot be put up again.',
        confirmLabel: action.name,
        destructive: true,
      );
      if (!confirmed || !context.mounted) return;
    }

    // Before the await, as the app's messages need: the screen's colours and its messenger.
    final messenger = AppMessenger.of(context);
    try {
      await ref
          .read(marketplaceRepositoryProvider)
          .changeStatus(post.id, action.toStatus);
      reloadMarketplace(ref);
      messenger.showSuccess(
        '${post.title}: ${action.name.toLowerCase()} done.',
      );
    } catch (e) {
      messenger.showFailure(e.toString());
    }
  }

  Future<void> _remove(BuildContext context, WidgetRef ref) async {
    final confirmed = await showConfirmDialog(
      context,
      title: 'Remove post?',
      message: '"${post.title}" will be taken off your Marketplace list.',
      confirmLabel: 'Remove',
      destructive: true,
    );
    if (!confirmed || !context.mounted) return;

    final messenger = AppMessenger.of(context);
    try {
      await ref.read(marketplaceRepositoryProvider).delete(post.id);
      reloadMarketplace(ref);
      messenger.showSuccess('${post.title} removed.');
    } catch (e) {
      messenger.showFailure(e.toString());
    }
  }
}

/// The posts behind a home-screen tile, on a page of their own.
class MarketplacePostListScreen extends StatelessWidget {
  const MarketplacePostListScreen({
    required this.title,
    this.status,
    super.key,
  });

  final String title;

  /// Null for every post.
  final String? status;

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(title)),
    body: BusinessMarketplaceTab(status: status),
  );
}
