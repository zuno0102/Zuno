import 'package:zuno/features/catalog/domain/entities/district.dart';

/// How a customer's location was set — which decides whether the app may change it by itself.
/// The same three words the server keeps.
enum CustomerLocationSource {
  /// Read from the phone. Updated on the next open if they have moved.
  gps('Gps'),

  /// Picked by hand. Left alone.
  manual('Manual'),

  /// Cleared to everywhere on purpose. Left alone too.
  cleared('Cleared');

  const CustomerLocationSource(this.code);

  final String code;

  static CustomerLocationSource? fromCode(String? code) =>
      values.where((s) => s.code == code).firstOrNull;
}

/// The location kept in the customer's account; [district] null for everywhere or never set.
class SavedCustomerLocation {
  const SavedCustomerLocation({this.district, this.source});

  final District? district;
  final CustomerLocationSource? source;
}
