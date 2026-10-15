import 'package:json_annotation/json_annotation.dart';
import 'package:zuno/features/booking/domain/entities/booking_service_answer.dart';

part 'booking_service_answer_model.g.dart';

@JsonSerializable(createToJson: false)
class BookingServiceAnswerModel {
  const BookingServiceAnswerModel({
    required this.id,
    required this.questionPrompt,
    required this.answerText,
    required this.sortOrder,
  });

  factory BookingServiceAnswerModel.fromJson(Map<String, dynamic> json) =>
      _$BookingServiceAnswerModelFromJson(json);

  final String id;
  final String questionPrompt;
  final String answerText;
  final int sortOrder;

  BookingServiceAnswer toEntity() => BookingServiceAnswer(
    id: id,
    questionPrompt: questionPrompt,
    answerText: answerText,
    sortOrder: sortOrder,
  );
}
