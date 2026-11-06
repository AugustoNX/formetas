import 'package:firebase_database/firebase_database.dart';

import '../../core/config/rtdb_helper.dart';
import '../../domain/entities/control_trail.dart';
import '../models/control_trail_model.dart';

/// Persistência dos insights: trilhas aceitas e insights dispensados.
///
/// users/{uid}/trilhas/{id}
/// users/{uid}/insightsDispensados/{chaveSegura} = { id, em }
class InsightRemoteDataSource {
  InsightRemoteDataSource({FirebaseDatabase? database})
      : _database = database ?? RtdbHelper.database;

  final FirebaseDatabase _database;

  DatabaseReference _trails(String userId) => _database.ref('users/$userId/trilhas');
  DatabaseReference _dismissed(String userId) =>
      _database.ref('users/$userId/insightsDispensados');

  /// Chaves RTDB não aceitam `. # $ [ ] /`.
  static String safeKey(String id) => id.replaceAll(RegExp(r'[.#$\[\]/]'), '_');

  Stream<List<ControlTrail>> watchTrails(String userId) {
    return _trails(userId).onValue.map(
          (event) => RtdbHelper.parseChildren(event.snapshot.value, ControlTrailModel.fromMap),
        );
  }

  Future<void> saveTrail(String userId, ControlTrail trail) =>
      _trails(userId).child(trail.id).set(ControlTrailModel.toMap(trail));

  Future<void> updateTrailStatus(String userId, String trailId, TrailStatus status) =>
      _trails(userId).child(trailId).update({'status': status.name});

  Future<void> deleteTrail(String userId, String trailId) =>
      _trails(userId).child(trailId).remove();

  Stream<Set<String>> watchDismissed(String userId) {
    return _dismissed(userId).onValue.map((event) {
      final map = RtdbHelper.toStringKeyMap(event.snapshot.value);
      return {
        for (final entry in map.entries)
          if (entry.value is Map && (entry.value as Map)['id'] is String)
            (entry.value as Map)['id'] as String
          else
            entry.key,
      };
    });
  }

  Future<void> dismiss(String userId, String insightId) =>
      _dismissed(userId).child(safeKey(insightId)).set({
        'id': insightId,
        'em': DateTime.now().toIso8601String(),
      });

  Future<void> clearDismissed(String userId) => _dismissed(userId).remove();
}
