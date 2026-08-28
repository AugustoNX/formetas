import 'package:firebase_database/firebase_database.dart';

import '../../core/config/rtdb_helper.dart';
import '../../domain/entities/ant_profile_entity.dart';
import '../models/ant_profile_model.dart';

class AnthillRemoteDataSource {
  AnthillRemoteDataSource({FirebaseDatabase? database})
      : _database = database ?? RtdbHelper.database;

  final FirebaseDatabase _database;

  DatabaseReference _ref(String userId) =>
      _database.ref('users/$userId/formigueiro');

  Stream<AntProfileEntity> watchProfile(String userId) {
    return _ref(userId).onValue.map((event) => _parse(event.snapshot.value));
  }

  Future<AntProfileEntity> getProfile(String userId) async {
    final snapshot = await _ref(userId).get();
    return _parse(snapshot.value);
  }

  Future<void> updateAntName(String userId, String name) async {
    await _ref(userId).update({'nomeFormiga': name});
  }

  Future<void> updateAnimationsEnabled(String userId, bool enabled) async {
    await _ref(userId).update({'animacoes': enabled});
  }

  Future<void> updateCelebratedLevel(String userId, int level) async {
    await _ref(userId).update({'nivelCelebrado': level});
  }

  Future<void> initialize(String userId, AntProfileEntity profile) async {
    await _ref(userId).set(AntProfileModel.fromEntity(profile).toMap());
  }

  Future<void> unlockAchievements(
    String userId,
    Map<String, DateTime> unlockedAt,
  ) async {
    if (unlockedAt.isEmpty) return;
    await _ref(userId).child('conquistas').update({
      for (final entry in unlockedAt.entries)
        entry.key: entry.value.toIso8601String(),
    });
  }

  AntProfileEntity _parse(Object? value) {
    if (value is! Map) return const AntProfileEntity();
    return AntProfileModel.fromMap(RtdbHelper.toStringKeyMap(value));
  }
}
