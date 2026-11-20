/// Where the Marketplace service lives, and its paths.
///
/// Marketplace is its own server with its own database, signed in with the same account as the
/// rest of the app — so its address is configured on its own:
/// `--dart-define=MARKETPLACE_API_BASE_URL=...`. Defaults to the Android-emulator alias for the
/// host machine, port 5058.
class MarketplaceApi {
  const MarketplaceApi._();

  static const String baseUrl = String.fromEnvironment(
    'MARKETPLACE_API_BASE_URL',
    defaultValue: 'http://10.0.2.2:5058',
  );

  static const String categoriesPath = '/api/v1/marketplace-categories';
  static const String optionsPath = '/api/v1/marketplace-options';

  static const String myPostsPath = '/api/v1/business/marketplace';
  static const String summaryPath = '$myPostsPath/summary';
  static const String profileSyncPath = '$myPostsPath/profile/sync';

  static String postPath(String id) => '$myPostsPath/$id';

  static String postStatusPath(String id) => '$myPostsPath/$id/status';

  static String postStockPath(String id) => '$myPostsPath/$id/stock';

  static String postVariantsPath(String id) => '$myPostsPath/$id/variants';

  static String postImagePath(String id, int slot) =>
      '$myPostsPath/$id/images/$slot';

  /// A colour / size's own photo slot.
  static String postVariantImagePath(String id, String variantId, int slot) =>
      '$myPostsPath/$id/variants/$variantId/images/$slot';

  /// The business's product orders and how its customers may pay.
  static const String ordersPath = '$myPostsPath/orders';

  static String orderPath(String id) => '$ordersPath/$id';

  static String orderStatusPath(String id) => '$ordersPath/$id/status';

  static String orderShipPath(String id) => '$ordersPath/$id/ship';

  static String orderReceiptPath(String id) => '$ordersPath/$id/receipt';

  static const String paymentSettingsPath = '$myPostsPath/payment-settings';

  /// B2B requests buyers send on the business's lots.
  static const String b2bRequestsPath = '$myPostsPath/b2b-requests';

  static String b2bRequestAnswerPath(String id, {required bool accept}) =>
      '$b2bRequestsPath/$id/${accept ? 'accept' : 'decline'}';

  /// What customers browse, save, order and ask for.
  static const String customerPath = '/api/v1/marketplace';
  static const String homePath = '$customerPath/home';
  static const String searchPath = '$customerPath/posts';

  static String customerPostPath(String id) => '$searchPath/$id';

  static const String favouritesPath = '$customerPath/favourites';

  static String favouritePath(String postId) => '$favouritesPath/$postId';

  static const String myOrdersPath = '$customerPath/orders';

  static String myOrderPath(String id) => '$myOrdersPath/$id';

  static String myOrderPaymentPath(String id) => '$myOrdersPath/$id/payment';

  static String myOrderPaymentConfirmPath(String id) =>
      '$myOrdersPath/$id/payment/confirm';

  static String myOrderCancelPath(String id) => '$myOrdersPath/$id/cancel';

  static String myOrderReviewPath(String id) => '$myOrdersPath/$id/review';

  static const String myB2BRequestsPath = '$customerPath/b2b-requests';

  static const String adminCategoriesPath =
      '/api/v1/admin/marketplace/categories';

  static String adminCategoryPath(String id) => '$adminCategoriesPath/$id';

  static String adminSubCategoriesPath(String categoryId) =>
      '$adminCategoriesPath/$categoryId/sub-categories';

  static String adminSubCategoryPath(String categoryId, String subId) =>
      '$adminCategoriesPath/$categoryId/sub-categories/$subId';

  static String adminFieldsPath(String categoryId) =>
      '$adminCategoriesPath/$categoryId/fields';

  static String adminFieldPath(String categoryId, String fieldId) =>
      '$adminCategoriesPath/$categoryId/fields/$fieldId';

  /// A photo path the Marketplace server returned, as a full address.
  static String mediaUrl(String path) => '$baseUrl$path';
}
