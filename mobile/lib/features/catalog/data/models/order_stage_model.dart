import 'package:json_annotation/json_annotation.dart';
import 'package:zuno/features/catalog/domain/entities/order_stage.dart';

part 'order_stage_model.g.dart';

@JsonSerializable(createToJson: false)
class OrderStageModel {
  const OrderStageModel({
    required this.code,
    required this.label,
    this.sortOrder = 0,
    this.tone = '',
    this.showOnBookings = false,
    this.showOnWork = false,
  });

  factory OrderStageModel.fromJson(Map<String, dynamic> json) =>
      _$OrderStageModelFromJson(json);

  final String code;
  final String label;
  final int sortOrder;
  final String tone;
  final bool showOnBookings;
  final bool showOnWork;

  OrderStage toEntity() => OrderStage(
    code: code,
    label: label,
    sortOrder: sortOrder,
    tone: tone,
    showOnBookings: showOnBookings,
    showOnWork: showOnWork,
  );
}
