import 'package:firebase_database/firebase_database.dart';

import '../../core/config/rtdb_helper.dart';
import '../../domain/entities/settings_entity.dart';
import '../../domain/entities/user_entity.dart';
import '../models/settings_model.dart';
import '../models/user_model.dart';

class UserRemoteDataSource {
  UserRemoteDataSource({FirebaseDatabase? database})
      : _database = database ?? RtdbHelper.database;

  final FirebaseDatabase _database;

  DatabaseReference _userRef(String userId) => _database.ref('users/$userId');

  Future<UserEntity?> getUser(String userId) async {
    final snapshot = await _userRef(userId).child('profile').get();
    if (!snapshot.exists) return null;
    return UserModel.fromMap(
      RtdbHelper.toStringKeyMap(snapshot.value),
      userId,
    );
  }

  Future<void> createUser(UserEntity user) async {
    final model = UserModel.fromEntity(user);
    await _userRef(user.id).child('profile').set(model.toMap());
    await _userRef(user.id)
        .child('settings')
        .set(const SettingsModel().toMap());
  }

  Future<void> updateUser(UserEntity user) async {
    final model = UserModel.fromEntity(user);
    await _userRef(user.id).child('profile').update(model.toMap());
  }

  Future<SettingsEntity> getSettings(String userId) async {
    final snapshot = await _userRef(userId).child('settings').get();
    if (!snapshot.exists) return const SettingsModel();
    return SettingsModel.fromMap(RtdbHelper.toStringKeyMap(snapshot.value));
  }

  Future<void> updateSettings(String userId, SettingsEntity settings) async {
    final model = SettingsModel.fromEntity(settings);
    await _userRef(userId).child('settings').update(model.toMap());
  }

  Stream<SettingsEntity> watchSettings(String userId) {
    return _userRef(userId).child('settings').onValue.map((event) {
      if (!event.snapshot.exists) return const SettingsModel();
      return SettingsModel.fromMap(
        RtdbHelper.toStringKeyMap(event.snapshot.value),
      );
    });
  }
}
