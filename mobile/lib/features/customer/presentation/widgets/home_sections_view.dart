import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:zuno/features/customer/domain/entities/home_sections.dart';
import 'package:zuno/features/customer/domain/entities/service_listing.dart';
import 'package:zuno/features/customer/presentation/widgets/popular_services_strip.dart';
import 'package:zuno/features/customer/presentation/widgets/service_card.dart';
import 'package:zuno/shared/widgets/section_header.dart';

/// The customer home screen's service sections, in order.
///
/// Five of them, alternating between grids to browse and strips to glance at, so the page has a
/// rhythm rather than being one long wall of identical cards. Every service on it is distinct — the
/// server composes the sections against each other — which is what stops the same business filling
/// the screen the way it used to.
List<Widget> homeSectionSlivers(BuildContext context, HomeSections sections) => [
  if (sections.forYou.isNotEmpty) ...[
    const SliverToBoxAdapter(child: SectionHeader(title: 'Services for you')),
    _grid(sections.forYou),
  ],

  if (sections.mostBooked.isNotEmpty) ...[
    const SliverToBoxAdapter(
      child: SectionHeader(title: 'Booked most often'),
    ),
    SliverToBoxAdapter(child: PopularServicesStrip(services: sections.mostBooked)),
  ],

  if (sections.more.isNotEmpty) ...[
    const SliverToBoxAdapter(child: SectionHeader(title: 'More to explore')),
    _grid(sections.more),
  ],

  if (sections.topRated.isNotEmpty) ...[
    const SliverToBoxAdapter(child: SectionHeader(title: 'Top rated')),
    SliverToBoxAdapter(child: PopularServicesStrip(services: sections.topRated)),
  ],

  if (sections.all.isNotEmpty) ...[
    SliverToBoxAdapter(
      child: SectionHeader(
        title: 'All services',
        count: sections.all.length,
      ),
    ),
    _grid(sections.all),
  ],

  const SliverToBoxAdapter(child: ZunoQuote()),
];

/// Two across, which is the shape every grid on this page uses.
///
/// Fixed at two rather than fitted to the width, so a section is the same number of rows on every
/// phone — twenty services are ten rows wherever they are read.
Widget _grid(List<ServiceListing> services) => SliverPadding(
  padding: const EdgeInsets.fromLTRB(16, 0, 16, 18),
  sliver: SliverGrid.builder(
    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
      crossAxisCount: 2,
      mainAxisSpacing: 12,
      crossAxisSpacing: 12,
      childAspectRatio: 0.74,
    ),
    itemCount: services.length,
    itemBuilder: (context, index) => ServiceCard(
      service: services[index],
      onTap: () => context.push('/customer/service/${services[index].id}'),
    ),
  ),
);

/// A line at the foot of the home screen.
///
/// The end of a long scroll is otherwise just where the cards stop. One quiet sentence gives the page
/// an ending, and says what Zuno is for in the words a customer would use.
///
/// Changes daily rather than on every build: a line that flickers between rebuilds reads as a bug.
class ZunoQuote extends StatelessWidget {
  const ZunoQuote({super.key});

  static const _lines = <String>[
    'Good work, close to home.',
    'Every job here was done by somebody your neighbours booked.',
    'Ask, agree, and get it done — all in one place.',
    'Behind every service is a person who does this for a living.',
    'Booked in minutes. Done properly.',
    'The right people for the day that matters.',
    'Local businesses, paid fairly, on time.',
  ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final line = _lines[DateTime.now().day % _lines.length];

    return Padding(
      padding: const EdgeInsets.fromLTRB(32, 10, 32, 36),
      child: Column(
        children: [
          Icon(
            Icons.format_quote_rounded,
            size: 26,
            color: theme.colorScheme.primary.withValues(alpha: 0.35),
          ),
          const SizedBox(height: 6),
          Text(
            line,
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
              fontStyle: FontStyle.italic,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'ZUNO',
            style: theme.textTheme.labelSmall?.copyWith(
              letterSpacing: 3,
              fontWeight: FontWeight.w700,
              color: theme.colorScheme.primary.withValues(alpha: 0.6),
            ),
          ),
        ],
      ),
    );
  }
}
