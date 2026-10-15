import 'package:json_annotation/json_annotation.dart';

part 'register_request_model.g.dart';

@JsonSerializable(includeIfNull: false, createFactory: false)
class RegisterRequestModel {
  const RegisterRequestModel({
    required this.password,
    required this.firstName,
    required this.lastName,
    required this.role,
    this.email,
    this.phoneNumber,
  });

  final String? email;
  final String? phoneNumber;
  final String password;
  final String firstName;
  final String lastName;
  final String role;

  Map<String, dynamic> toJson() => _$RegisterRequestModelToJson(this);
}
