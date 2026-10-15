// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'hiring_business_model.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

HiringBusinessModel _$HiringBusinessModelFromJson(Map<String, dynamic> json) =>
    HiringBusinessModel(
      id: json['id'] as String,
      businessName: json['businessName'] as String,
      levelName: json['levelName'] as String,
      logoUrl: json['logoUrl'] as String?,
      city: json['city'] as String?,
      state: json['state'] as String?,
      level: (json['level'] as num?)?.toInt() ?? 1,
      isVerified: json['isVerified'] as bool? ?? false,
      pay: json['pay'] == null
          ? null
          : WorkerFacingTrustModel.fromJson(
              json['pay'] as Map<String, dynamic>,
            ),
      openPosts:
          (json['openPosts'] as List<dynamic>?)
              ?.map((e) => HiringPostModel.fromJson(e as Map<String, dynamic>))
              .toList() ??
          const [],
    );
