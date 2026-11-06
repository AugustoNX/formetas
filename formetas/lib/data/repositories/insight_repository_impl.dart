import '../../domain/entities/control_trail.dart';
import '../../domain/repositories/insight_repository.dart';
import '../datasources/insight_remote_datasource.dart';

class InsightRepositoryImpl implements InsightRepository {
  InsightRepositoryImpl(this._dataSource);

  final InsightRemoteDataSource _dataSource;

  @override
  Stream<List<ControlTrail>> watchTrails(String userId) => _dataSource.watchTrails(userId);

  @override
  Future<void> saveTrail(String userId, ControlTrail trail) =>
      _dataSource.saveTrail(userId, trail);

  @override
  Future<void> updateTrailStatus(String userId, String trailId, TrailStatus status) =>
      _dataSource.updateTrailStatus(userId, trailId, status);

  @override
  Future<void> deleteTrail(String userId, String trailId) =>
      _dataSource.deleteTrail(userId, trailId);

  @override
  Stream<Set<String>> watchDismissed(String userId) => _dataSource.watchDismissed(userId);

  @override
  Future<void> dismiss(String userId, String insightId) =>
      _dataSource.dismiss(userId, insightId);

  @override
  Future<void> clearDismissed(String userId) => _dataSource.clearDismissed(userId);
}
