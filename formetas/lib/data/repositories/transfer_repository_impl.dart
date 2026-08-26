import '../../domain/entities/transfer_entity.dart';
import '../../domain/repositories/transfer_repository.dart';
import '../datasources/transfer_remote_datasource.dart';

class TransferRepositoryImpl implements TransferRepository {
  TransferRepositoryImpl(this._dataSource);

  final TransferRemoteDataSource _dataSource;

  @override
  Stream<List<TransferEntity>> watchTransfers(String userId) =>
      _dataSource.watchTransfers(userId);

  @override
  Future<List<TransferEntity>> getTransfers(String userId) =>
      _dataSource.getTransfers(userId);

  @override
  Future<void> createTransfer(TransferEntity transfer) =>
      _dataSource.createTransfer(transfer);

  @override
  Future<void> deleteTransfer(String userId, String id) =>
      _dataSource.deleteTransfer(userId, id);
}
