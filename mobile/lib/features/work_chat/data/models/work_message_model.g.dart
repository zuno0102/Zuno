// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'work_message_model.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

WorkMessageModel _$WorkMessageModelFromJson(Map<String, dynamic> json) =>
    WorkMessageModel(
      id: json['id'] as String,
      counterpartId: json['counterpartId'] as String,
      senderRole: json['senderRole'] as String,
      isMine: json['isMine'] as bool,
      senderName: json['senderName'] as String,
      body: json['body'] as String,
      sentAt: DateTime.parse(json['sentAt'] as String),
      readAt: json['readAt'] == null
          ? null
          : DateTime.parse(json['readAt'] as String),
    );

WorkThreadModel _$WorkThreadModelFromJson(Map<String, dynamic> json) =>
    WorkThreadModel(
      counterpartId: json['counterpartId'] as String,
      counterpartName: json['counterpartName'] as String,
      lastMessage: json['lastMessage'] as String,
      lastMessageAt: DateTime.parse(json['lastMessageAt'] as String),
      counterpartImageUrl: json['counterpartImageUrl'] as String?,
      lastMessageIsMine: json['lastMessageIsMine'] as bool? ?? false,
      unreadCount: (json['unreadCount'] as num?)?.toInt() ?? 0,
    );
