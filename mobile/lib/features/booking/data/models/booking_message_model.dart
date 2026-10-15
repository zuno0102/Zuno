import 'package:json_annotation/json_annotation.dart';
import 'package:zuno/features/booking/domain/entities/booking_message.dart';

part 'booking_message_model.g.dart';

@JsonSerializable(createToJson: false)
class BookingMessageModel {
  const BookingMessageModel({
    required this.id,
    required this.bookingId,
    required this.senderRole,
    required this.isMine,
    required this.senderName,
    required this.body,
    required this.sentAt,
    this.readAt,
  });

  factory BookingMessageModel.fromJson(Map<String, dynamic> json) =>
      _$BookingMessageModelFromJson(json);

  final String id;
  final String bookingId;
  final String senderRole;
  final bool isMine;
  final String senderName;
  final String body;
  final DateTime sentAt;
  final DateTime? readAt;

  BookingMessage toEntity() => BookingMessage(
    id: id,
    bookingId: bookingId,
    senderRole: senderRole,
    isMine: isMine,
    senderName: senderName,
    body: body,
    sentAt: sentAt,
    readAt: readAt,
  );
}

@JsonSerializable(createToJson: false)
class BookingThreadModel {
  const BookingThreadModel({
    required this.bookingId,
    required this.title,
    required this.counterpartName,
    required this.scheduledDate,
    required this.bookingStatus,
    this.counterpartLogoUrl,
    this.lastMessage,
    this.lastMessageAt,
    this.lastMessageIsMine = false,
    this.unreadCount = 0,
  });

  factory BookingThreadModel.fromJson(Map<String, dynamic> json) =>
      _$BookingThreadModelFromJson(json);

  final String bookingId;
  final String title;
  final String counterpartName;
  final String? counterpartLogoUrl;
  final DateTime scheduledDate;
  final String bookingStatus;
  final String? lastMessage;
  final DateTime? lastMessageAt;
  final bool lastMessageIsMine;
  final int unreadCount;

  BookingThread toEntity() => BookingThread(
    bookingId: bookingId,
    title: title,
    counterpartName: counterpartName,
    counterpartLogoUrl: counterpartLogoUrl,
    scheduledDate: scheduledDate,
    bookingStatus: bookingStatus,
    lastMessage: lastMessage,
    lastMessageAt: lastMessageAt,
    lastMessageIsMine: lastMessageIsMine,
    unreadCount: unreadCount,
  );
}
