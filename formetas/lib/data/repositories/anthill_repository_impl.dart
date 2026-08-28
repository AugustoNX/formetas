import '../../domain/entities/ant_profile_entity.dart';
import '../../domain/repositories/anthill_repository.dart';
import '../datasources/anthill_remote_datasource.dart';

class AnthillRepositoryImpl implements AnthillRepository {
  AnthillRepositoryImpl(this._dataSource);

  final AnthillRemoteDataSource _dataSource;

  @override
  Stream<AntProfileEntity> watchProfile(String userId) =>
      _dataSource.watchProfile(userId);

  @override
  Future<AntProfileEntity> getProfile(String userId) =>
      _dataSource.getProfile(userId);

  @override
  Future<void> updateAntName(String userId, String name) =>
      _dataSource.updateAntName(userId, name);

  @override
  Future<void> updateAnimationsEnabled(String userId, bool enabled) =>
      _dataSource.updateAnimationsEnabled(userId, enabled);

  @override
  Future<void> updateCelebratedLevel(String userId, int level) =>
      _dataSource.updateCelebratedLevel(userId, level);

  @override
  Future<void> initialize(String userId, AntProfileEntity profile) =>
      _dataSource.initialize(userId, profile);

  @override
  Future<void> unlockAchievements(
    String userId,
    Map<String, DateTime> unlockedAt,
  ) =>
      _dataSource.unlockAchievements(userId, unlockedAt);
}
