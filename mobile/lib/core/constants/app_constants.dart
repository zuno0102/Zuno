class AppConstants {
  const AppConstants._();

  static const String appName = 'Zuno';

  /// Where the marketplace operates. Used only when an address has no country of its own — a
  /// saved country is never overwritten with it.
  static const String defaultCountry = 'India';

  static const List<String> selfRegistrableRoles = [
    'Customer',
    'BusinessOwner',
    'Worker',
  ];
}
