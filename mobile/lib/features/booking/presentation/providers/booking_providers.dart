import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:zuno/features/auth/presentation/providers/auth_providers.dart';
import 'package:zuno/features/booking/data/datasources/booking_remote_datasource.dart';
import 'package:zuno/features/booking/data/repositories/booking_repository_impl.dart';
import 'package:zuno/features/booking/domain/repositories/booking_repository.dart';

part 'booking_providers.g.dart';

@Riverpod(keepAlive: true)
BookingRemoteDataSource bookingRemoteDataSource(Ref ref) =>
    BookingRemoteDataSource(ref.watch(dioClientProvider));

@Riverpod(keepAlive: true)
BookingRepository bookingRepository(Ref ref) => BookingRepositoryImpl(
  remoteDataSource: ref.watch(bookingRemoteDataSourceProvider),
);
