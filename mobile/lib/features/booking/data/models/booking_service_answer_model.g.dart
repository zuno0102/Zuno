// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'booking_service_answer_model.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

BookingServiceAnswerModel _$BookingServiceAnswerModelFromJson(
  Map<String, dynamic> json,
) => BookingServiceAnswerModel(
  id: json['id'] as String,
  questionPrompt: json['questionPrompt'] as String,
  answerText: json['answerText'] as String,
  sortOrder: (json['sortOrder'] as num).toInt(),
);
