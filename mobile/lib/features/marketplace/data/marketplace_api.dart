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

  static String postImagePath(String id, int slot) =>
      '$myPostsPath/$id/images/$slot';

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
