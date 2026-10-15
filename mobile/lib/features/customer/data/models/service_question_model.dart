import 'package:json_annotation/json_annotation.dart';
import 'package:zuno/features/customer/domain/entities/service_question.dart';

part 'service_question_model.g.dart';

@JsonSerializable(createToJson: false)
class ServiceQuestionModel {
  const ServiceQuestionModel({
    required this.id,
    required this.prompt,
    required this.isRequired,
    required this.sortOrder,
  });

  factory ServiceQuestionModel.fromJson(Map<String, dynamic> json) =>
      _$ServiceQuestionModelFromJson(json);

  final String id;
  final String prompt;
  final bool isRequired;
  final int sortOrder;

  ServiceQuestion toEntity() => ServiceQuestion(
    id: id,
    prompt: prompt,
    isRequired: isRequired,
    sortOrder: sortOrder,
  );
}
