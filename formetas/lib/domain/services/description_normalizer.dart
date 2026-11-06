/// Transforma descrições de extrato em uma chave estável.
///
/// Extratos repetem o mesmo estabelecimento com ruído diferente a cada linha:
/// data, hora, NSU, CPF mascarado, final do cartão, agência e conta. A chave
/// remove esse ruído para que "Pix enviado 05/03 - ENEL 123456" e
/// "Pix enviado 05/04 - ENEL 987654" caiam no mesmo grupo.
///
/// O sentido do Pix não é jogado fora: vira um token de tipo ([pixOut] ou
/// [pixIn]) no começo da chave, porque receber e enviar para a mesma pessoa
/// são coisas diferentes.
abstract final class DescriptionNormalizer {
  static const pixOut = 'pix_enviado';
  static const pixIn = 'pix_recebido';

  /// Similaridade mínima para considerar duas chaves o mesmo item.
  static const defaultThreshold = 0.75;

  static const _stopwords = {
    'a', 'o', 'as', 'os', 'e', 'de', 'da', 'do', 'das', 'dos', 'em', 'no',
    'na', 'para', 'pelo', 'pela', 'por', 'com', 'via', 'ltda', 'me', 'sa',
    'eireli', 'epp', 'ag', 'agencia', 'conta', 'cc', 'ip', 'final', 'cartao',
    'nsu', 'id', 'doc', 'ted', 'aut', 'autenticacao', 'parcela',
  };

  static const _pixOutPhrases = [
    'transferencia enviada pelo pix',
    'transferencia enviada via pix',
    'pix enviado',
    'pix transferido',
    'envio de pix',
    'pagamento pix',
    'pix pagamento',
  ];

  static const _pixInPhrases = [
    'transferencia recebida pelo pix',
    'transferencia recebida via pix',
    'pix recebido',
    'recebimento de pix',
    'recebimento pix',
  ];

  /// Chave estável: tokens significativos separados por espaço.
  static String key(String description) => tokens(description).join(' ');

  /// Tokens da chave, na ordem em que aparecem e sem repetição.
  static List<String> tokens(String description) {
    var text = stripAccents(description.toLowerCase());

    // Ruído estruturado, removido antes de perder a pontuação.
    text = text
        // CPF/CNPJ, inclusive mascarados (•••.123.456-•• / ***.123.456-**).
        .replaceAll(
          RegExp(r'[\d•*x]{2,3}\.[\d•*x]{3}\.[\d•*x]{3}[/\-][\d•*x]{2,4}(-[\d•*x]{2})?'),
          ' ',
        )
        .replaceAll(RegExp(r'[•*]{2,}[\d.\-•*]*'), ' ')
        // Datas: 05/03, 05/03/2026, 05-03-26, 2026-03-05.
        .replaceAll(RegExp(r'\b\d{4}-\d{1,2}-\d{1,2}\b'), ' ')
        .replaceAll(RegExp(r'\b\d{1,2}[/\-.]\d{1,2}([/\-.]\d{2,4})?\b'), ' ')
        // Horas: 14:32, 14:32:10, 14h32.
        .replaceAll(RegExp(r'\b\d{1,2}[:h]\d{2}(:\d{2})?\b'), ' ')
        // Parcelas: (1/3), 01 de 12.
        .replaceAll(RegExp(r'\(\s*\d+\s*/\s*\d+\s*\)'), ' ')
        .replaceAll(RegExp(r'\b\d+\s+de\s+\d+\b'), ' ')
        // Final do cartão.
        .replaceAll(RegExp(r'\bfinal\s*\d{3,4}\b'), ' ');

    text = text.replaceAll(RegExp(r'[^a-z0-9]+'), ' ').replaceAll(RegExp(r'\s+'), ' ').trim();

    String? typeToken;
    for (final phrase in _pixOutPhrases) {
      if (text.contains(phrase)) {
        typeToken = pixOut;
        text = text.replaceFirst(phrase, ' ');
        break;
      }
    }
    if (typeToken == null) {
      for (final phrase in _pixInPhrases) {
        if (text.contains(phrase)) {
          typeToken = pixIn;
          text = text.replaceFirst(phrase, ' ');
          break;
        }
      }
    }

    final result = <String>[?typeToken];
    for (final token in text.split(' ')) {
      if (token.isEmpty) continue;
      if (_stopwords.contains(token)) continue;
      if (_isCode(token)) continue;
      if (token == 'pix' && typeToken != null) continue;
      if (!result.contains(token)) result.add(token);
    }
    return result;
  }

  /// Jaccard entre os conjuntos de tokens de duas descrições (0 a 1).
  static double similarity(String a, String b) =>
      tokenSimilarity(tokens(a), tokens(b));

  /// Jaccard entre listas de tokens já calculadas.
  static double tokenSimilarity(Iterable<String> a, Iterable<String> b) {
    final left = a.toSet();
    final right = b.toSet();
    if (left.isEmpty && right.isEmpty) return 1;
    if (left.isEmpty || right.isEmpty) return 0;
    // Sentidos opostos de Pix nunca são o mesmo item.
    if ((left.contains(pixOut) && right.contains(pixIn)) ||
        (left.contains(pixIn) && right.contains(pixOut))) {
      return 0;
    }
    final intersection = left.intersection(right).length;
    final union = left.union(right).length;
    return intersection / union;
  }

  static String stripAccents(String value) {
    const accents = {
      'á': 'a', 'à': 'a', 'â': 'a', 'ã': 'a', 'ä': 'a',
      'é': 'e', 'è': 'e', 'ê': 'e', 'ë': 'e',
      'í': 'i', 'ì': 'i', 'î': 'i', 'ï': 'i',
      'ó': 'o', 'ò': 'o', 'ô': 'o', 'õ': 'o', 'ö': 'o',
      'ú': 'u', 'ù': 'u', 'û': 'u', 'ü': 'u',
      'ç': 'c', 'ñ': 'n',
    };
    final buffer = StringBuffer();
    for (final rune in value.runes) {
      final char = String.fromCharCode(rune);
      buffer.write(accents[char] ?? char);
    }
    return buffer.toString();
  }

  /// Sequências que mudam a cada linha: números longos, códigos com letras e
  /// dígitos misturados e números soltos (agência, conta, NSU).
  static bool _isCode(String token) {
    final digits = token.replaceAll(RegExp(r'[^0-9]'), '').length;
    if (digits == 0) return false;
    if (digits == token.length) return true;
    return digits >= 3;
  }
}
