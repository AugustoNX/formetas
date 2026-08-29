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
    return _auth.userChanges().asyncMap(_mapUserWhenReady);
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
      await credential.user?.getIdToken();
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
      final firebaseUser = credential.user!;
      await firebaseUser.getIdToken(true);
      await firebaseUser.updateDisplayName(name.trim());

      final user = UserModel(
        id: firebaseUser.uid,
        name: name.trim(),
        email: email.trim(),
        createdAt: DateTime.now(),
      );

      await _database.ref('users/${user.id}/profile').set(user.toMap());
      await _database
          .ref('users/${user.id}/settings')
          .set(const SettingsModel().toMap());

      await firebaseUser.sendEmailVerification();
      return user;
    } on FirebaseAuthException catch (e) {
      throw AuthErrorMapper.map(e);
    } on FirebaseException catch (e) {
      throw AuthFailure(
        e.code == 'permission-denied'
            ? 'Não foi possível criar seus dados agora. Tente entrar de novo.'
            : 'Não foi possível concluir o cadastro. Tente novamente.',
      );
    }
  }

  Future<void> signOut() => _auth.signOut();

  Future<UserEntity> updateName(String name) async {
    final user = _auth.currentUser;
    if (user == null) {
      throw const AuthFailure('Usuário não autenticado.');
    }

    final trimmed = name.trim();
    if (trimmed.isEmpty) {
      throw const AuthFailure('Informe seu nome.');
    }

    try {
      await user.updateDisplayName(trimmed);
      await _database.ref('users/${user.uid}/profile').update({'nome': trimmed});
      await user.reload();
      return _mapUser(_auth.currentUser ?? user);
    } on FirebaseAuthException catch (e) {
      throw AuthErrorMapper.map(e);
    } on FirebaseException catch (e) {
      throw AuthFailure(
        e.code == 'permission-denied'
            ? 'Não foi possível salvar o nome agora. Tente de novo.'
            : 'Não foi possível atualizar o nome. Tente novamente.',
      );
    }
  }

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
    await _auth.currentUser?.getIdToken(true);
    return _mapUser(_auth.currentUser!);
  }

  Future<UserEntity?> _mapUserWhenReady(User? user) async {
    if (user == null) return null;
    try {
      await user.getIdToken();
    } catch (_) {}
    return _mapUser(_auth.currentUser ?? user);
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
