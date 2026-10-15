import 'package:zuno/features/admin/data/datasources/admin_catalog_remote_datasource.dart';
import 'package:zuno/features/admin/domain/entities/catalog_category.dart';
import 'package:zuno/features/admin/domain/repositories/admin_catalog_repository.dart';

class AdminCatalogRepositoryImpl implements AdminCatalogRepository {
  AdminCatalogRepositoryImpl({
    required AdminCatalogRemoteDataSource remoteDataSource,
  }) : _remoteDataSource = remoteDataSource;

  final AdminCatalogRemoteDataSource _remoteDataSource;

  @override
  Future<List<CatalogCategory>> getCatalog() async =>
      (await _remoteDataSource.getCatalog()).map((m) => m.toEntity()).toList();

  @override
  Future<CatalogCategory> saveCategory({
    String? id,
    required String name,
    String? description,
    required int displayOrder,
    required bool isActive,
  }) async => (await _remoteDataSource.saveCategory(
    id: id,
    name: name,
    description: description,
    displayOrder: displayOrder,
    isActive: isActive,
  )).toEntity();

  @override
  Future<CatalogSubCategory> saveSubCategory({
    String? id,
    required String categoryId,
    required String name,
    required int displayOrder,
    required bool isActive,
  }) async => (await _remoteDataSource.saveSubCategory(
    id: id,
    categoryId: categoryId,
    name: name,
    displayOrder: displayOrder,
    isActive: isActive,
  )).toEntity();
}
