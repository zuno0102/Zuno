import 'package:zuno/features/hiring_post/domain/entities/hiring_post.dart';
import 'package:zuno/shared/domain/business_trust.dart';

/// A business as a worker sees it, before deciding whether to give up a day for it.
///
/// Carries the pay record only. Customer star ratings are deliberately absent: how good the
/// food was tells a worker nothing about whether they will be paid.
class HiringBusiness {
  const HiringBusiness({
    required this.id,
    required this.businessName,
    required this.levelName,
    this.logoUrl,
    this.city,
    this.state,
    this.level = 1,
    this.isVerified = false,
    this.pay = const WorkerFacingTrust(),
    this.openPosts = const [],
  });

  final String id;
  final String businessName;
  final String? logoUrl;
  final String? city;
  final String? state;
  final int level;
  final String levelName;
  final bool isVerified;
  final WorkerFacingTrust pay;
  final List<HiringPost> openPosts;

  String? get location {
    final parts = [city, state].whereType<String>().where((s) => s.isNotEmpty);
    return parts.isEmpty ? null : parts.join(', ');
  }

  bool get hasEarnedLevel => level > 1;
}
