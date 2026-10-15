import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:zuno/features/auth/presentation/providers/auth_providers.dart';
import 'package:zuno/features/business_owner/data/datasources/business_remote_datasource.dart';
import 'package:zuno/features/business_owner/data/repositories/business_repository_impl.dart';
import 'package:zuno/features/business_owner/domain/repositories/business_repository.dart';

part 'business_providers.g.dart';

@Riverpod(keepAlive: true)
BusinessRemoteDataSource businessRemoteDataSource(Ref ref) =>
    BusinessRemoteDataSource(ref.watch(dioClientProvider));

@Riverpod(keepAlive: true)
BusinessRepository businessRepository(Ref ref) => BusinessRepositoryImpl(
  remoteDataSource: ref.watch(businessRemoteDataSourceProvider),
);
