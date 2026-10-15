// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'rating_model.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

RatingModel _$RatingModelFromJson(Map<String, dynamic> json) => RatingModel(
  score: (json['score'] as num).toInt(),
  createdDate: DateTime.parse(json['createdDate'] as String),
  comment: json['comment'] as String?,
);
