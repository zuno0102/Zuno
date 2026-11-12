import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:zuno/core/router/push_screen.dart';
import 'package:zuno/core/theme/app_colors.dart';
import 'package:zuno/core/ui_config/ui_icons.dart';
import 'package:zuno/features/marketplace/data/marketplace_api.dart';
import 'package:zuno/features/marketplace/domain/entities/marketplace_post.dart';
import 'package:zuno/features/marketplace/presentation/providers/marketplace_providers.dart';
import 'package:zuno/features/marketplace/presentation/screens/marketplace_variants_screen.dart';
import 'package:zuno/features/marketplace/presentation/widgets/marketplace_post_form_sheet.dart';
import 'package:zuno/features/marketplace/presentation/widgets/marketplace_post_lines.dart';
import 'package:zuno/shared/widgets/app_messages.dart';
import 'package:zuno/shared/widgets/confirm_dialog.dart';
import 'package:zuno/shared/widgets/empty_state.dart';
import 'package:zuno/shared/widgets/error_banner.dart';
import 'package:zuno/shared/widgets/category_square_row.dart';
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

/// What the business puts up on the Marketplace: its plan's room at the top, a square per main
/// category that starts a new post in it, then every post. Orders › Marketplace is where they are
/// counted and filtered.
///
/// With [status] set it shows only the posts in that state: what a Marketplace tile on the home
/// screen opens. That view lists and changes posts, but adds from the Marketplace tab.
class BusinessMarketplaceTab extends ConsumerStatefulWidget {
  const BusinessMarketplaceTab({this.status, this.inactive = false, super.key});

  final String? status;

  /// The Inactive tile's view: paused posts, and live products with a colour / size switched off.
  final bool inactive;

  /// A home tile's list: it shows and changes posts, but adds from the Marketplace tab.
  bool get isFiltered => status != null || inactive;

  @override
  ConsumerState<BusinessMarketplaceTab> createState() =>
      _BusinessMarketplaceTabState();
}

class _BusinessMarketplaceTabState
    extends ConsumerState<BusinessMarketplaceTab> {
  @override
  Widget build(BuildContext context) {
    final status = widget.status;
    final postsAsync = ref.watch(
      businessMarketplacePostsProvider(
        status: status,
        inactive: widget.inactive,
      ),
    );
    final summary = ref.watch(marketplaceSummaryProvider).value;
    final options = ref.watch(marketplaceOptionsProvider).value;

    return Scaffold(
      floatingActionButton: widget.isFiltered
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
                    businessMarketplacePostsProvider(
                      status: status,
                      inactive: widget.inactive,
                    ),
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
    final categories =
        ref.watch(marketplaceCategoriesProvider).value ??
        const <MarketplaceCategory>[];
    // "products, b2b wholesale, nearby food or advertisements" — from the category table.
    final names = [for (final c in categories) c.name.toLowerCase()];
    final what = names.length < 2
        ? names.join()
        : '${names.take(names.length - 1).join(', ')} or ${names.last}';

    return RefreshIndicator(
      onRefresh: () async {
        reloadMarketplace(ref);
        await ref.read(
          businessMarketplacePostsProvider(
            status: widget.status,
            inactive: widget.inactive,
          ).future,
        );
      },
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.only(bottom: 96),
        children: [
          if (!widget.isFiltered && summary != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
              child: MarketplacePlanBanner(plan: summary.plan),
            ),
          // A square per main category starts a post already in it; the business then picks the
          // sub-category. Only where posts are added — not on a home tile's list.
          if (!widget.isFiltered && categories.isNotEmpty)
            CategorySquareRow<String>(
              squares: [
                for (final c in categories)
                  CategorySquare(
                    value: c.id,
                    label: c.shortName,
                    icon: UiIcons.byName(c.iconName),
                    count: null,
                  ),
              ],
              selected: null,
              onChanged: (id) => _addPost(summary, categoryId: id),
            ),
          if (posts.isEmpty)
            EmptyState(
              icon: Icons.storefront_outlined,
              title: 'Nothing posted yet',
              message: widget.isFiltered
                  ? 'No posts here right now.'
                  : 'Tap a category above or "Add post" to list $what.',
            )
          else
            for (final post in posts)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
                child: MarketplacePostCard(post: post),
              ),
        ],
      ),
    );
  }

  /// Opens the form, in [categoryId] when a square was tapped — unless the plan has no room, when
  /// it says why instead.
  void _addPost(MarketplaceSummary? summary, {String? categoryId}) {
    final plan = summary?.plan;
    if (plan != null && !plan.canAddActivePost) {
      AppMessenger.of(context).showInfo(marketplacePlanFullMessage(plan));
      return;
    }
    showMarketplacePostFormSheet(context, categoryId: categoryId);
  }
}

/// The status moves a post's menu offers. A product is edited, its colours and sizes managed, or
/// removed — not paused or closed: one that runs out of stock hides itself. A paused one can still
/// be put back up, and a used one marked sold.
List<MarketplacePostAction> marketplaceMenuActions(MarketplacePost post) => [
  for (final action in post.actions)
    if (post.condition == null ||
        (action.toStatus != MarketplacePostStatus.paused &&
            action.toStatus != MarketplacePostStatus.closed))
      action,
];

/// The colours and sizes added under a product's main one (the first) that are still on sale —
/// while there are any, the product is not removed.
List<MarketplaceVariant> marketplaceActiveChildVariants(MarketplacePost post) =>
    [
      for (final v in post.variants.skip(1))
        if (v.isActive) v,
    ];

/// "Your Free plan allows 1 active post. Pause, close or remove one to put up another."
String marketplacePlanFullMessage(MarketplacePlan plan) =>
    'Your ${plan.name} plan allows ${plan.maxActivePosts} active '
    'post${plan.maxActivePosts == 1 ? '' : 's'}. Pause, close or remove one to put up another.';

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
              ? 'Pause, close or remove a post to put up a new one. More plans are coming soon.'
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
    final quantity = marketplaceQuantityLine(post, options: options);
    final window = marketplaceWindowLine(post);
    final details = marketplaceDetailsLine(post, categories);

    return MediaListCard(
      key: ValueKey('marketplace-post-${post.id}'),
      thumbnailUrl: cover == null ? null : MarketplaceApi.mediaUrl(cover),
      placeholderIcon: Icons.storefront_outlined,
      title: post.title,
      lines: [
        Text(
          '${post.categoryLine} · ${post.placeLine}',
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
            // Still listed and counted on the plan, but customers do not see it until restocked.
            if (post.isOutOfStock)
              const StatusPill(
                key: ValueKey('marketplace-out-of-stock'),
                label: 'Out of stock',
                tone: StatusTone.danger,
                compact: true,
              ),
          ],
        ),
        if (quantity != null) Text(quantity),
        if (window != null) Text(window),
        if (details != null)
          Text(details, maxLines: 1, overflow: TextOverflow.ellipsis),
      ],
      menu: [
        if (post.status != MarketplacePostStatus.closed &&
            post.status != MarketplacePostStatus.sold)
          ('edit', 'Edit'),
        // A new product's colours and sizes; its stock is counted on the Stock page.
        if (post.canUpdateStock) ('variants', 'Manage variants'),
        for (final action in marketplaceMenuActions(post))
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
    if (value == 'variants') {
      return pushScreen(context, MarketplaceVariantsScreen(post: post));
    }
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
    // The main colour / size goes last: the others on sale are removed or switched off first.
    final children = marketplaceActiveChildVariants(post);
    if (children.isNotEmpty) {
      AppMessenger.of(context).showInfo(
        'Remove or switch off its other colours and sizes first: '
        '${children.map((v) => v.name).join(', ')}.',
      );
      return;
    }

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
    this.inactive = false,
    super.key,
  });

  final String title;

  /// Null for every post.
  final String? status;

  /// The Inactive tile's posts.
  final bool inactive;

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(title)),
    body: BusinessMarketplaceTab(status: status, inactive: inactive),
  );
}
