import '../../domain/entities/settings_entity.dart';
import '../../domain/entities/user_entity.dart';
import '../../domain/repositories/user_repository.dart';
import '../datasources/user_remote_datasource.dart';

class UserRepositoryImpl implements UserRepository {
  UserRepositoryImpl(this._dataSource);

  final UserRemoteDataSource _dataSource;

  @override
  Future<UserEntity?> getUser(String userId) => _dataSource.getUser(userId);

  @override
  Future<void> createUser(UserEntity user) => _dataSource.createUser(user);

  @override
  Future<void> updateUser(UserEntity user) => _dataSource.updateUser(user);

  @override
  Future<SettingsEntity> getSettings(String userId) =>
      _dataSource.getSettings(userId);

  @override
  Future<void> updateSettings(String userId, SettingsEntity settings) =>
      _dataSource.updateSettings(userId, settings);

  @override
  Stream<SettingsEntity> watchSettings(String userId) =>
      _dataSource.watchSettings(userId);
}
