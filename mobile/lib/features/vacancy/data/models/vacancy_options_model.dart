import 'package:json_annotation/json_annotation.dart';
import 'package:zuno/features/vacancy/data/models/vacancy_model.dart';
import 'package:zuno/features/vacancy/domain/entities/vacancy_options.dart';
import 'package:zuno/features/vacancy/domain/entities/vacancy_payment.dart';

part 'vacancy_options_model.g.dart';

@JsonSerializable(createToJson: false)
class VacancyOptionsModel {
  const VacancyOptionsModel({
    this.jobTypes = const [],
    this.feePlans = const [],
    this.allowedFileExtensions = const [],
    this.maxFileSizeBytes = 0,
  });

  factory VacancyOptionsModel.fromJson(Map<String, dynamic> json) =>
      _$VacancyOptionsModelFromJson(json);

  final List<VacancyJobTypeModel> jobTypes;
  final List<VacancyFeePlanModel> feePlans;
  final List<String> allowedFileExtensions;
  final int maxFileSizeBytes;

  VacancyOptions toEntity() => VacancyOptions(
    jobTypes: jobTypes
        .map(
          (t) => VacancyJobType(
            id: t.id,
            name: t.name,
            hasFixedLength: t.hasFixedLength,
          ),
        )
        .toList(),
    feePlans: feePlans
        .map(
          (p) => VacancyFeePlan(
            id: p.id,
            name: p.name,
            amount: p.amount,
            listingDays: p.listingDays,
          ),
        )
        .toList(),
    allowedFileExtensions: allowedFileExtensions,
    maxFileSizeBytes: maxFileSizeBytes,
  );
}

@JsonSerializable(createToJson: false)
class VacancyJobTypeModel {
  const VacancyJobTypeModel({
    required this.id,
    required this.name,
    required this.hasFixedLength,
  });

  factory VacancyJobTypeModel.fromJson(Map<String, dynamic> json) =>
      _$VacancyJobTypeModelFromJson(json);

  final String id;
  final String name;
  final bool hasFixedLength;
}

@JsonSerializable(createToJson: false)
class VacancyFeePlanModel {
  const VacancyFeePlanModel({
    required this.id,
    required this.name,
    required this.amount,
    required this.listingDays,
  });

  factory VacancyFeePlanModel.fromJson(Map<String, dynamic> json) =>
      _$VacancyFeePlanModelFromJson(json);

  final String id;
  final String name;
  final double amount;
  final int listingDays;
}

@JsonSerializable(createToJson: false)
class VacancyPaymentModel {
  const VacancyPaymentModel({
    required this.vacancyId,
    required this.planName,
    required this.amount,
    required this.listingDays,
    this.providerOrderId,
    this.razorpayKeyId,
    required this.nothingToCollect,
    this.vacancy,
  });

  factory VacancyPaymentModel.fromJson(Map<String, dynamic> json) =>
      _$VacancyPaymentModelFromJson(json);

  final String vacancyId;
  final String planName;
  final double amount;
  final int listingDays;
  final String? providerOrderId;
  final String? razorpayKeyId;
  final bool nothingToCollect;
  final VacancyModel? vacancy;

  VacancyPayment toEntity() => VacancyPayment(
    vacancyId: vacancyId,
    planName: planName,
    amount: amount,
    listingDays: listingDays,
    providerOrderId: providerOrderId,
    razorpayKeyId: razorpayKeyId,
    nothingToCollect: nothingToCollect,
    vacancy: vacancy?.toEntity(),
  );
}
