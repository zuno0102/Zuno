import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:zuno/features/business_owner/domain/entities/business_dashboard.dart';
import 'package:zuno/features/business_owner/presentation/providers/business_providers.dart';

part 'business_dashboard_notifier.g.dart';

@riverpod
Future<BusinessDashboard> businessDashboard(Ref ref) async =>
    (await ref.watch(businessRemoteDataSourceProvider).getDashboard()).toEntity();
