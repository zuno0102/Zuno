// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'booking_message_model.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

BookingMessageModel _$BookingMessageModelFromJson(Map<String, dynamic> json) =>
    BookingMessageModel(
      id: json['id'] as String,
      bookingId: json['bookingId'] as String,
      senderRole: json['senderRole'] as String,
      isMine: json['isMine'] as bool,
      senderName: json['senderName'] as String,
      body: json['body'] as String,
      sentAt: DateTime.parse(json['sentAt'] as String),
      readAt: json['readAt'] == null
          ? null
          : DateTime.parse(json['readAt'] as String),
    );

BookingThreadModel _$BookingThreadModelFromJson(Map<String, dynamic> json) =>
    BookingThreadModel(
      bookingId: json['bookingId'] as String,
      title: json['title'] as String,
      counterpartName: json['counterpartName'] as String,
      scheduledDate: DateTime.parse(json['scheduledDate'] as String),
      bookingStatus: json['bookingStatus'] as String,
      counterpartLogoUrl: json['counterpartLogoUrl'] as String?,
      lastMessage: json['lastMessage'] as String?,
      lastMessageAt: json['lastMessageAt'] == null
          ? null
          : DateTime.parse(json['lastMessageAt'] as String),
      lastMessageIsMine: json['lastMessageIsMine'] as bool? ?? false,
      unreadCount: (json['unreadCount'] as num?)?.toInt() ?? 0,
    );
