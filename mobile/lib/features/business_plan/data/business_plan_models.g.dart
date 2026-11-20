// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'business_plan_models.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

AreaUsageModel _$AreaUsageModelFromJson(Map<String, dynamic> json) =>
    AreaUsageModel(
      area: json['area'] as String,
      liveCount: (json['liveCount'] as num?)?.toInt(),
      canAdd: json['canAdd'] as bool? ?? false,
      reason: json['reason'] as String?,
    );

PlanOfferModel _$PlanOfferModelFromJson(Map<String, dynamic> json) =>
    PlanOfferModel(
      id: json['id'] as String,
      code: json['code'] as String,
      name: json['name'] as String,
      period: json['period'] as String,
      price: (json['price'] as num).toDouble(),
      durationDays: (json['durationDays'] as num).toInt(),
      includesService: json['includesService'] as bool? ?? false,
      includesRent: json['includesRent'] as bool? ?? false,
      includesMarketplace: json['includesMarketplace'] as bool? ?? false,
    );

BusinessPlanModel _$BusinessPlanModelFromJson(Map<String, dynamic> json) =>
    BusinessPlanModel(
      planName: json['planName'] as String,
      isBasic: json['isBasic'] as bool? ?? true,
      endsAt: json['endsAt'] == null
          ? null
          : DateTime.parse(json['endsAt'] as String),
      includesService: json['includesService'] as bool? ?? false,
      includesRent: json['includesRent'] as bool? ?? false,
      includesMarketplace: json['includesMarketplace'] as bool? ?? false,
      basicLimit: (json['basicLimit'] as num?)?.toInt() ?? 1,
      areas:
          (json['areas'] as List<dynamic>?)
              ?.map((e) => AreaUsageModel.fromJson(e as Map<String, dynamic>))
              .toList() ??
          const [],
      pausedCount: (json['pausedCount'] as num?)?.toInt() ?? 0,
      plans:
          (json['plans'] as List<dynamic>?)
              ?.map((e) => PlanOfferModel.fromJson(e as Map<String, dynamic>))
              .toList() ??
          const [],
    );

PlanPaymentModel _$PlanPaymentModelFromJson(Map<String, dynamic> json) =>
    PlanPaymentModel(
      subscriptionId: json['subscriptionId'] as String,
      planName: json['planName'] as String,
      amount: (json['amount'] as num).toDouble(),
      durationDays: (json['durationDays'] as num).toInt(),
      providerOrderId: json['providerOrderId'] as String?,
      razorpayKeyId: json['razorpayKeyId'] as String?,
      nothingToCollect: json['nothingToCollect'] as bool? ?? false,
    );
