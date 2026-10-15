// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'service_question_model.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

ServiceQuestionModel _$ServiceQuestionModelFromJson(
  Map<String, dynamic> json,
) => ServiceQuestionModel(
  id: json['id'] as String,
  prompt: json['prompt'] as String,
  isRequired: json['isRequired'] as bool,
  sortOrder: (json['sortOrder'] as num).toInt(),
);
