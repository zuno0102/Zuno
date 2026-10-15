import 'package:cached_network_image/cached_network_image.dart';
import 'package:zuno/core/constants/api_constants.dart';
import 'package:flutter/material.dart';

/// One tile in the category picker.
class CategoryTile {
  const CategoryTile({
    required this.id,
    required this.label,
    required this.icon,
    this.iconUrl,
  });

  final String id;
  final String label;

  /// The built-in icon to draw when there is no uploaded image.
  final IconData icon;

  /// An image the app owner uploaded for this category, drawn in preference to [icon].
  ///
  /// The reason it exists: this app can only draw icons compiled into it, so a category wanting
  /// artwork outside that set would otherwise wait for a release. With an image on the row, adding a
  /// category is entirely self-service.
  final String? iconUrl;
}

/// The icon grid a customer taps to narrow down what they are looking for.
///
/// Capped at seven with an eighth "More" tile rather than growing without limit: a grid long
/// enough to scroll stops being a glance and becomes another list to read.
class CategoryGrid extends StatelessWidget {
  const CategoryGrid({
    required this.categories,
    required this.onSelected,
    this.selectedId,
    this.maxVisible = 7,
    this.onMore,
    super.key,
  });

  final List<CategoryTile> categories;
  final ValueChanged<String?> onSelected;
  final String? selectedId;
  final int maxVisible;
  final VoidCallback? onMore;

  /// The icons this app can draw, by the key a category row carries.
  ///
  /// The only list of its kind that has to stay in code. Flutter strips every icon the source does
  /// not name, so an icon chosen purely at runtime — a codepoint read from the database — would draw
  /// an empty box unless the whole Material font were shipped with the app. This is the dictionary;
  /// the database holds the choice.
  ///
  /// Adding an icon here and naming its key on a category row is all a new category needs.
  static const iconsByName = <String, IconData>{
    'plumbing': Icons.plumbing,
    'electrical': Icons.bolt,
    'cleaning': Icons.cleaning_services,
    'carpentry': Icons.carpenter,
    'painting': Icons.format_paint,
    'appliance': Icons.kitchen,
    'pest-control': Icons.pest_control,
    'beauty': Icons.spa,
    'catering': Icons.restaurant,
    'events': Icons.celebration,
    'photography': Icons.photo_camera,
    'sound': Icons.speaker,
    'transport': Icons.local_shipping,
    'home-repair': Icons.home_repair_service,
    'handyman': Icons.handyman,
  };

  /// The icon for a category, taken from the row that defines it.
  ///
  /// [iconName] is what the app owner chose and is the answer whenever it is set. The guess from the
  /// name is only for a row that has none — a category a business added before anybody picked one.
  /// That guess used to be the whole mechanism, which is how Carpentry came to show a lorry.
  static IconData iconForCategory({String? iconName, required String name}) {
    if (iconName != null) {
      if (iconsByName[iconName] case final icon?) return icon;
    }
    return iconFor(name);
  }

  /// A guess at an icon from what the category is called. The fallback, not the rule.
  static IconData iconFor(String name) {
    final n = name.toLowerCase();
    if (n.contains('cater') || n.contains('food')) return Icons.restaurant;
    // Checked before the generic fallback and after catering, so a category named for both lands on
    // the food icon — "Catering & events" was one category until it was split into two trades.
    if (n.contains('decor') ||
        n.contains('event') ||
        n.contains('party') ||
        n.contains('wedding')) {
      return Icons.celebration;
    }
    if (n.contains('photo') || n.contains('video')) return Icons.photo_camera;
    if (n.contains('electric')) return Icons.bolt;
    if (n.contains('plumb')) return Icons.plumbing;
    if (n.contains('clean')) return Icons.cleaning_services;
    if (n.contains('sound') || n.contains('music') || n.contains('light')) {
      return Icons.speaker;
    }
    if (n.contains('paint')) return Icons.format_paint;
    if (n.contains('pest')) return Icons.pest_control;
    if (n.contains('beauty') ||
        n.contains('salon') ||
        n.contains('wellness') ||
        n.contains('spa')) {
      return Icons.spa;
    }
    if (n.contains('appliance')) return Icons.kitchen;
    // Before the transport rule, and this order is the whole point: "car" is a substring of
    // "carpentry", so Carpentry was being given a lorry.
    if (n.contains('carpent') || n.contains('wood') || n.contains('furniture')) {
      return Icons.carpenter;
    }
    if (n.contains('home') || n.contains('house')) return Icons.home_repair_service;
    if (n.contains('transport') || n.contains('car')) return Icons.local_shipping;
    return Icons.handyman;
  }

  @override
  Widget build(BuildContext context) {
    final visible = categories.take(maxVisible).toList();
    final hidden = categories.length - visible.length;

    // The chosen category, when it is one of the ones that did not fit in the grid.
    //
    // Without this the last tile still read "More" and sat unlit while a filter was quietly narrowing
    // every result below it: the customer had chosen Catering from the sheet, no tile on screen
    // showed it, and the only clue was the Clear link further down the page. So the tile takes on
    // whatever is filtering — its name, its icon, lit — and still opens the full list when tapped.
    final chosenButHidden = selectedId == null
        ? null
        : categories
              .skip(visible.length)
              .where((c) => c.id == selectedId)
              .firstOrNull;

    return GridView.count(
      crossAxisCount: 4,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 12),
      // Two rows of these sit between the banner and the services, so every bit of height here comes
      // straight out of what a customer can see of the first service card without scrolling. At 0.86
      // the pair cost about 110px more than they needed to, and the cards below opened half cut off.
      childAspectRatio: 1.05,
      mainAxisSpacing: 2,
      children: [
        for (final c in visible)
          _Tile(
            icon: c.icon,
            iconUrl: c.iconUrl,
            label: c.label,
            selected: c.id == selectedId,
            // Tapping the chosen one again clears it, so there is always a way back to
            // everything without hunting for a reset.
            onTap: () => onSelected(c.id == selectedId ? null : c.id),
          ),
        if (hidden > 0)
          _Tile(
            icon: chosenButHidden?.icon ?? Icons.more_horiz,
            iconUrl: chosenButHidden?.iconUrl,
            label: chosenButHidden?.label ?? 'More',
            selected: chosenButHidden != null,
            // Lit, it behaves like every other tile in this grid: tapping the one already chosen
            // turns it off, and the tile goes back to reading "More". Opening the list instead would
            // make this the one tile where the obvious gesture did something else.
            onTap: chosenButHidden != null
                ? () => onSelected(null)
                : (onMore ?? () {}),
          ),
      ],
    );
  }
}

/// What came back from the all-categories sheet. A null [id] means "any category".
///
/// A class rather than a bare `String?`, because the sheet has to be able to say three different
/// things: this one, no filter at all, and nothing — the customer dismissed it. A null return from
/// the sheet is the third.
class CategoryPick {
  const CategoryPick(this.id);

  final String? id;
}

/// The rest of the categories, behind the "More" tile.
///
/// A plain list of categories with their icons, one tap to choose. It used to open the app's generic
/// multi-select sheet — the same checkbox-and-search sheet the district filter uses — so a customer
/// tapping More on the categories got something that looked like the location picker. It also took
/// several ticks and then quietly applied only the first, because the feed filters on one category.
Future<CategoryPick?> showAllCategoriesSheet(
  BuildContext context, {
  required List<CategoryTile> categories,
  String? selectedId,
}) {
  return showModalBottomSheet<CategoryPick>(
    context: context,
    useSafeArea: true,
    // The list is longer than the default sheet allows, and a category below the fold that cannot
    // be reached is the same as one that does not exist.
    isScrollControlled: true,
    builder: (context) {
      final theme = Theme.of(context);

      return SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 18, 20, 12),
              child: Text(
                'All categories',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            const Divider(height: 1),
            Flexible(
              child: ListView(
                shrinkWrap: true,
                children: [
                  _CategoryRow(
                    icon: Icons.apps,
                    label: 'Everything',
                    detail: 'No category filter',
                    isSelected: selectedId == null,
                    onTap: () =>
                        Navigator.of(context).pop(const CategoryPick(null)),
                  ),
                  for (final category in categories)
                    _CategoryRow(
                      icon: category.icon,
                      iconUrl: category.iconUrl,
                      label: category.label,
                      isSelected: category.id == selectedId,
                      onTap: () =>
                          Navigator.of(context).pop(CategoryPick(category.id)),
                    ),
                ],
              ),
            ),
          ],
        ),
      );
    },
  );
}

class _CategoryRow extends StatelessWidget {
  const _CategoryRow({
    required this.icon,
    this.iconUrl,
    required this.label,
    required this.isSelected,
    required this.onTap,
    this.detail,
  });

  final IconData icon;
  final String? iconUrl;
  final String label;
  final String? detail;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return ListTile(
      onTap: onTap,
      selected: isSelected,
      selectedTileColor: theme.colorScheme.primary.withValues(alpha: 0.08),
      // The same icon the grid uses, so the list reads as more of the grid rather than as a
      // different control that happens to open from it.
      // The same preference as the grid: an uploaded image, else the built-in icon.
      leading: iconUrl == null || iconUrl!.isEmpty
          ? Icon(
              icon,
              color: isSelected
                  ? theme.colorScheme.primary
                  : theme.colorScheme.onSurfaceVariant,
            )
          : SizedBox(
              width: 24,
              height: 24,
              child: CachedNetworkImage(
                imageUrl: '${ApiConstants.baseUrl}$iconUrl',
                fit: BoxFit.contain,
                errorWidget: (_, _, _) => Icon(icon),
              ),
            ),
      title: Text(
        label,
        style: theme.textTheme.bodyLarge?.copyWith(
          fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
          color: isSelected ? theme.colorScheme.primary : null,
        ),
      ),
      subtitle: detail == null ? null : Text(detail!),
      trailing: isSelected
          ? Icon(Icons.check_circle, color: theme.colorScheme.primary)
          : null,
    );
  }
}

class _Tile extends StatelessWidget {
  const _Tile({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
    this.iconUrl,
  });

  final IconData icon;
  final String? iconUrl;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tint = selected ? theme.colorScheme.primary : theme.colorScheme.onSurfaceVariant;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: selected
                  ? theme.colorScheme.primaryContainer
                  : theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.7),
              borderRadius: BorderRadius.circular(14),
              border: selected
                  ? Border.all(color: theme.colorScheme.primary, width: 1.5)
                  : null,
            ),
            // The uploaded image wins. Tinted icons and full-colour artwork cannot both be
            // styled the same way, so the image is drawn as it was given, inset a little.
            child: iconUrl == null || iconUrl!.isEmpty
                ? Icon(icon, size: 20, color: tint)
                : Padding(
                    padding: const EdgeInsets.all(7),
                    child: CachedNetworkImage(
                      imageUrl: '${ApiConstants.baseUrl}$iconUrl',
                      fit: BoxFit.contain,
                      // A category that has an image but cannot load it still has a usable tile.
                      errorWidget: (_, _, _) => Icon(icon, size: 20, color: tint),
                    ),
                  ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: theme.textTheme.bodySmall?.copyWith(
              fontSize: 11,
              fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
              color: selected ? theme.colorScheme.primary : null,
            ),
          ),
        ],
      ),
    );
  }
}
