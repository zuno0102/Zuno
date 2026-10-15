import 'package:json_annotation/json_annotation.dart';
import 'package:zuno/features/customer/data/models/service_listing_model.dart';
import 'package:zuno/features/customer/domain/entities/home_sections.dart';

part 'home_sections_model.g.dart';

@JsonSerializable(createToJson: false)
class HomeSectionsModel {
  const HomeSectionsModel({
    this.forYou = const [],
    this.mostBooked = const [],
    this.more = const [],
    this.topRated = const [],
    this.all = const [],
  });

  factory HomeSectionsModel.fromJson(Map<String, dynamic> json) =>
      _$HomeSectionsModelFromJson(json);

  final List<ServiceListingModel> forYou;
  final List<ServiceListingModel> mostBooked;
  final List<ServiceListingModel> more;
  final List<ServiceListingModel> topRated;
  final List<ServiceListingModel> all;

  HomeSections toEntity() => HomeSections(
    forYou: forYou.map((m) => m.toEntity()).toList(),
    mostBooked: mostBooked.map((m) => m.toEntity()).toList(),
    more: more.map((m) => m.toEntity()).toList(),
    topRated: topRated.map((m) => m.toEntity()).toList(),
    all: all.map((m) => m.toEntity()).toList(),
  );
}
