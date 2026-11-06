/// Limiares do classificador de categorias. Tudo que muda o comportamento
/// (confiança, pesos, poda, decaimento) fica aqui.
abstract final class ClassifierThresholds {
  /// Versão do mapa gravado em `users/{uid}/antBrain`.
  /// Se o valor lido for outro, o modelo é refeito a partir do histórico.
  static const schemaVersion = 1;

  /// Confiança mínima para aceitar a sugestão do Naive Bayes.
  static const learnedMinConfidence = 0.6;

  /// A partir daqui o selo é "alta".
  static const highConfidence = 0.85;

  /// Abaixo de [learnedMinConfidence] o selo é "baixa" e a linha sobe para revisão.
  static const mediumConfidence = 0.6;

  /// Igual ao casamento aproximado das regras de importação.
  static const ruleFuzzy = 0.8;

  /// Similaridade mínima para herdar a categoria de um padrão recorrente.
  static const recurrenceSimilarity = 0.8;

  /// Confiança mínima do próprio padrão recorrente.
  static const recurrenceMinConfidence = 0.4;

  /// "Aplicar a todas parecidas".
  static const similarApply = 0.8;

  /// Linha aceita como veio.
  static const acceptWeight = 1.0;

  /// Linha corrigida pelo usuário: pesa mais que um aceite.
  static const correctionWeight = 3.0;

  /// Suavização de Laplace.
  static const laplaceAlpha = 1.0;

  /// Tokens pesam mais que valor e dia.
  static const tokenWeight = 3.0;
  static const bigramWeight = 2.4;
  static const typeWeight = 1.6;
  static const paymentWeight = 1.1;
  static const amountWeight = 0.45;
  static const dayWeight = 0.3;

  /// Multiplicador diário aplicado ao conhecimento antigo antes de um exemplo novo.
  /// 0,997 ao dia deixa o hábito recente falar mais alto sem apagar o ano.
  static const timeDecayPerDay = 0.997;

  /// Quantos atributos (tokens, faixas, dias) cada categoria guarda.
  static const maxFeaturesPerCategory = 40;

  /// Importações lembradas para o gráfico de acerto.
  static const maxHistory = 12;

  /// Uma escrita só, depois que as correções da sessão assentam.
  static const saveDebounce = Duration(milliseconds: 800);

  /// Acima deste tamanho o bootstrap vai para outro isolate.
  static const bootstrapIsolateAt = 80;
}
