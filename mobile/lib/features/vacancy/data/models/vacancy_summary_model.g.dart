// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'vacancy_summary_model.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

VacancySummaryModel _$VacancySummaryModelFromJson(Map<String, dynamic> json) =>
    VacancySummaryModel(
      activePosts: (json['activePosts'] as num?)?.toInt() ?? 0,
      newCount: (json['newCount'] as num?)?.toInt() ?? 0,
      waitingCount: (json['waitingCount'] as num?)?.toInt() ?? 0,
      shortlistedCount: (json['shortlistedCount'] as num?)?.toInt() ?? 0,
      hiredCount: (json['hiredCount'] as num?)?.toInt() ?? 0,
    );
