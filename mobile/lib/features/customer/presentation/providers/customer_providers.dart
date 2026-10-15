import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:zuno/features/auth/presentation/providers/auth_providers.dart';
import 'package:zuno/features/customer/data/datasources/customer_remote_datasource.dart';
import 'package:zuno/features/customer/data/repositories/customer_repository_impl.dart';
import 'package:zuno/features/customer/domain/entities/business_detail.dart';
import 'package:zuno/features/customer/domain/entities/service_detail.dart';
import 'package:zuno/features/customer/domain/repositories/customer_repository.dart';

part 'customer_providers.g.dart';

@Riverpod(keepAlive: true)
CustomerRemoteDataSource customerRemoteDataSource(Ref ref) =>
    CustomerRemoteDataSource(ref.watch(dioClientProvider));

@Riverpod(keepAlive: true)
CustomerRepository customerRepository(Ref ref) => CustomerRepositoryImpl(
  remoteDataSource: ref.watch(customerRemoteDataSourceProvider),
);

@riverpod
Future<BusinessDetail> businessDetail(Ref ref, String businessId) =>
    ref.watch(customerRepositoryProvider).getBusinessDetail(businessId);

@riverpod
Future<ServiceDetail> serviceDetail(Ref ref, String serviceId) =>
    ref.watch(customerRepositoryProvider).getServiceDetail(serviceId);
