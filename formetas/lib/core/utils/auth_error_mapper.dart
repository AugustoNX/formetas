import 'package:firebase_auth/firebase_auth.dart';

import '../errors/failures.dart';

abstract final class AuthErrorMapper {
  static Failure map(FirebaseAuthException e) {
    switch (e.code) {
      case 'user-not-found':
        return const AuthFailure('Nenhuma conta encontrada com este e-mail.');
      case 'wrong-password':
        return const AuthFailure('Senha incorreta. Tente novamente.');
      case 'email-already-in-use':
        return const AuthFailure('Este e-mail já está cadastrado.');
      case 'invalid-email':
        return const AuthFailure('E-mail inválido.');
      case 'weak-password':
        return const AuthFailure('A senha deve ter pelo menos 6 caracteres.');
      case 'too-many-requests':
        return const AuthFailure('Muitas tentativas. Aguarde um momento.');
      case 'network-request-failed':
        return const AuthFailure('Sem conexão. Verifique sua internet.');
      case 'user-disabled':
        return const AuthFailure('Esta conta foi desativada.');
      default:
        return AuthFailure(e.message ?? 'Erro de autenticação.');
    }
  }
}
