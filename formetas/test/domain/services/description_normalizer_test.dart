import 'package:flutter_test/flutter_test.dart';
import 'package:formetas/domain/services/description_normalizer.dart';

void main() {
  group('DescriptionNormalizer.key', () {
    test('remove CPF mascarado, banco, agência e conta do Pix do Nubank', () {
      final key = DescriptionNormalizer.key(
        'Transferência enviada pelo Pix - JOÃO DA SILVA - •••.123.456-•• - '
        'NU PAGAMENTOS - IP (0260) Agência: 1 Conta: 12345678-9',
      );
      expect(key, 'pix_enviado joao silva nu pagamentos');
    });

    test('mantém o sentido do Pix como token de tipo', () {
      expect(
        DescriptionNormalizer.key('Transferência recebida pelo Pix - MARIA SOUZA'),
        'pix_recebido maria souza',
      );
      expect(
        DescriptionNormalizer.key('PIX ENVIADO 05/03 14:32 MARIA SOUZA'),
        'pix_enviado maria souza',
      );
    });

    test('ignora datas, horas, NSU e final do cartão', () {
      final a = DescriptionNormalizer.key(
          'Compra no débito - PADARIA PÃO QUENTE 05/03 08:12 NSU 004512 final 1234');
      final b = DescriptionNormalizer.key(
          'Compra no débito - Padaria Pao Quente 2026-04-07 19h05 NSU 998877 final 1234');
      expect(a, b);
      expect(a, 'compra debito padaria pao quente');
    });

    test('remove CNPJ e códigos alfanuméricos longos', () {
      expect(
        DescriptionNormalizer.key('Pagamento de boleto efetuado - ENEL CE 07.047.251/0001-70 A1B2C3D4'),
        'pagamento boleto efetuado enel ce',
      );
    });

    test('remove marcador de parcela', () {
      expect(
        DescriptionNormalizer.key('Magazine Luiza (3/10)'),
        DescriptionNormalizer.key('Magazine Luiza (4/10)'),
      );
    });

    test('preserva nomes com poucos dígitos', () {
      expect(DescriptionNormalizer.key('99app *99Pop'), '99app 99pop');
    });
  });

  group('DescriptionNormalizer.similarity', () {
    test('mesmo estabelecimento com ruído diferente é idêntico', () {
      expect(
        DescriptionNormalizer.similarity(
          'NETFLIX.COM 05/03 SAO PAULO',
          'Netflix.com 05/04 Sao Paulo',
        ),
        1,
      );
    });

    test('Pix enviado e recebido para a mesma pessoa não se misturam', () {
      expect(
        DescriptionNormalizer.similarity(
          'Pix enviado - Maria Souza',
          'Pix recebido - Maria Souza',
        ),
        0,
      );
    });

    test('Jaccard parcial', () {
      final score = DescriptionNormalizer.similarity(
        'Uber Trip Sao Paulo',
        'Uber Trip',
      );
      expect(score, closeTo(0.5, 0.001));
    });
  });
}
