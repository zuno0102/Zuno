/// A star average and how many ratings it is built from.
///
/// The server sends no average until there are enough ratings to be fair, so a null [average]
/// means "too new to say" — never a rating of zero.
class StarRating {
  const StarRating({this.average, this.count = 0});

  final double? average;
  final int count;

  bool get isRated => count > 0;
}

/// One business's stars on each line it runs, Service and Rent.
///
/// Only worth showing apart from the overall rating when more than one line has been rated —
/// a business with only Service ratings is fully described by its overall stars.
class LineRatings {
  const LineRatings({
    this.service = const StarRating(),
    this.rent = const StarRating(),
  });

  /// Built from the four flat fields every business payload carries.
  factory LineRatings.fromFields({
    double? serviceAverage,
    int serviceCount = 0,
    double? rentAverage,
    int rentCount = 0,
  }) => LineRatings(
    service: StarRating(average: serviceAverage, count: serviceCount),
    rent: StarRating(average: rentAverage, count: rentCount),
  );

  /// The line names as the app's own tabs call them.
  static const serviceLabel = 'Service';
  static const rentLabel = 'Rent';

  final StarRating service;
  final StarRating rent;

  /// Each line that has at least one rating, by name, Service first.
  Map<String, StarRating> get rated => {
    if (service.isRated) serviceLabel: service,
    if (rent.isRated) rentLabel: rent,
  };

  /// Whether a per-line breakdown says anything the overall rating does not.
  bool get isSplit => rated.length > 1;
}
