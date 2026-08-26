import 'package:firebase_database/firebase_database.dart';

import '../../core/config/rtdb_helper.dart';
import '../../domain/entities/goal_entity.dart';
import '../models/goal_model.dart';

class GoalRemoteDataSource {
  GoalRemoteDataSource({FirebaseDatabase? database})
      : _database = database ?? RtdbHelper.database;

  final FirebaseDatabase _database;

  DatabaseReference _ref(String userId) => _database.ref('users/$userId/goals');

  Stream<List<GoalEntity>> watchGoals(String userId) {
    return _ref(userId).onValue.map((event) {
      return RtdbHelper.parseChildren(
        event.snapshot.value,
        (map, id) => GoalModel.fromMap(map, id),
      );
    });
  }

  Future<List<GoalEntity>> getGoals(String userId) async {
    final snapshot = await _ref(userId).get();
    return RtdbHelper.parseChildren(
      snapshot.value,
      (map, id) => GoalModel.fromMap(map, id),
    );
  }

  Future<void> createGoal(GoalEntity goal) async {
    final data = GoalModel.fromEntity(goal).toMap();
    await _ref(goal.userId).child(goal.id).set(data);
  }

  Future<void> updateGoal(GoalEntity goal) async {
    final data = GoalModel.fromEntity(goal).toMap();
    await _ref(goal.userId).child(goal.id).update(data);
  }

  Future<void> deleteGoal(String userId, String id) async {
    await _ref(userId).child(id).remove();
  }
}
