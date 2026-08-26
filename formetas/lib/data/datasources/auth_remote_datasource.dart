import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';

import '../../core/config/rtdb_helper.dart';
import '../../core/errors/failures.dart';
import '../../core/utils/auth_error_mapper.dart';
import '../../domain/entities/user_entity.dart';
import '../models/settings_model.dart';
import '../models/user_model.dart';

class AuthRemoteDataSource {
  AuthRemoteDataSource({
    FirebaseAuth? auth,
    FirebaseDatabase? database,
  })  : _auth = auth ?? FirebaseAuth.instance,
        _database = database ?? RtdbHelper.database;

  final FirebaseAuth _auth;
  final FirebaseDatabase _database;

  Stream<UserEntity?> get authStateChanges {
    return _auth.authStateChanges().map((user) {
      if (user == null) return null;
      return _mapUser(user);
    });
  }

  UserEntity? get currentUser {
    final user = _auth.currentUser;
    if (user == null) return null;
    return _mapUser(user);
  }

  Future<UserEntity> signIn({
    required String email,
    required String password,
  }) async {
    try {
      final credential = await _auth.signInWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
      return _mapUser(credential.user!);
    } on FirebaseAuthException catch (e) {
      throw AuthErrorMapper.map(e);
    }
  }

  Future<UserEntity> signUp({
    required String name,
    required String email,
    required String password,
  }) async {
    try {
      final credential = await _auth.createUserWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
      await credential.user!.updateDisplayName(name.trim());

      final user = UserModel(
        id: credential.user!.uid,
        name: name.trim(),
        email: email.trim(),
        createdAt: DateTime.now(),
      );

      await _database.ref('users/${user.id}/profile').set(user.toMap());
      await _database
          .ref('users/${user.id}/settings')
          .set(const SettingsModel().toMap());

      await credential.user!.sendEmailVerification();
      return user;
    } on FirebaseAuthException catch (e) {
      throw AuthErrorMapper.map(e);
    }
  }

  Future<void> signOut() => _auth.signOut();

  Future<void> sendPasswordResetEmail(String email) async {
    try {
      await _auth.sendPasswordResetEmail(email: email.trim());
    } on FirebaseAuthException catch (e) {
      throw AuthErrorMapper.map(e);
    }
  }

  Future<void> sendEmailVerification() async {
    final user = _auth.currentUser;
    if (user != null && !user.emailVerified) {
      await user.sendEmailVerification();
    }
  }

  Future<UserEntity> reloadUser() async {
    final user = _auth.currentUser;
    if (user == null) throw const AuthFailure('Usuário não autenticado.');
    await user.reload();
    return _mapUser(_auth.currentUser!);
  }

  UserEntity _mapUser(User user) {
    return UserModel(
      id: user.uid,
      name: user.displayName ?? '',
      email: user.email ?? '',
      photoUrl: user.photoURL,
      createdAt: user.metadata.creationTime ?? DateTime.now(),
      emailVerified: user.emailVerified,
    );
  }
}
