class District {
  const District({
    required this.id,
    required this.name,
    required this.stateId,
    required this.stateName,
    this.centreLatitude,
    this.centreLongitude,
  });

  final String id;
  final String name;
  final String stateId;
  final String stateName;

  /// Where the district is. Null outside the curated states.
  ///
  /// Present so the app can suggest places as somebody types with no network call: the free
  /// geocoder does no prefix matching, so this cached list is what makes as-you-type work.
  final double? centreLatitude;
  final double? centreLongitude;

  bool get hasCentre => centreLatitude != null && centreLongitude != null;
}
