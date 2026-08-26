import '../entities/user_entity.dart';

abstract class AuthRepository {
  Stream<UserEntity?> get authStateChanges;
  UserEntity? get currentUser;
  Future<UserEntity> signIn({required String email, required String password});
  Future<UserEntity> signUp({
    required String name,
    required String email,
    required String password,
  });
  Future<void> signOut();
  Future<void> sendPasswordResetEmail(String email);
  Future<void> sendEmailVerification();
  Future<UserEntity> reloadUser();
}
