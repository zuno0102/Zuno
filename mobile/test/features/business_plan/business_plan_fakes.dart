import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:zuno/features/business_plan/data/business_plan_repository.dart';
import 'package:zuno/features/business_plan/domain/business_plan.dart';
import 'package:zuno/features/business_plan/presentation/business_plan_providers.dart';

/// Plans on sale as the Super Admin seeded them, monthly and yearly.
const testPlanOffers = [
  PlanOffer(
    id: 'p-s-m',
    code: 'service-monthly',
    name: 'Service',
    period: 'Monthly',
    price: 199,
    durationDays: 30,
    areas: {ListingArea.service},
  ),
  PlanOffer(
    id: 'p-r-m',
    code: 'rent-monthly',
    name: 'Rent',
    period: 'Monthly',
    price: 199,
    durationDays: 30,
    areas: {ListingArea.rent},
  ),
  PlanOffer(
    id: 'p-a-m',
    code: 'all3-monthly',
    name: 'All 3',
    period: 'Monthly',
    price: 699,
    durationDays: 30,
    areas: {ListingArea.service, ListingArea.rent, ListingArea.marketplace},
  ),
  PlanOffer(
    id: 'p-a-y',
    code: 'all3-annual',
    name: 'All 3',
    period: 'Annual',
    price: 6999,
    durationDays: 365,
    areas: {ListingArea.service, ListingArea.rent, ListingArea.marketplace},
  ),
];

/// A Basic business with [live] listings per area; areas in [locked] cannot add.
BusinessPlan testBusinessPlan({
  Map<ListingArea, int> live = const {},
  Set<ListingArea> locked = const {},
  String planName = 'Basic',
  bool isBasic = true,
  DateTime? endsAt,
  int pausedCount = 0,
  Set<ListingArea> includes = const {},
}) => BusinessPlan(
  planName: planName,
  isBasic: isBasic,
  endsAt: endsAt,
  includes: includes,
  basicLimit: 1,
  pausedCount: pausedCount,
  offers: testPlanOffers,
  areas: [
    for (final area in ListingArea.values)
      AreaUsage(
        area: area,
        liveCount: live[area] ?? 0,
        canAdd: !locked.contains(area),
        reason: locked.contains(area)
            ? 'The Basic plan allows 1 live listing in total. Get a plan with ${area.label} to add more.'
            : null,
      ),
  ],
);

/// The plan a screen under test sees; every area open unless said otherwise.
Override businessPlanOverride([BusinessPlan? plan]) => businessPlanProvider
    .overrideWith((ref) async => plan ?? testBusinessPlan());

/// Answers like the Service API's plan endpoints, remembering what was bought.
class FakeBusinessPlanRepository implements BusinessPlanRepository {
  FakeBusinessPlanRepository(this.plan);

  BusinessPlan plan;
  final started = <String>[];
  final confirmed = <(String, String?, String?)>[];

  /// What a confirmed purchase turns the plan into.
  BusinessPlan? afterPurchase;

  @override
  Future<BusinessPlan> getPlan() async => plan;

  @override
  Future<PlanPayment> startPurchase(String planId) async {
    started.add(planId);
    final offer = plan.offers.firstWhere((o) => o.id == planId);
    return PlanPayment(
      subscriptionId: 'sub-1',
      planName: offer.name,
      amount: offer.price,
      durationDays: offer.durationDays,
      nothingToCollect: true,
    );
  }

  @override
  Future<BusinessPlan> confirmPurchase(
    String subscriptionId, {
    String? paymentId,
    String? signature,
  }) async {
    confirmed.add((subscriptionId, paymentId, signature));
    return plan = afterPurchase ?? plan;
  }
}
