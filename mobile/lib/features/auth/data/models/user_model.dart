import 'package:json_annotation/json_annotation.dart';
import 'package:zuno/features/auth/domain/entities/user.dart';

part 'user_model.g.dart';

@JsonSerializable()
class UserModel {
  const UserModel({
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

  factory UserModel.fromJson(Map<String, dynamic> json) =>
      _$UserModelFromJson(json);

  final String id;
  final String? email;
  final String? phoneNumber;
  final String firstName;
  final String lastName;
  final String? profileImageUrl;
  final String role;
  final bool emailConfirmed;
  final bool phoneNumberConfirmed;

  Map<String, dynamic> toJson() => _$UserModelToJson(this);

  User toEntity() => User(
    id: id,
    email: email,
    phoneNumber: phoneNumber,
    firstName: firstName,
    lastName: lastName,
    profileImageUrl: profileImageUrl,
    role: role,
    emailConfirmed: emailConfirmed,
    phoneNumberConfirmed: phoneNumberConfirmed,
  );
}
