/// What a UPI ID looks like — name@bank, e.g. ravi@okhdfcbank. The same rule the Service API applies
/// to a business's UPI ID and a worker's payout UPI, so a typo is caught before a round trip.
/// Matches the Rent server too, so an ID saved on the profile is one the Rent QR accepts.
final upiIdPattern = RegExp(
  r'^[a-zA-Z0-9._-]{2,256}@[a-zA-Z][a-zA-Z0-9]{1,63}$',
);

const upiIdHint = 'A UPI ID looks like name@bank, for example ravi@okhdfcbank.';

/// Why [value] is not a UPI ID that can be saved, or null when it is. A UPI ID is required: without
/// one a business cannot show a payment QR and a worker cannot be paid.
String? upiIdProblem(String? value, {required String missing}) {
  final text = value?.trim() ?? '';
  if (text.isEmpty) return missing;
  if (text.length > 100) return 'That UPI ID is too long.';
  return upiIdPattern.hasMatch(text) ? null : upiIdHint;
}
