import 'package:json_annotation/json_annotation.dart';
import 'package:zuno/features/booking/domain/entities/rating.dart';

part 'rating_model.g.dart';

@JsonSerializable(createToJson: false)
class RatingModel {
  const RatingModel({
    required this.score,
    required this.createdDate,
    this.comment,
  });

  factory RatingModel.fromJson(Map<String, dynamic> json) =>
      _$RatingModelFromJson(json);

  final int score;
  final String? comment;
  final DateTime createdDate;

  Rating toEntity() =>
      Rating(score: score, comment: comment, createdDate: createdDate);
}
