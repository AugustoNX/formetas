import '../../domain/entities/category_entity.dart';
import '../../domain/repositories/category_repository.dart';
import '../datasources/category_remote_datasource.dart';

class CategoryRepositoryImpl implements CategoryRepository {
  CategoryRepositoryImpl(this._dataSource);

  final CategoryRemoteDataSource _dataSource;

  @override
  Stream<List<CategoryEntity>> watchCustomCategories(String userId) =>
      _dataSource.watchCategories(userId);

  @override
  Future<List<CategoryEntity>> getCustomCategories(String userId) =>
      _dataSource.getCategories(userId);

  @override
  Future<void> createCategory(CategoryEntity category) =>
      _dataSource.createCategory(category);

  @override
  Future<void> updateCategory(CategoryEntity category) =>
      _dataSource.updateCategory(category);

  @override
  Future<void> deleteCategory(String userId, String id) =>
      _dataSource.deleteCategory(userId, id);
}
