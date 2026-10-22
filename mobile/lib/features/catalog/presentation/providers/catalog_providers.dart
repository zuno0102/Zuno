import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:zuno/features/auth/presentation/providers/auth_providers.dart';
import 'package:zuno/features/catalog/data/datasources/catalog_remote_datasource.dart';
import 'package:zuno/features/catalog/domain/entities/district.dart';
import 'package:zuno/features/catalog/domain/entities/location_state.dart';
import 'package:zuno/features/catalog/domain/entities/order_stage.dart';
import 'package:zuno/features/catalog/domain/entities/service_category.dart';

part 'catalog_providers.g.dart';

@Riverpod(keepAlive: true)
CatalogRemoteDataSource catalogRemoteDataSource(Ref ref) =>
    CatalogRemoteDataSource(ref.watch(dioClientProvider));

/// Reference data — categories rarely change within a session, so this is kept alive
/// instead of being refetched every time a category picker opens.
@Riverpod(keepAlive: true)
Future<List<ServiceCategory>> serviceCategories(Ref ref) async =>
    (await ref.watch(catalogRemoteDataSourceProvider).getServiceCategories())
        .map((m) => m.toEntity())
        .toList();

/// How each order stage is named, coloured and ordered — reference data from the server, kept for
/// the session like the categories.
@Riverpod(keepAlive: true)
Future<List<OrderStage>> orderStages(Ref ref) async =>
    (await ref.watch(catalogRemoteDataSourceProvider).getOrderStages())
        .map((m) => m.toEntity())
        .toList();

/// India states — reference data, rarely changes within a session.
@Riverpod(keepAlive: true)
Future<List<LocationState>> locationStates(Ref ref) async =>
    (await ref.watch(catalogRemoteDataSourceProvider).getStates())
        .map((m) => m.toEntity())
        .toList();

/// Districts filtered to a set of selected state ids. Keyed by a sorted, comma-joined id
/// string (rather than the raw List) so repeated calls with the same selection hit the
/// cache instead of refetching — Dart Lists don't compare equal by value, but Strings do.
/// Auto-dispose (not keepAlive) since many different state combinations could be queried
/// across a session and there's no need to hold them all in memory indefinitely.
@riverpod
Future<List<District>> districtsForStates(Ref ref, String stateIdsCsv) async {
  final stateIds = stateIdsCsv.isEmpty ? <String>[] : stateIdsCsv.split(',');
  return (await ref
          .watch(catalogRemoteDataSourceProvider)
          .getDistricts(stateIds: stateIds))
      .map((m) => m.toEntity())
      .toList();
}

/// Every district in the country, cached for the session.
///
/// Fetched once and kept, because it powers the place suggestions that appear as somebody types.
/// The list is about 765 rows and never changes, so holding it is cheaper than a network call per
/// keystroke — which the free geocoder would refuse anyway, and which it cannot answer at all since
/// it does no prefix matching.
@Riverpod(keepAlive: true)
Future<List<District>> allDistricts(Ref ref) async =>
    (await ref.watch(catalogRemoteDataSourceProvider).getDistricts())
        .map((m) => m.toEntity())
        .toList();
