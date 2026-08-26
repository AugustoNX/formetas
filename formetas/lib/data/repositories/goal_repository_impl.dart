import '../../domain/entities/goal_entity.dart';
import '../../domain/repositories/goal_repository.dart';
import '../datasources/goal_remote_datasource.dart';

class GoalRepositoryImpl implements GoalRepository {
  GoalRepositoryImpl(this._dataSource);

  final GoalRemoteDataSource _dataSource;

  @override
  Stream<List<GoalEntity>> watchGoals(String userId) =>
      _dataSource.watchGoals(userId);

  @override
  Future<List<GoalEntity>> getGoals(String userId) =>
      _dataSource.getGoals(userId);

  @override
  Future<void> createGoal(GoalEntity goal) => _dataSource.createGoal(goal);

  @override
  Future<void> updateGoal(GoalEntity goal) => _dataSource.updateGoal(goal);

  @override
  Future<void> deleteGoal(String userId, String id) =>
      _dataSource.deleteGoal(userId, id);
}
