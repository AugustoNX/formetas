import 'package:firebase_database/firebase_database.dart';

import '../../core/config/rtdb_helper.dart';
import '../../domain/entities/ant_brain.dart';
import '../models/ant_brain_model.dart';

/// `users/{uid}/antBrain` — o modelo inteiro numa escrita só.
class AntBrainRemoteDataSource {
  AntBrainRemoteDataSource({FirebaseDatabase? database})
    : _database = database ?? RtdbHelper.database;

  final FirebaseDatabase _database;

  DatabaseReference _ref(String userId) =>
      _database.ref('users/$userId/antBrain');

  Future<AntBrainSnapshot?> load(String userId) async {
    final snapshot = await _ref(userId).get();
    if (!snapshot.exists || snapshot.value == null) return null;
    final brain = AntBrainModel.fromValue(snapshot.value);
    if (brain.model.isEmpty &&
        brain.history.isEmpty &&
        brain.model.schemaVersion == 0) {
      return null;
    }
    return brain;
  }

  Future<void> save(String userId, AntBrainSnapshot snapshot) {
    return _ref(userId).set(AntBrainModel.toMap(snapshot));
  }
}
