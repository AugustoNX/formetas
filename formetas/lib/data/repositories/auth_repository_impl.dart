import '../../domain/entities/user_entity.dart';
import '../../domain/repositories/auth_repository.dart';
import '../datasources/auth_remote_datasource.dart';

class AuthRepositoryImpl implements AuthRepository {
  AuthRepositoryImpl(this._dataSource);

  final AuthRemoteDataSource _dataSource;

  @override
  Stream<UserEntity?> get authStateChanges => _dataSource.authStateChanges;

  @override
  UserEntity? get currentUser => _dataSource.currentUser;

  @override
  Future<UserEntity> signIn({
    required String email,
    required String password,
  }) =>
      _dataSource.signIn(email: email, password: password);

  @override
  Future<UserEntity> signUp({
    required String name,
    required String email,
    required String password,
  }) =>
      _dataSource.signUp(name: name, email: email, password: password);

  @override
  Future<void> signOut() => _dataSource.signOut();

  @override
  Future<void> sendPasswordResetEmail(String email) =>
      _dataSource.sendPasswordResetEmail(email);

  @override
  Future<void> sendEmailVerification() => _dataSource.sendEmailVerification();

  @override
  Future<UserEntity> reloadUser() => _dataSource.reloadUser();

  @override
  Future<UserEntity> updateName(String name) => _dataSource.updateName(name);
}
