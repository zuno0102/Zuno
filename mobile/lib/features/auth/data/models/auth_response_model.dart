import 'package:json_annotation/json_annotation.dart';
import 'package:zuno/features/auth/data/models/user_model.dart';
import 'package:zuno/features/auth/domain/entities/auth_tokens.dart';

part 'auth_response_model.g.dart';

@JsonSerializable()
class AuthResponseModel {
  const AuthResponseModel({
    required this.accessToken,
    required this.refreshToken,
    required this.accessTokenExpiresAt,
    required this.user,
  });

  factory AuthResponseModel.fromJson(Map<String, dynamic> json) =>
      _$AuthResponseModelFromJson(json);

  final String accessToken;
  final String refreshToken;
  final DateTime accessTokenExpiresAt;
  final UserModel user;

  Map<String, dynamic> toJson() => _$AuthResponseModelToJson(this);

  AuthTokens toEntity() => AuthTokens(
    accessToken: accessToken,
    refreshToken: refreshToken,
    accessTokenExpiresAt: accessTokenExpiresAt,
    user: user.toEntity(),
  );
}
