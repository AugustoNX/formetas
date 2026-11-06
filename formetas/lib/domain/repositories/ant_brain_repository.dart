import '../entities/ant_brain.dart';

abstract class AntBrainRepository {
  Future<AntBrainSnapshot?> load(String userId);
  Future<void> save(String userId, AntBrainSnapshot snapshot);
}
