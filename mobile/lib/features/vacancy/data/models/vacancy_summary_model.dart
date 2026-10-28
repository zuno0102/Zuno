import 'package:json_annotation/json_annotation.dart';
import 'package:zuno/features/vacancy/domain/entities/vacancy_summary.dart';

part 'vacancy_summary_model.g.dart';

@JsonSerializable(createToJson: false)
class VacancySummaryModel {
  const VacancySummaryModel({
    this.activePosts = 0,
    this.newCount = 0,
    this.waitingCount = 0,
    this.shortlistedCount = 0,
    this.hiredCount = 0,
  });

  factory VacancySummaryModel.fromJson(Map<String, dynamic> json) =>
      _$VacancySummaryModelFromJson(json);

  final int activePosts;
  final int newCount;
  final int waitingCount;
  final int shortlistedCount;
  final int hiredCount;

  VacancySummary toEntity() => VacancySummary(
    activePosts: activePosts,
    newCount: newCount,
    waitingCount: waitingCount,
    shortlistedCount: shortlistedCount,
    hiredCount: hiredCount,
  );
}
