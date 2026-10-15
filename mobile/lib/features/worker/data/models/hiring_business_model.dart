import 'package:json_annotation/json_annotation.dart';
import 'package:zuno/features/hiring_post/data/models/hiring_post_model.dart';
import 'package:zuno/features/worker/domain/entities/hiring_business.dart';
import 'package:zuno/shared/data/business_trust_model.dart';
import 'package:zuno/shared/domain/business_trust.dart';

part 'hiring_business_model.g.dart';

@JsonSerializable(createToJson: false)
class HiringBusinessModel {
  const HiringBusinessModel({
    required this.id,
    required this.businessName,
    required this.levelName,
    this.logoUrl,
    this.city,
    this.state,
    this.level = 1,
    this.isVerified = false,
    this.pay,
    this.openPosts = const [],
  });

  factory HiringBusinessModel.fromJson(Map<String, dynamic> json) =>
      _$HiringBusinessModelFromJson(json);

  final String id;
  final String businessName;
  final String? logoUrl;
  final String? city;
  final String? state;
  final int level;
  final String levelName;
  final bool isVerified;
  final WorkerFacingTrustModel? pay;
  final List<HiringPostModel> openPosts;

  HiringBusiness toEntity() => HiringBusiness(
    id: id,
    businessName: businessName,
    logoUrl: logoUrl,
    city: city,
    state: state,
    level: level,
    levelName: levelName,
    isVerified: isVerified,
    pay: pay?.toEntity() ?? const WorkerFacingTrust(),
    openPosts: openPosts.map((p) => p.toEntity()).toList(),
  );
}
