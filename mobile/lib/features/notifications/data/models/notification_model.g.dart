// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'notification_model.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

NotificationModel _$NotificationModelFromJson(Map<String, dynamic> json) =>
    NotificationModel(
      id: json['id'] as String,
      kind: json['kind'] as String,
      title: json['title'] as String,
      body: json['body'] as String,
      target: json['target'] as String,
      isUnread: json['isUnread'] as bool,
      createdAt: DateTime.parse(json['createdAt'] as String),
      targetId: json['targetId'] as String?,
    );

NotificationCountModel _$NotificationCountModelFromJson(
  Map<String, dynamic> json,
) => NotificationCountModel(unreadCount: (json['unreadCount'] as num).toInt());
