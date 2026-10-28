import 'dart:typed_data';

/// What the business fills in on the vacancy form. Create and edit send the same shape.
class VacancyDraft {
  const VacancyDraft({
    required this.title,
    this.description,
    required this.jobTypeId,
    required this.openings,
    required this.salaryMin,
    this.salaryMax,
    required this.payPeriod,
    required this.workingDaysPerWeek,
    this.shiftStart,
    this.shiftEnd,
    this.contractMonths,
    this.location,
    this.latitude,
    this.longitude,
    this.locationPrecision,
    required this.requirements,
  });

  final String title;
  final String? description;
  final String jobTypeId;
  final int openings;
  final double salaryMin;
  final double? salaryMax;
  final String payPeriod;
  final int workingDaysPerWeek;

  /// "HH:mm:ss".
  final String? shiftStart;
  final String? shiftEnd;
  final int? contractMonths;
  final String? location;
  final double? latitude;
  final double? longitude;
  final String? locationPrecision;
  final List<VacancyRequirementDraft> requirements;
}

class VacancyRequirementDraft {
  const VacancyRequirementDraft({
    required this.kind,
    required this.prompt,
    required this.isRequired,
  });

  final String kind;
  final String prompt;
  final bool isRequired;
}

/// What the worker sends for one requirement: typed text, or a picked file.
class VacancyAnswerDraft {
  const VacancyAnswerDraft({
    required this.requirementId,
    this.text,
    this.bytes,
    this.fileName,
  });

  final String requirementId;
  final String? text;
  final Uint8List? bytes;
  final String? fileName;
}
