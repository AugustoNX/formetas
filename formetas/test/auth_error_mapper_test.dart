import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:formetas/core/errors/failures.dart';
import 'package:formetas/core/utils/auth_error_mapper.dart';
import 'package:formetas/core/utils/user_facing_error.dart';

void main() {
  test('login com credencial inválida não mostra a mensagem em inglês', () {
    final failure = AuthErrorMapper.map(
      FirebaseAuthException(
        code: 'invalid-credential',
        message:
            'The supplied auth credential is incorrect, malformed or has expired.',
      ),
    );

    expect(failure, isA<AuthFailure>());
    expect(failure.message, 'E-mail ou senha incorretos.');
    expect(failure.message, isNot(contains('supplied')));
  });

  test('código desconhecido de autenticação também fica em português', () {
    final failure = AuthErrorMapper.map(
      FirebaseAuthException(
        code: 'internal-error',
        message: 'An internal error has occurred.',
      ),
    );

    expect(failure.message, 'Não foi possível concluir agora. Tente novamente.');
  });

  test('falha de carregamento não repassa o texto técnico', () {
    expect(
      UserFacingError.load(
        Exception('[firebase_database/permission-denied] Client does not have permission'),
      ),
      'Ainda estamos liberando o acesso da sua conta.',
    );
    expect(
      UserFacingError.load(Exception('SocketException: Failed host lookup')),
      'Sem conexão. Verifique sua internet e tente de novo.',
    );
  });
}
