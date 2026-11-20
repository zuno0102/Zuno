import 'package:dio/dio.dart';
import 'package:zuno/core/constants/api_constants.dart';
import 'package:zuno/core/network/dio_error_mapper.dart';
import 'package:zuno/features/business_plan/data/business_plan_models.dart';
import 'package:zuno/features/business_plan/domain/business_plan.dart';

/// The business's plan, from the Service API, which holds it over all three areas.
abstract interface class BusinessPlanRepository {
  Future<BusinessPlan> getPlan();

  /// Starts buying [planId] at its price now: the Razorpay order to pay.
  Future<PlanPayment> startPurchase(String planId);

  /// Confirms with Razorpay's proof; the plan then runs.
  Future<BusinessPlan> confirmPurchase(
    String subscriptionId, {
    String? paymentId,
    String? signature,
  });
}

class BusinessPlanRepositoryImpl implements BusinessPlanRepository {
  BusinessPlanRepositoryImpl(this._dio);

  final Dio _dio;

  @override
  Future<BusinessPlan> getPlan() => _run(() async {
    final response = await _dio.get<Map<String, dynamic>>(
      ApiConstants.businessPlanPath,
    );
    return BusinessPlanModel.fromJson(response.data!).toEntity();
  });

  @override
  Future<PlanPayment> startPurchase(String planId) => _run(() async {
    final response = await _dio.post<Map<String, dynamic>>(
      ApiConstants.businessPlanPurchasePath,
      data: {'planId': planId},
    );
    return PlanPaymentModel.fromJson(response.data!).toEntity();
  });

  @override
  Future<BusinessPlan> confirmPurchase(
    String subscriptionId, {
    String? paymentId,
    String? signature,
  }) => _run(() async {
    final response = await _dio.post<Map<String, dynamic>>(
      ApiConstants.businessPlanConfirmPath(subscriptionId),
      data: {'providerPaymentId': paymentId, 'signature': signature},
    );
    return BusinessPlanModel.fromJson(response.data!).toEntity();
  });

  Future<T> _run<T>(Future<T> Function() call) async {
    try {
      return await call();
    } on DioException catch (e) {
      throw mapDioExceptionToAppException(e);
    }
  }
}
