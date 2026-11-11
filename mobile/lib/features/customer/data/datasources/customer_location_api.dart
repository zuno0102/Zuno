import 'package:dio/dio.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:zuno/core/constants/api_constants.dart';
import 'package:zuno/core/network/dio_error_mapper.dart';
import 'package:zuno/features/auth/presentation/providers/auth_providers.dart';
import 'package:zuno/features/catalog/domain/entities/district.dart';
import 'package:zuno/features/customer/domain/entities/customer_location.dart';

part 'customer_location_api.g.dart';

/// The server's side of the customer's location: which district a point is in, and the location
/// kept in their account so another phone they sign in on starts in the same place.
class CustomerLocationApi {
  CustomerLocationApi(this._dio);

  final Dio _dio;

  /// The district a point is in, or null when it is too far from every district Zuno knows.
  Future<District?> nearestDistrict(double latitude, double longitude) =>
      _run(() async {
        final response = await _dio.get<Map<String, dynamic>?>(
          ApiConstants.nearestDistrictPath,
          queryParameters: {'latitude': latitude, 'longitude': longitude},
        );
        final json = response.data;
        if (json == null || json['districtId'] == null) return null;
        return District(
          id: json['districtId'] as String,
          name: json['districtName'] as String,
          stateId: json['stateId'] as String,
          stateName: json['stateName'] as String,
        );
      });

  Future<SavedCustomerLocation> myLocation() => _run(() async {
    final response = await _dio.get<Map<String, dynamic>>(
      ApiConstants.customerLocationPath,
    );
    return _saved(response.data!);
  });

  /// Saves [district] (null for everywhere) and how it was set.
  Future<void> save(String? districtId, CustomerLocationSource source) =>
      _run(() async {
        await _dio.put<Map<String, dynamic>>(
          ApiConstants.customerLocationPath,
          data: {'districtId': districtId, 'source': source.code},
        );
      });

  static SavedCustomerLocation _saved(Map<String, dynamic> json) =>
      SavedCustomerLocation(
        district: json['districtId'] == null
            ? null
            : District(
                id: json['districtId'] as String,
                name: json['districtName'] as String,
                stateId: json['stateId'] as String,
                stateName: json['stateName'] as String,
              ),
        source: CustomerLocationSource.fromCode(json['source'] as String?),
      );

  Future<T> _run<T>(Future<T> Function() call) async {
    try {
      return await call();
    } on DioException catch (e) {
      throw mapDioExceptionToAppException(e);
    }
  }
}

@Riverpod(keepAlive: true)
CustomerLocationApi customerLocationApi(Ref ref) =>
    CustomerLocationApi(ref.watch(dioClientProvider));
