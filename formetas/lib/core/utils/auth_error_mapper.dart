import 'package:firebase_auth/firebase_auth.dart';

import '../errors/failures.dart';

abstract final class AuthErrorMapper {
  static Failure map(FirebaseAuthException e) {
    return AuthFailure(_message(e.code));
  }

  static String _message(String code) {
    return switch (code) {
      'invalid-credential' ||
      'invalid-login-credentials' ||
      'wrong-password' ||
      'user-not-found' =>
        'E-mail ou senha incorretos.',
      'invalid-email' => 'E-mail inválido.',
      'missing-email' => 'Informe seu e-mail.',
      'missing-password' => 'Informe sua senha.',
      'email-already-in-use' => 'Este e-mail já está cadastrado.',
      'weak-password' => 'A senha deve ter pelo menos 6 caracteres.',
      'too-many-requests' => 'Muitas tentativas. Aguarde um momento.',
      'network-request-failed' => 'Sem conexão. Verifique sua internet.',
      'user-disabled' => 'Esta conta foi desativada.',
      'operation-not-allowed' => 'Esse tipo de acesso não está disponível.',
      'requires-recent-login' =>
        'Entre de novo na conta para concluir essa alteração.',
      'expired-action-code' ||
      'invalid-action-code' =>
        'Esse link expirou. Peça outro e tente de novo.',
      'user-token-expired' ||
      'invalid-user-token' =>
        'Sua sessão expirou. Entre de novo.',
      'credential-already-in-use' ||
      'account-exists-with-different-credential' =>
        'Esse e-mail já está ligado a outra forma de acesso.',
      'timeout' => 'A conexão demorou demais. Tente de novo.',
      _ => 'Não foi possível concluir agora. Tente novamente.',
    };
  }
}
