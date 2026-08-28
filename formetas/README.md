# Formetas

Controle financeiro pessoal com a filosofia de **trabalho de formiguinha**: pequenas ações diárias constroem grandes patrimônios.

> *Grandes conquistas são construídas como um trabalho de formiguinha.*

O Formetas não é um extrato bancário. É um espaço para registrar o que entra, o que sai e para onde o dinheiro vai — saldo disponível, reserva (caixinha) e investimentos — sem misturar movimento interno com gasto.

---

## Contexto

Muita gente controla só receita e despesa. O problema aparece quando o dinheiro **sai do bolso, mas não foi gasto**: foi para uma caixinha, um CDB ou a carteira de investimentos. Se isso entra como despesa, o app mente: parece que você gastou, quando na verdade só mudou o dinheiro de lugar.

O Formetas trata o patrimônio em **três bolsos**:

| Bolso | O que é | Exemplos |
| --- | --- | --- |
| **Saldo disponível** | Dinheiro livre no mês | Conta corrente, PIX, o que ainda pode gastar |
| **Caixinha / reserva** | Dinheiro parado rendendo com regra de CDI ou taxa fixa | CDB, caixinha do banco, poupança, reserva de emergência |
| **Investimentos** | Carteira de mercado | Ações, FIIs, total investido |

Mover dinheiro entre esses bolsos é **transferência interna**. Não conta como receita nem como despesa.

---

## Como a lógica funciona

### 1. Receitas e despesas

Toda movimentação “de verdade” com o mundo externo é uma transação:

- **Receita** — salário, freelance, dividendos recebidos na conta, etc.
- **Despesa** — mercado, aluguel, lazer, contas.

Elas alimentam o **saldo do mês**. Categorias (padrão + as suas) organizam gráficos e relatórios.

### 2. Saldo mensal (o “banco interno”)

O saldo **não** é receita menos despesa do mês isolado. Ele carrega o mês anterior:

```
saldo final =
  saldo inicial do mês
  + receitas
  − despesas
  + transferências que entram no saldo
  − transferências que saem do saldo
```

Assim, guardar R$ 500 na caixinha diminui o saldo disponível, mas **não** aparece como gasto. Resgatar da caixinha devolve o valor ao saldo, sem aparecer como renda.

O **patrimônio** na home é:

```
patrimônio = saldo disponível + total das caixinhas
```

Investimentos aparecem no card próprio; o saldo da home é o dinheiro que ainda está “à mão”.

### 3. Caixinha (reserva)

Cada caixinha tem:

- valor inicial e data de início
- aportes e resgates ao longo do tempo
- rendimento por **% do CDI** ou **taxa fixa**

O cálculo simula o rendimento **dia a dia**, com juros compostos. Cada aporte começa a render a partir da data em que entrou; cada resgate tira do valor atualizado. Por isso duas caixinhas com o mesmo CDI podem ter valores diferentes — o histórico de movimentação pesa.

Não dá para resgatar mais do que o saldo atual (principal + rendimento até agora).

### 4. Investimentos

A carteira é o total investido (visão simplificada). Entrar e sair da carteira também é transferência: **do saldo para investir** ou **resgatar para o saldo**. Não passa pelo extrato de despesas.

### 5. Transferências

Qualquer rota entre os três bolsos:

```
Saldo  ⇄  Caixinha
Saldo  ⇄  Investimentos
Caixinha  ⇄  Investimentos
```

Regras:

- origem e destino precisam ser diferentes
- o valor **não pode ser maior** que o disponível na origem naquele momento
- a operação grava um registro em `transfers` e atualiza a caixinha/carteira quando for o caso

### 6. Metas

Objetivo com valor-alvo, valor atual e prazo. É o “para onde o trabalho de formiguinha está indo” — viagem, reserva de X meses, quitar dívida, etc.

### 7. Relatórios

Comparam receitas, despesas e economia no tempo: categorias, médias, maiores lançamentos, evolução do saldo e da reserva.

---

## O que o app oferece

- Login, cadastro e recuperação de senha (Firebase Auth)
- Home com saldo do mês, receitas, despesas, economia (caixinhas) e investimentos
- Extrato de movimentações com filtro por tipo, mês e busca
- Caixinhas com detalhe, aporte/resgate e simulação de rendimento
- Carteira de investimentos com investir / resgatar
- Transferência entre bolsos sem sujar o extrato
- Metas financeiras
- Relatórios e gráficos
- Categorias padrão + personalizadas
- Tema claro / escuro
- **Celular:** barra inferior e botão Novo  
- **Computador / web:** menu na lateral e conteúdo em tela cheia

---

## Arquitetura

O código segue uma Clean Architecture enxuta:

```
lib/
  core/           tema, rotas, constantes, calculadoras
  domain/         entidades, contratos e regras de negócio
  data/           Firebase (Auth + Realtime Database) e modelos
  presentation/   telas, widgets e Riverpod
```

**Estado:** Riverpod.  
**Navegação:** GoRouter.  
**Backend:** Firebase Authentication + Realtime Database, por usuário:

```
users/{uid}/
  transactions/
  reserves/{id}/movimentacoes/
  investments/
  transfers/
  goals/
  categories/
```

As regras importantes (saldo acumulado, rendimento da caixinha, teto da transferência) ficam no **domínio**, não na tela. A UI só pede e mostra.

---

## Stack

| Camada | Tecnologia |
| --- | --- |
| App | Flutter (Dart 3.12+) |
| Estado | Riverpod |
| Rotas | GoRouter |
| Auth / dados | Firebase Auth + Realtime Database |
| Gráficos | fl_chart |
| Web | Flutter Web na Vercel |

---

## Como rodar

Pré-requisito: [Flutter SDK](https://docs.flutter.dev/get-started/install).

```bash
cd formetas
flutter pub get
flutter run
```

Web local:

```bash
flutter run -d chrome
```

Build de produção web:

```bash
flutter build web --release --no-wasm-dry-run
```

---

## Deploy (Vercel)

O repositório já tem `vercel.json` e `scripts/vercel-build.sh`. Importe o GitHub na Vercel; o build instala o Flutter e gera `formetas/build/web`.

No [Firebase Console](https://console.firebase.google.com) → Authentication → Settings → **Authorized domains**, inclua o domínio `*.vercel.app` (e o domínio próprio, se houver). Sem isso o login na web falha.

---

## Princípio de produto

O Formetas assume que disciplina financeira é acumulação, não um golpe de sorte:

- registrar o gasto já é um passo
- guardar na caixinha é outro
- investir é o seguinte

Cada tela reforça isso com mensagens curtas, sem tom de cobrança. O objetivo é tornar o hábito visível — formiguinha por formiguinha.
