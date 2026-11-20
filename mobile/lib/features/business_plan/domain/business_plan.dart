/// The three areas a business lists in; one plan covers them all.
enum ListingArea {
  service('Service'),
  rent('Rent'),
  marketplace('Marketplace');

  const ListingArea(this.label);

  /// As the business reads it, and as the server names it.
  final String label;

  static ListingArea? parse(String value) {
    for (final area in values) {
      if (area.label.toLowerCase() == value.toLowerCase()) return area;
    }
    return null;
  }
}

/// One area: how many listings are live there, and whether one more may go up.
class AreaUsage {
  const AreaUsage({
    required this.area,
    required this.canAdd,
    this.liveCount,
    this.reason,
  });

  final ListingArea area;

  /// Null when the area could not be counted just now.
  final int? liveCount;
  final bool canAdd;

  /// Why not, in the server's words; null when it can add.
  final String? reason;
}

/// A plan on sale. Every price, length and name is the Super Admin's.
class PlanOffer {
  const PlanOffer({
    required this.id,
    required this.code,
    required this.name,
    required this.period,
    required this.price,
    required this.durationDays,
    required this.areas,
  });

  final String id;
  final String code;
  final String name;

  /// `Monthly` or `Annual`.
  final String period;
  final double price;
  final int durationDays;
  final Set<ListingArea> areas;

  bool get isAnnual => period == 'Annual';

  bool includes(ListingArea area) => areas.contains(area);
}

/// The business's plan: free Basic or a paid one, what it uses, and what it can buy.
class BusinessPlan {
  const BusinessPlan({
    required this.planName,
    required this.isBasic,
    required this.basicLimit,
    required this.areas,
    required this.pausedCount,
    required this.offers,
    this.includes = const {},
    this.endsAt,
  });

  final String planName;
  final bool isBasic;
  final DateTime? endsAt;

  /// The areas a running paid plan opens.
  final Set<ListingArea> includes;

  /// How many live listings the Basic plan allows in total.
  final int basicLimit;
  final List<AreaUsage> areas;

  /// Listings the end of a plan paused; they come back on renewal.
  final int pausedCount;
  final List<PlanOffer> offers;

  AreaUsage? usage(ListingArea area) {
    for (final usage in areas) {
      if (usage.area == area) return usage;
    }
    return null;
  }

  /// Live listings in all areas; null when one could not be counted.
  int? get totalLive {
    var total = 0;
    for (final usage in areas) {
      final count = usage.liveCount;
      if (count == null) return null;
      total += count;
    }
    return total;
  }

  /// The cheapest plan of [period] that opens [area], to suggest on a lock.
  PlanOffer? cheapestFor(ListingArea area, {String period = 'Monthly'}) {
    PlanOffer? best;
    for (final offer in offers) {
      if (offer.period != period || !offer.includes(area)) continue;
      if (best == null || offer.price < best.price) best = offer;
    }
    return best;
  }

  /// What a year of the same plan monthly would cost more than [annual]; null without a monthly match.
  double? annualSaving(PlanOffer annual) {
    for (final offer in offers) {
      if (!offer.isAnnual &&
          offer.name == annual.name &&
          offer.areas.length == annual.areas.length &&
          offer.areas.containsAll(annual.areas)) {
        final saving = offer.price * 12 - annual.price;
        return saving > 0 ? saving : null;
      }
    }
    return null;
  }
}

/// A purchase started: the Razorpay order to pay, or nothing to collect.
class PlanPayment {
  const PlanPayment({
    required this.subscriptionId,
    required this.planName,
    required this.amount,
    required this.durationDays,
    required this.nothingToCollect,
    this.providerOrderId,
    this.razorpayKeyId,
  });

  final String subscriptionId;
  final String planName;
  final double amount;
  final int durationDays;
  final String? providerOrderId;
  final String? razorpayKeyId;
  final bool nothingToCollect;
}
