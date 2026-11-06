abstract final class UserFacingError {
  static String load(Object error) {
    final raw = error.toString().toLowerCase();
    if (raw.contains('permission-denied') ||
        raw.contains('permission denied') ||
        raw.contains("doesn't have permission") ||
        raw.contains('does not have permission')) {
      return 'Ainda estamos liberando o acesso da sua conta.';
    }
    if (raw.contains('network') ||
        raw.contains('socket') ||
        raw.contains('unavailable') ||
        raw.contains('timeout') ||
        raw.contains('failed host')) {
      return 'Sem conexão. Verifique sua internet e tente de novo.';
    }
    return 'Não foi possível carregar agora. Tente de novo.';
  }
}
