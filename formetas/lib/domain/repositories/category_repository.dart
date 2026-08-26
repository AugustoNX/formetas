import '../entities/category_entity.dart';

abstract class CategoryRepository {
  Stream<List<CategoryEntity>> watchCustomCategories(String userId);
  Future<List<CategoryEntity>> getCustomCategories(String userId);
  Future<void> createCategory(CategoryEntity category);
  Future<void> updateCategory(CategoryEntity category);
  Future<void> deleteCategory(String userId, String id);
}
