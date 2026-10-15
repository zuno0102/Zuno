import 'package:zuno/features/customer/domain/entities/service_listing.dart';

/// Everything the customer's home screen lists, composed by the server so none of it repeats.
///
/// One object rather than four requests: the sections have to know about each other, or they all pick
/// the same services for the same good reasons — which is how the page came to show one business six
/// times in a row.
class HomeSections {
  const HomeSections({
    this.forYou = const [],
    this.mostBooked = const [],
    this.more = const [],
    this.topRated = const [],
    this.all = const [],
  });

  final List<ServiceListing> forYou;
  final List<ServiceListing> mostBooked;
  final List<ServiceListing> more;
  final List<ServiceListing> topRated;
  final List<ServiceListing> all;

  bool get isEmpty =>
      forYou.isEmpty &&
      mostBooked.isEmpty &&
      more.isEmpty &&
      topRated.isEmpty &&
      all.isEmpty;
}
