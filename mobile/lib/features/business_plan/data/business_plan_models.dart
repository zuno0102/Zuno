import 'package:json_annotation/json_annotation.dart';
import 'package:zuno/features/business_plan/domain/business_plan.dart';

part 'business_plan_models.g.dart';

Set<ListingArea> _areas({
  required bool service,
  required bool rent,
  required bool marketplace,
}) => {
  if (service) ListingArea.service,
  if (rent) ListingArea.rent,
  if (marketplace) ListingArea.marketplace,
};

@JsonSerializable(createToJson: false)
class AreaUsageModel {
  const AreaUsageModel({
    required this.area,
    this.liveCount,
    this.canAdd = false,
    this.reason,
  });

  factory AreaUsageModel.fromJson(Map<String, dynamic> json) =>
      _$AreaUsageModelFromJson(json);

  final String area;
  final int? liveCount;
  final bool canAdd;
  final String? reason;
}

@JsonSerializable(createToJson: false)
class PlanOfferModel {
  const PlanOfferModel({
    required this.id,
    required this.code,
    required this.name,
    required this.period,
    required this.price,
    required this.durationDays,
    this.includesService = false,
    this.includesRent = false,
    this.includesMarketplace = false,
  });

  factory PlanOfferModel.fromJson(Map<String, dynamic> json) =>
      _$PlanOfferModelFromJson(json);

  final String id;
  final String code;
  final String name;
  final String period;
  final double price;
  final int durationDays;
  final bool includesService;
  final bool includesRent;
  final bool includesMarketplace;

  PlanOffer toEntity() => PlanOffer(
    id: id,
    code: code,
    name: name,
    period: period,
    price: price,
    durationDays: durationDays,
    areas: _areas(
      service: includesService,
      rent: includesRent,
      marketplace: includesMarketplace,
    ),
  );
}

@JsonSerializable(createToJson: false)
class BusinessPlanModel {
  const BusinessPlanModel({
    required this.planName,
    this.isBasic = true,
    this.endsAt,
    this.includesService = false,
    this.includesRent = false,
    this.includesMarketplace = false,
    this.basicLimit = 1,
    this.areas = const [],
    this.pausedCount = 0,
    this.plans = const [],
  });

  factory BusinessPlanModel.fromJson(Map<String, dynamic> json) =>
      _$BusinessPlanModelFromJson(json);

  final String planName;
  final bool isBasic;
  final DateTime? endsAt;
  final bool includesService;
  final bool includesRent;
  final bool includesMarketplace;
  final int basicLimit;
  final List<AreaUsageModel> areas;
  final int pausedCount;
  final List<PlanOfferModel> plans;

  BusinessPlan toEntity() => BusinessPlan(
    planName: planName,
    isBasic: isBasic,
    endsAt: endsAt?.toLocal(),
    includes: _areas(
      service: includesService,
      rent: includesRent,
      marketplace: includesMarketplace,
    ),
    basicLimit: basicLimit,
    areas: [
      for (final a in areas)
        if (ListingArea.parse(a.area) case final area?)
          AreaUsage(
            area: area,
            liveCount: a.liveCount,
            canAdd: a.canAdd,
            reason: a.reason,
          ),
    ],
    pausedCount: pausedCount,
    offers: [for (final p in plans) p.toEntity()],
  );
}

@JsonSerializable(createToJson: false)
class PlanPaymentModel {
  const PlanPaymentModel({
    required this.subscriptionId,
    required this.planName,
    required this.amount,
    required this.durationDays,
    this.providerOrderId,
    this.razorpayKeyId,
    this.nothingToCollect = false,
  });

  factory PlanPaymentModel.fromJson(Map<String, dynamic> json) =>
      _$PlanPaymentModelFromJson(json);

  final String subscriptionId;
  final String planName;
  final double amount;
  final int durationDays;
  final String? providerOrderId;
  final String? razorpayKeyId;
  final bool nothingToCollect;

  PlanPayment toEntity() => PlanPayment(
    subscriptionId: subscriptionId,
    planName: planName,
    amount: amount,
    durationDays: durationDays,
    providerOrderId: providerOrderId,
    razorpayKeyId: razorpayKeyId,
    nothingToCollect: nothingToCollect,
  );
}
