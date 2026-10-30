/// Where the Rent service lives, and its paths.
///
/// Rent is its own server with its own database, signed in with the same account as the rest of
/// the app — so its address is configured on its own: `--dart-define=RENT_API_BASE_URL=...`.
/// Defaults to the Android-emulator alias for the host machine, port 5057.
class RentApi {
  const RentApi._();

  static const String baseUrl = String.fromEnvironment(
    'RENT_API_BASE_URL',
    defaultValue: 'http://10.0.2.2:5057',
  );

  static const String categoriesPath = '/api/v1/rental-categories';
  static const String priceTypesPath = '/api/v1/rental-price-types';
  static const String myItemsPath = '/api/v1/business/rentals';
  static const String summaryPath = '$myItemsPath/summary';
  static const String stockPath = '$myItemsPath/stock';

  static String itemOrdersPath(String id) => '$myItemsPath/$id/orders';

  /// The business's UPI ID, which its order QR is made from.
  static const String paymentSettingsPath = '$myItemsPath/payment-settings';

  /// The words for advances and payment methods, from the server's tables.
  static const String paymentOptionsPath = '/api/v1/rental-payment-options';

  /// The business's name, logo and verification, refreshed from its Service profile.
  static const String profileSyncPath = '$myItemsPath/profile/sync';

  // The customer side.
  static const String browsePath = '/api/v1/rentals';
  static const String browseHomePath = '$browsePath/home';
  static const String browseBannersPath = '$browsePath/banners';

  static String browseItemPath(String id) => '$browsePath/$id';

  static String browseAvailabilityPath(String id) =>
      '$browsePath/$id/availability';

  static const String myRentalsPath = '/api/v1/customer/rental-orders';
  static const String myRentalThreadsPath = '$myRentalsPath/threads';

  static String myRentalPath(String id) => '$myRentalsPath/$id';

  static String myRentalCancelPath(String id) => '$myRentalsPath/$id/cancel';

  static String myRentalHistoryPath(String id) => '$myRentalsPath/$id/history';

  static String myRentalMessagesPath(String id) =>
      '$myRentalsPath/$id/messages';

  /// Starts an online payment: the advance while awaited, otherwise what is due.
  static String myRentalCheckoutPath(String id) =>
      '$myRentalsPath/$id/checkout';

  /// The payment window's answer, checked by the server.
  static String myRentalPayPath(String id) => '$myRentalsPath/$id/pay';

  static const String ordersPath = '/api/v1/business/rental-orders';
  static const String orderCountsPath = '$ordersPath/counts';
  static const String orderThreadsPath = '$ordersPath/threads';

  static String orderPath(String id) => '$ordersPath/$id';

  static String orderAddOnPath(String id) => '$ordersPath/$id/add-on';

  static String orderHistoryPath(String id) => '$ordersPath/$id/history';

  static String itemAvailabilityPath(String id) =>
      '$myItemsPath/$id/availability';

  static String orderStatusPath(String id) => '$ordersPath/$id/status';

  /// Money taken for an order — cash or UPI QR — or given back.
  static String orderPaymentsPath(String id) => '$ordersPath/$id/payments';

  static String orderMessagesPath(String id) => '$ordersPath/$id/messages';

  static String itemPath(String id) => '$myItemsPath/$id';

  static String itemStockPath(String id) => '$myItemsPath/$id/stock';

  static String itemImagePath(String id, int slot) =>
      '$myItemsPath/$id/images/$slot';

  static String itemVideoPath(String id) => '$myItemsPath/$id/video';

  /// A photo or video path the Rent server returned, as a full address.
  static String mediaUrl(String path) => '$baseUrl$path';
}
