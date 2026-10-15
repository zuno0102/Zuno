import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:zuno/features/auth/presentation/providers/auth_providers.dart';
import 'package:zuno/features/hiring_post/data/datasources/hiring_post_remote_datasource.dart';
import 'package:zuno/features/hiring_post/data/repositories/hiring_post_repository_impl.dart';
import 'package:zuno/features/hiring_post/domain/repositories/hiring_post_repository.dart';

part 'hiring_post_providers.g.dart';

@Riverpod(keepAlive: true)
HiringPostRemoteDataSource hiringPostRemoteDataSource(Ref ref) =>
    HiringPostRemoteDataSource(ref.watch(dioClientProvider));

@Riverpod(keepAlive: true)
HiringPostRepository hiringPostRepository(Ref ref) => HiringPostRepositoryImpl(
  remoteDataSource: ref.watch(hiringPostRemoteDataSourceProvider),
);
