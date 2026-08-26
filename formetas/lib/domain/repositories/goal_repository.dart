import '../entities/goal_entity.dart';

abstract class GoalRepository {
  Stream<List<GoalEntity>> watchGoals(String userId);
  Future<List<GoalEntity>> getGoals(String userId);
  Future<void> createGoal(GoalEntity goal);
  Future<void> updateGoal(GoalEntity goal);
  Future<void> deleteGoal(String userId, String id);
}
