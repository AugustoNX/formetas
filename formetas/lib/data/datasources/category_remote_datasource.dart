import 'package:firebase_database/firebase_database.dart';

import '../../core/config/rtdb_helper.dart';
import '../../domain/entities/category_entity.dart';
import '../models/category_model.dart';

class CategoryRemoteDataSource {
  CategoryRemoteDataSource({FirebaseDatabase? database})
      : _database = database ?? RtdbHelper.database;

  final FirebaseDatabase _database;

  DatabaseReference _ref(String userId) =>
      _database.ref('users/$userId/categories');

  Stream<List<CategoryEntity>> watchCategories(String userId) {
    return _ref(userId).onValue.map((event) {
      final list = RtdbHelper.parseChildren(
        event.snapshot.value,
        (map, id) => CategoryModel.fromMap(map, id),
      );
      list.sort((a, b) => a.order.compareTo(b.order));
      return list;
    });
  }

  Future<List<CategoryEntity>> getCategories(String userId) async {
    final snapshot = await _ref(userId).get();
    final list = RtdbHelper.parseChildren(
      snapshot.value,
      (map, id) => CategoryModel.fromMap(map, id),
    );
    list.sort((a, b) => a.order.compareTo(b.order));
    return list;
  }

  Future<void> createCategory(CategoryEntity category) async {
    final data = CategoryModel.fromEntity(category).toMap();
    await _ref(category.userId).child(category.id).set(data);
  }

  Future<void> updateCategory(CategoryEntity category) async {
    final data = CategoryModel.fromEntity(category).toMap();
    await _ref(category.userId).child(category.id).update(data);
  }

  Future<void> deleteCategory(String userId, String id) async {
    await _ref(userId).child(id).remove();
  }
}
