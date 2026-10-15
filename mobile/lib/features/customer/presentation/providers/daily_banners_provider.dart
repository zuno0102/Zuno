import 'dart:math';

import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:zuno/features/customer/domain/entities/home_sections.dart';
import 'package:zuno/features/customer/domain/entities/service_listing.dart';
import 'package:zuno/features/customer/presentation/providers/customer_providers.dart';

part 'daily_banners_provider.g.dart';

/// The services on today's home banner.
///
/// Which seven, and when they change, is the server's decision — so the app asks once and keeps the
/// answer. Kept alive because the customer shell rebuilds the home tab every time somebody comes back
/// from Bookings, and refetching a banner that only changes at midnight on each of those visits would
/// be a request for nothing.
@Riverpod(keepAlive: true)
Future<List<ServiceListing>> dailyBanners(Ref ref) =>
    ref.watch(customerRepositoryProvider).getBanners();

/// Which shuffle the home screen is showing.
///
/// Re-rolled when somebody pulls to refresh, and only then. The server shuffles the catalogue by
/// whatever seed it is given, so a new one brings back a different set of services while an ordinary
/// rebuild — coming back from Bookings, say — keeps the page exactly where they left it.
///
/// Held in the app rather than decided by the server because only the app can tell those two apart.
@Riverpod(keepAlive: true)
class HomeShuffleSeed extends _$HomeShuffleSeed {
  @override
  int build() => DateTime.now().millisecondsSinceEpoch % 1000000;

  void reroll() => state = Random().nextInt(1000000);
}

/// Every section of the home screen, in one answer.
///
/// One request rather than four: the sections are composed against each other so nothing repeats
/// between them, which only the server can do.
///
/// Kept alive because it changes with the catalogue, not with what the customer is filtering by, and
/// the home tab is rebuilt every time they come back from another tab.
///
/// Deliberately unfiltered. What the customer is looking for narrows the band of results shown
/// *above* these sections; the sections themselves stay the catalogue, so a district with four
/// businesses in it does not reduce the whole home screen to four cards.
@Riverpod(keepAlive: true)
Future<HomeSections> homeSections(Ref ref) => ref
    .watch(customerRepositoryProvider)
    .getHomeSections(seed: ref.watch(homeShuffleSeedProvider));
