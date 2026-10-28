import 'package:json_annotation/json_annotation.dart';
import 'package:zuno/features/catalog/domain/entities/app_options.dart';

part 'app_options_model.g.dart';

/// Every field is optional: one an older server does not send keeps the shipped default.
@JsonSerializable(createToJson: false)
class AppOptionsModel {
  const AppOptionsModel({
    this.hiringPostMinDurationMinutes,
    this.hiringPostMaxDurationMinutes,
    this.hiringPostDefaultDurationMinutes,
    this.hiringPostMaxWorkers,
    this.orderMaxCrewSize,
    this.serviceMaxQuestions,
    this.serviceImageSlots,
    this.serviceVideoMaxSeconds,
    this.serviceVideoMaxBytes,
    this.imageMaxBytes,
    this.imageUploadQuality,
    this.imageUploadMaxWidth,
    this.maxDaysAhead,
    this.customerBookingMaxDaysAhead,
    this.vacancyMaxOpenings,
    this.vacancyMaxContractMonths,
    this.vacancyMaxFields,
    this.vacancyTitleMaxLength,
    this.vacancyDescriptionMaxLength,
    this.vacancyLocationMaxLength,
    this.vacancyFieldNameMaxLength,
  });

  factory AppOptionsModel.fromJson(Map<String, dynamic> json) =>
      _$AppOptionsModelFromJson(json);

  final int? hiringPostMinDurationMinutes;
  final int? hiringPostMaxDurationMinutes;
  final int? hiringPostDefaultDurationMinutes;
  final int? hiringPostMaxWorkers;
  final int? orderMaxCrewSize;
  final int? serviceMaxQuestions;
  final int? serviceImageSlots;
  final int? serviceVideoMaxSeconds;
  final int? serviceVideoMaxBytes;
  final int? imageMaxBytes;
  final int? imageUploadQuality;
  final int? imageUploadMaxWidth;
  final int? maxDaysAhead;
  final int? customerBookingMaxDaysAhead;
  final int? vacancyMaxOpenings;
  final int? vacancyMaxContractMonths;
  final int? vacancyMaxFields;
  final int? vacancyTitleMaxLength;
  final int? vacancyDescriptionMaxLength;
  final int? vacancyLocationMaxLength;
  final int? vacancyFieldNameMaxLength;

  AppOptions toEntity() {
    const d = AppOptions.defaults;
    return AppOptions(
      hiringPostMinDurationMinutes:
          hiringPostMinDurationMinutes ?? d.hiringPostMinDurationMinutes,
      hiringPostMaxDurationMinutes:
          hiringPostMaxDurationMinutes ?? d.hiringPostMaxDurationMinutes,
      hiringPostDefaultDurationMinutes:
          hiringPostDefaultDurationMinutes ??
          d.hiringPostDefaultDurationMinutes,
      hiringPostMaxWorkers: hiringPostMaxWorkers ?? d.hiringPostMaxWorkers,
      orderMaxCrewSize: orderMaxCrewSize ?? d.orderMaxCrewSize,
      serviceMaxQuestions: serviceMaxQuestions ?? d.serviceMaxQuestions,
      serviceImageSlots: serviceImageSlots ?? d.serviceImageSlots,
      serviceVideoMaxSeconds:
          serviceVideoMaxSeconds ?? d.serviceVideoMaxSeconds,
      serviceVideoMaxBytes: serviceVideoMaxBytes ?? d.serviceVideoMaxBytes,
      imageMaxBytes: imageMaxBytes ?? d.imageMaxBytes,
      imageUploadQuality: imageUploadQuality ?? d.imageUploadQuality,
      imageUploadMaxWidth: imageUploadMaxWidth ?? d.imageUploadMaxWidth,
      maxDaysAhead: maxDaysAhead ?? d.maxDaysAhead,
      customerBookingMaxDaysAhead:
          customerBookingMaxDaysAhead ?? d.customerBookingMaxDaysAhead,
      vacancyMaxOpenings: vacancyMaxOpenings ?? d.vacancyMaxOpenings,
      vacancyMaxContractMonths:
          vacancyMaxContractMonths ?? d.vacancyMaxContractMonths,
      vacancyMaxFields: vacancyMaxFields ?? d.vacancyMaxFields,
      vacancyTitleMaxLength: vacancyTitleMaxLength ?? d.vacancyTitleMaxLength,
      vacancyDescriptionMaxLength:
          vacancyDescriptionMaxLength ?? d.vacancyDescriptionMaxLength,
      vacancyLocationMaxLength:
          vacancyLocationMaxLength ?? d.vacancyLocationMaxLength,
      vacancyFieldNameMaxLength:
          vacancyFieldNameMaxLength ?? d.vacancyFieldNameMaxLength,
    );
  }
}
