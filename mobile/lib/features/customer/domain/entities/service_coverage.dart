/// Whether a service is offered at the spot the customer pinned.
class ServiceCoverage {
  const ServiceCoverage({
    required this.isAvailable,
    required this.servedDistricts,
  });

  factory ServiceCoverage.fromJson(Map<String, dynamic> json) =>
      ServiceCoverage(
        isAvailable: json['isAvailable'] as bool? ?? true,
        servedDistricts: (json['servedDistricts'] as List<dynamic>? ?? const [])
            .map((e) => e as String)
            .toList(),
      );

  final bool isAvailable;

  /// The districts the business chose to work in, for telling the customer where it does go.
  final List<String> servedDistricts;
}
