/// The business's full-time hiring at a glance, for its home screen.
class VacancySummary {
  const VacancySummary({
    required this.activePosts,
    required this.newCount,
    required this.waitingCount,
    required this.shortlistedCount,
    required this.hiredCount,
  });

  /// Vacancies workers can see right now.
  final int activePosts;

  /// Applicants not opened yet, across every vacancy.
  final int newCount;
  final int waitingCount;
  final int shortlistedCount;
  final int hiredCount;
}
