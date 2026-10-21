import 'package:json_annotation/json_annotation.dart';
import 'package:zuno/features/booking/domain/entities/booking_message.dart';
import 'package:zuno/features/work_chat/domain/entities/work_thread.dart';

part 'work_message_model.g.dart';

@JsonSerializable(createToJson: false)
class WorkMessageModel {
  const WorkMessageModel({
    required this.id,
    required this.counterpartId,
    required this.senderRole,
    required this.isMine,
    required this.senderName,
    required this.body,
    required this.sentAt,
    this.readAt,
  });

  factory WorkMessageModel.fromJson(Map<String, dynamic> json) =>
      _$WorkMessageModelFromJson(json);

  final String id;
  final String counterpartId;
  final String senderRole;
  final bool isMine;
  final String senderName;
  final String body;
  final DateTime sentAt;
  final DateTime? readAt;

  /// As a chat message, so the shared chat screen draws it like any other conversation. The bubble
  /// reads only who sent it, what they said and when it was read; the thread it belongs to (here
  /// the other side's profile) rides in the id field the booking chat uses for its booking.
  BookingMessage toChatMessage() => BookingMessage(
    id: id,
    bookingId: counterpartId,
    senderRole: senderRole,
    isMine: isMine,
    senderName: senderName,
    body: body,
    sentAt: sentAt,
    readAt: readAt,
  );
}

@JsonSerializable(createToJson: false)
class WorkThreadModel {
  const WorkThreadModel({
    required this.counterpartId,
    required this.counterpartName,
    required this.lastMessage,
    required this.lastMessageAt,
    this.counterpartImageUrl,
    this.lastMessageIsMine = false,
    this.unreadCount = 0,
  });

  factory WorkThreadModel.fromJson(Map<String, dynamic> json) =>
      _$WorkThreadModelFromJson(json);

  final String counterpartId;
  final String counterpartName;
  final String? counterpartImageUrl;
  final String lastMessage;
  final DateTime lastMessageAt;
  final bool lastMessageIsMine;
  final int unreadCount;

  WorkThread toEntity() => WorkThread(
    counterpartId: counterpartId,
    counterpartName: counterpartName,
    counterpartImageUrl: counterpartImageUrl,
    lastMessage: lastMessage,
    lastMessageAt: lastMessageAt,
    lastMessageIsMine: lastMessageIsMine,
    unreadCount: unreadCount,
  );
}
