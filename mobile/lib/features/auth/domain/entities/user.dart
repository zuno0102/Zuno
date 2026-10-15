class User {
  const User({
    required this.id,
    required this.firstName,
    required this.lastName,
    required this.role,
    required this.emailConfirmed,
    required this.phoneNumberConfirmed,
    this.email,
    this.phoneNumber,
    this.profileImageUrl,
  });

  final String id;
  final String? email;
  final String? phoneNumber;
  final String firstName;
  final String lastName;
  final String? profileImageUrl;
  final String role;
  final bool emailConfirmed;
  final bool phoneNumberConfirmed;

  String get fullName => '$firstName $lastName';
}
