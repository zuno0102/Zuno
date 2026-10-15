import 'package:json_annotation/json_annotation.dart';
import 'package:zuno/features/business_owner/domain/entities/worker_busy_period.dart';

part 'worker_busy_period_model.g.dart';

@JsonSerializable(createToJson: false)
class WorkerBusyPeriodModel {
  const WorkerBusyPeriodModel({required this.startsAt, required this.endsAt});

  factory WorkerBusyPeriodModel.fromJson(Map<String, dynamic> json) =>
      _$WorkerBusyPeriodModelFromJson(json);

  final DateTime startsAt;
  final DateTime endsAt;

  WorkerBusyPeriod toEntity() =>
      WorkerBusyPeriod(startsAt: startsAt.toLocal(), endsAt: endsAt.toLocal());
}
