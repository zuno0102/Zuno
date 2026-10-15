import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:zuno/features/admin/data/datasources/admin_catalog_remote_datasource.dart';
import 'package:zuno/features/admin/data/repositories/admin_catalog_repository_impl.dart';
import 'package:zuno/features/admin/domain/entities/catalog_category.dart';
import 'package:zuno/features/admin/domain/repositories/admin_catalog_repository.dart';
import 'package:zuno/features/auth/presentation/providers/auth_providers.dart';

part 'admin_catalog_notifier.g.dart';

@Riverpod(keepAlive: true)
AdminCatalogRemoteDataSource adminCatalogRemoteDataSource(Ref ref) =>
    AdminCatalogRemoteDataSource(ref.watch(dioClientProvider));

@Riverpod(keepAlive: true)
AdminCatalogRepository adminCatalogRepository(Ref ref) =>
    AdminCatalogRepositoryImpl(
      remoteDataSource: ref.watch(adminCatalogRemoteDataSourceProvider),
    );

/// The whole catalogue, and the app owner's edits to it.
@riverpod
class AdminCatalogNotifier extends _$AdminCatalogNotifier {
  @override
  Future<List<CatalogCategory>> build() =>
      ref.watch(adminCatalogRepositoryProvider).getCatalog();

  /// Adds a category, or edits one. Pass [id] to edit.
  ///
  /// Reloads the whole catalogue rather than patching the one row: a rename changes the slug the
  /// server worked out, and a save can shift the display order of everything around it. Errors
  /// propagate so the sheet that called this can show what the server said and keep the form open.
  Future<void> saveCategory({
    String? id,
    required String name,
    String? description,
    required int displayOrder,
    required bool isActive,
  }) async {
    await ref
        .read(adminCatalogRepositoryProvider)
        .saveCategory(
          id: id,
          name: name,
          description: description,
          displayOrder: displayOrder,
          isActive: isActive,
        );
    await _refresh();
  }

  /// Adds a sub-category under [categoryId], or edits one. Pass [id] to edit.
  Future<void> saveSubCategory({
    String? id,
    required String categoryId,
    required String name,
    required int displayOrder,
    required bool isActive,
  }) async {
    await ref
        .read(adminCatalogRepositoryProvider)
        .saveSubCategory(
          id: id,
          categoryId: categoryId,
          name: name,
          displayOrder: displayOrder,
          isActive: isActive,
        );
    await _refresh();
  }

  Future<void> _refresh() async {
    state = AsyncData(await ref.read(adminCatalogRepositoryProvider).getCatalog());
  }
}
