import '../entities/control_trail.dart';

abstract class InsightRepository {
  Stream<List<ControlTrail>> watchTrails(String userId);
  Future<void> saveTrail(String userId, ControlTrail trail);
  Future<void> updateTrailStatus(String userId, String trailId, TrailStatus status);
  Future<void> deleteTrail(String userId, String trailId);
  Stream<Set<String>> watchDismissed(String userId);
  Future<void> dismiss(String userId, String insightId);
  Future<void> clearDismissed(String userId);
}
