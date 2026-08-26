import '../entities/settings_entity.dart';
import '../entities/user_entity.dart';

abstract class UserRepository {
  Future<UserEntity?> getUser(String userId);
  Future<void> createUser(UserEntity user);
  Future<void> updateUser(UserEntity user);
  Future<SettingsEntity> getSettings(String userId);
  Future<void> updateSettings(String userId, SettingsEntity settings);
  Stream<SettingsEntity> watchSettings(String userId);
}
