import '../../domain/entities/ant_brain.dart';
import '../../domain/repositories/ant_brain_repository.dart';
import '../datasources/ant_brain_remote_datasource.dart';

class AntBrainRepositoryImpl implements AntBrainRepository {
  AntBrainRepositoryImpl(this._dataSource);

  final AntBrainRemoteDataSource _dataSource;

  @override
  Future<AntBrainSnapshot?> load(String userId) => _dataSource.load(userId);

  @override
  Future<void> save(String userId, AntBrainSnapshot snapshot) =>
      _dataSource.save(userId, snapshot);
}
