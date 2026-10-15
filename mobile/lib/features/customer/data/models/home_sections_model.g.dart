// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'home_sections_model.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

HomeSectionsModel _$HomeSectionsModelFromJson(
  Map<String, dynamic> json,
) => HomeSectionsModel(
  forYou:
      (json['forYou'] as List<dynamic>?)
          ?.map((e) => ServiceListingModel.fromJson(e as Map<String, dynamic>))
          .toList() ??
      const [],
  mostBooked:
      (json['mostBooked'] as List<dynamic>?)
          ?.map((e) => ServiceListingModel.fromJson(e as Map<String, dynamic>))
          .toList() ??
      const [],
  more:
      (json['more'] as List<dynamic>?)
          ?.map((e) => ServiceListingModel.fromJson(e as Map<String, dynamic>))
          .toList() ??
      const [],
  topRated:
      (json['topRated'] as List<dynamic>?)
          ?.map((e) => ServiceListingModel.fromJson(e as Map<String, dynamic>))
          .toList() ??
      const [],
  all:
      (json['all'] as List<dynamic>?)
          ?.map((e) => ServiceListingModel.fromJson(e as Map<String, dynamic>))
          .toList() ??
      const [],
);
