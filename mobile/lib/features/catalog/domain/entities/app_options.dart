/// The limits the app's forms check before sending anything.
///
/// Comes from the server (`/app-options`), which reads the same platform settings it validates
/// against — so a form can never allow what the server would refuse. [AppOptions.defaults] holds the
/// values the server ships with, used until the first load and whenever it fails, so a form is never
/// left without a limit.
class AppOptions {
  const AppOptions({
    this.hiringPostMinDurationMinutes = 15,
    this.hiringPostMaxDurationMinutes = 1440,
    this.hiringPostDefaultDurationMinutes = 120,
    this.hiringPostMaxWorkers = 100,
    this.orderMaxCrewSize = 100,
    this.serviceMaxQuestions = 15,
    this.serviceImageSlots = 3,
    this.serviceVideoMaxSeconds = 30,
    this.serviceVideoMaxBytes = 25 * 1024 * 1024,
    this.imageMaxBytes = 5 * 1024 * 1024,
    this.imageUploadQuality = 85,
    this.imageUploadMaxWidth = 1600,
    this.maxDaysAhead = 365,
    this.customerBookingMaxDaysAhead = 90,
    this.vacancyMaxOpenings = 999,
    this.vacancyMaxContractMonths = 60,
    this.vacancyMaxFields = 15,
    this.vacancyTitleMaxLength = 150,
    this.vacancyDescriptionMaxLength = 2000,
    this.vacancyLocationMaxLength = 300,
    this.vacancyFieldNameMaxLength = 200,
  });

  static const defaults = AppOptions();

  final int hiringPostMinDurationMinutes;
  final int hiringPostMaxDurationMinutes;
  final int hiringPostDefaultDurationMinutes;
  final int hiringPostMaxWorkers;
  final int orderMaxCrewSize;
  final int serviceMaxQuestions;
  final int serviceImageSlots;
  final int serviceVideoMaxSeconds;
  final int serviceVideoMaxBytes;
  final int imageMaxBytes;

  /// JPEG quality, 1–100, a photo is compressed to before upload.
  final int imageUploadQuality;

  /// Widest a photo is sent at, in pixels.
  final int imageUploadMaxWidth;

  /// Furthest ahead a date picker reaches, in days.
  final int maxDaysAhead;

  /// Furthest ahead a customer may book a service, in days.
  final int customerBookingMaxDaysAhead;

  final int vacancyMaxOpenings;
  final int vacancyMaxContractMonths;
  final int vacancyMaxFields;
  final int vacancyTitleMaxLength;
  final int vacancyDescriptionMaxLength;
  final int vacancyLocationMaxLength;
  final int vacancyFieldNameMaxLength;

  /// "25MB" — the video size limit, as a form says it.
  String get serviceVideoMaxSize =>
      '${serviceVideoMaxBytes ~/ (1024 * 1024)}MB';

  /// The line under a service's photo and video slots.
  String get serviceMediaHint =>
      'Up to $serviceImageSlots photos and one video '
      '($serviceVideoMaxSeconds seconds, $serviceVideoMaxSize max).';

  /// Why a picked video was refused.
  String get serviceVideoTooLarge =>
      'Video must be $serviceVideoMaxSeconds seconds or shorter and under '
      '$serviceVideoMaxSize.';

  /// The last day a date picker offers, counted from [from].
  DateTime lastPickableDate(DateTime from) =>
      from.add(Duration(days: maxDaysAhead));
}
