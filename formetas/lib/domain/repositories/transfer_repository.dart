import '../entities/transfer_entity.dart';

abstract class TransferRepository {
  Stream<List<TransferEntity>> watchTransfers(String userId);
  Future<List<TransferEntity>> getTransfers(String userId);
  Future<void> createTransfer(TransferEntity transfer);
  Future<void> deleteTransfer(String userId, String id);
}
