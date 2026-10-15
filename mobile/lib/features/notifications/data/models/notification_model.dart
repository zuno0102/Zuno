import 'package:json_annotation/json_annotation.dart';
import 'package:zuno/features/notifications/domain/entities/app_notification.dart';

part 'notification_model.g.dart';

@JsonSerializable(createToJson: false)
class NotificationModel {
  const NotificationModel({
    required this.id,
    required this.kind,
    required this.title,
    required this.body,
    required this.target,
    required this.isUnread,
    required this.createdAt,
    this.targetId,
  });

  factory NotificationModel.fromJson(Map<String, dynamic> json) =>
      _$NotificationModelFromJson(json);

  final String id;
  final String kind;
  final String title;
  final String body;
  final String target;
  final String? targetId;
  final bool isUnread;
  final DateTime createdAt;

  AppNotification toEntity() => AppNotification(
    id: id,
    kind: kind,
    title: title,
    body: body,
    target: NotificationTarget.fromName(target),
    targetId: targetId,
    isUnread: isUnread,
    createdAt: createdAt,
  );
}

/// The badge number, in its own envelope.
///
/// A wrapper rather than a bare integer so a later addition — a per-kind breakdown, a "since"
/// marker — does not change the shape this already parses.
@JsonSerializable(createToJson: false)
class NotificationCountModel {
  const NotificationCountModel({required this.unreadCount});

  factory NotificationCountModel.fromJson(Map<String, dynamic> json) =>
      _$NotificationCountModelFromJson(json);

  final int unreadCount;
}
