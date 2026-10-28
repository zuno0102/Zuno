/// Everything the vacancy forms need from the server — job types and prices from its tables, and
/// the upload rules from its settings — so none of it is built into the app.
class VacancyOptions {
  const VacancyOptions({
    required this.jobTypes,
    required this.feePlans,
    required this.allowedFileExtensions,
    required this.maxFileSizeBytes,
  });

  final List<VacancyJobType> jobTypes;
  final List<VacancyFeePlan> feePlans;

  /// "pdf", "jpg" … — what a File field's picker offers.
  final List<String> allowedFileExtensions;
  final int maxFileSizeBytes;
}

class VacancyJobType {
  const VacancyJobType({
    required this.id,
    required this.name,
    required this.hasFixedLength,
  });

  final String id;
  final String name;

  /// A contract or internship: the form must ask how many months.
  final bool hasFixedLength;
}

class VacancyFeePlan {
  const VacancyFeePlan({
    required this.id,
    required this.name,
    required this.amount,
    required this.listingDays,
  });

  final String id;
  final String name;
  final double amount;
  final int listingDays;
}
