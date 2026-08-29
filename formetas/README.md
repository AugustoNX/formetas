# Formetas

**Grandes conquistas são construídas como um trabalho de formiguinha.**

O Formetas é um aplicativo de controle financeiro pessoal. Não é um extrato bancário e não se conecta à conta do banco: a pessoa registra o que entra, o que sai e **para onde o dinheiro foi**. O objetivo é tornar o hábito visível — registrar, guardar, investir — sem transformar movimento interno em “gasto”.

Este arquivo descreve a ideia, as funções, as lógicas, as telas, o banco, a hierarquia do código e as tecnologias. Serve tanto como documentação do projeto quanto como base para uma apresentação em slides.

---

## 1. A ideia

Muita gente controla só receita e despesa. O problema aparece quando o dinheiro **sai do bolso, mas não foi gasto**: foi para uma caixinha, um CDB ou a compra de uma ação. Se isso entra como despesa, o app mente. Parece que a pessoa gastou, quando na verdade só mudou o dinheiro de lugar.

O Formetas parte de três convicções:

1. **Disciplina financeira é acumulação**, não um golpe de sorte. Registrar o gasto já é um passo; guardar na caixinha é outro; investir é o seguinte.
2. **O patrimônio tem bolsos.** Saldo disponível, reserva e investimentos são coisas diferentes e precisam aparecer separados.
3. **Motivação sem culpa.** As mensagens são curtas e positivas. O Formigueiro traduz os mesmos números em folhinhas, missões e conquistas, sem alterar nenhuma regra financeira.

O nome junta *formiga* e *metas*: o trabalho pequeno e constante na direção de um objetivo.

### O que o app não é

- Não sincroniza Open Finance, PIX ou extrato do banco.
- Não executa ordens na corretora.
- Não usa a API da B3 (ela é B2B; pessoa física não tem acesso).
- Não duplica dados financeiros na gamificação: o Formigueiro só **lê**.

---

## 2. Os três bolsos

Todo o dinheiro da pessoa vive em um de três lugares:

| Bolso | O que é | Exemplos | Como o valor muda |
| --- | --- | --- | --- |
| **Saldo disponível** | Dinheiro livre no mês, “à mão” | Conta corrente, PIX, o que ainda pode gastar | Receitas, despesas e transferências que entram ou saem do saldo |
| **Caixinha / reserva** | Dinheiro parado rendendo com regra | CDB, caixinha do banco, poupança, reserva de emergência | Aportes, resgates e juros compostos dia a dia (% do CDI ou taxa fixa) |
| **Investimentos** | Carteira de mercado | Ações, FIIs, ETFs, BDRs, cripto | Compra (sai do saldo), venda e provento (entram no saldo); valor = quantidade × cotação |

Mover dinheiro entre esses bolsos é **transferência interna**. Não conta como receita nem como despesa do mês.

O patrimônio na home é a soma dos três:

```
patrimônio = saldo disponível + caixinhas + investimentos
```

---

## 3. Duas experiências, os mesmos dados

O aplicativo abre em uma de duas versões. A escolha fica salva no aparelho (`SharedPreferences`) e decide só a navegação — nenhum cálculo muda.

| Formetas (financeiro) | Formigueiro (gamificado) | O que mostra |
| --- | --- | --- |
| Início | Entrada | Visão geral do mês e do patrimônio |
| Movimentos | O mês | Fluxo do mês, consistência, extrato |
| Carteira | Armazéns | Caixinhas e investimentos |
| Metas | Missões | Objetivos de longo prazo + missões do mês |
| Relatórios | Conquistas | Estatísticas / conquistas desbloqueadas |

Entrar no formigueiro **troca a navegação inteira**, não só a tela. Sai-se pelo botão “Voltar ao Formetas”. R$ 1 equivale a 1 folhinha na leitura lúdica; o valor em reais aparece sempre ao lado.

---

## 4. Funções do aplicativo

### 4.1 Conta e perfil

- Cadastro com nome, e-mail e senha.
- Login e recuperação de senha por e-mail (Firebase Auth).
- Edição do nome no perfil.
- Logout com redirecionamento imediato para o login (o roteador consulta o usuário atual do Firebase no mesmo instante, sem esperar o stream atrasar).
- Tema claro, escuro ou do sistema.
- Taxa de CDI usada nas caixinhas (configurável).

### 4.2 Movimentações (o mundo externo)

Tudo que entra ou sai da vida financeira “de verdade”:

- **Receita** — salário, freelance, 13º, presente, etc.
- **Despesa** — mercado, aluguel, lazer, contas.

Cada lançamento tem categoria, valor, data, descrição e, se quiser, observações, forma de pagamento e recorrência. O extrato une transações e transferências numa linha do tempo só, com filtro por tipo, mês e busca.

Categorias vêm de uma lista padrão (alimentação, moradia, salário…) somada às que a pessoa cria. Dá para reordenar as personalizadas.

### 4.3 Caixinhas

Cada caixinha tem nome, tipo (CDB, poupança, tesouro, LCI/LCA…), data de início, banco opcional e regra de rendimento:

- **% do CDI** (100%, 110%…) usando a taxa configurada no app, ou
- **taxa fixa** anual.

Aportes e resgates entram no histórico. O valor atual **não é um número digitado**: é recalculado a partir do histórico + juros. Não dá para resgatar mais do que o saldo atualizado (principal + rendimento até agora).

### 4.4 Carteira de investimentos

Inspirada na carteira do Investidor10: ativos agrupados em seções recolhíveis (Ações, FIIs, ETFs, BDRs, Criptomoedas, Renda fixa, Outros).

Cada ativo tem:

- ticker e nome
- quantidade e preço médio (derivados dos lançamentos)
- cotação atual (busca pública ou digitada)
- variação, rentabilidade, saldo, % da carteira
- meta de alocação opcional (“comprar?” quando está abaixo do alvo)

**Lançamentos:** compra, venda ou provento.

- Compra tira do saldo na hora.
- Venda e provento devolvem ao saldo.
- Nada disso vira receita ou despesa do mês: vira transferência interna, com o ticker no extrato.

Na busca de um papel novo, a pessoa digita `mx` e escolhe **MXRF11 · FII Maxi Renda**, com nome e último preço — o mesmo gesto da tela de lançamento do Investidor10. A fonte é o catálogo público da [brapi](https://brapi.dev/docs/tickers) (ações, FIIs, ETFs, BDRs). Cripto e renda fixa continuam manuais.

Investimentos antigos (o “balde” único de antes da carteira por ativo) continuam visíveis num bloco **Outros investimentos**, para ninguém perder dinheiro de vista.

### 4.5 Transferências entre bolsos

Qualquer rota:

```
Saldo  ⇄  Caixinha
Saldo  ⇄  Investimentos (legado)
Caixinha  ⇄  Investimentos
```

Regras: origem ≠ destino; o valor não pode passar do disponível na origem naquele momento. Compra e venda de ativos usam o mesmo mecanismo por baixo.

### 4.6 Metas

Objetivo com nome, valor-alvo, valor atual e prazo. É o “para onde o trabalho de formiguinha está indo”: viagem, reserva de X meses, quitar dívida.

### 4.7 Relatórios

Receitas vs. despesas no tempo, categorias, médias mensais, maiores lançamentos, evolução do saldo, total de reservas e rendimento. Gráficos com `fl_chart`.

### 4.8 Formigueiro

Camada de leitura sobre os mesmos dados:

- **Entrada** — formiga, nível, inverno, resumo das folhinhas.
- **O mês** — fluxo do mês e consistência.
- **Armazéns** — caixinhas e carteira como estoque do formigueiro.
- **Missões** — missões do mês + metas de longo prazo.
- **Conquistas** — grade do que já foi desbloqueado.
- **Cuidar da formiga** — nome e preferência de animação.

Nível, conquistas e missões vêm de um catálogo (`anthill_catalog.dart`). O banco guarda só o nome da formiga, quando cada conquista aconteceu e se as animações estão ligadas. Nenhum valor financeiro é copiado para lá.

---

## 5. Lógicas (o que a apresentação precisa explicar)

As regras importantes moram no **domínio**, não na tela. A UI pede e mostra.

### 5.1 Saldo mensal (o “banco interno”)

O saldo **não** é receita menos despesa do mês isolado. Ele carrega o mês anterior:

```
saldo final do mês =
  saldo inicial
  + receitas
  − despesas
  + transferências que entram no saldo
  − transferências que saem do saldo
```

Guardar R$ 500 na caixinha diminui o saldo disponível e **não** aparece como gasto. Resgatar devolve ao saldo sem aparecer como renda. Comprar 10 PETR4 tira o custo (quantidade × preço + taxas) do saldo do mesmo jeito.

Quem calcula isso é o `MonthlyBalanceCalculator`. O `PatrimonyCalculator` usa essa série para o saldo “agora”.

### 5.2 Rendimento da caixinha

`ReserveCalculator` simula **dia a dia**, com juros compostos:

1. Junta valor inicial + aportes − resgates em um calendário.
2. Taxa anual = taxa fixa **ou** CDI × (% do CDI).
3. Converte para taxa diária equivalente.
4. Cada dia: aplica o evento daquele dia, depois rende.
5. Cada aporte só começa a render a partir da data em que entrou.

Por isso duas caixinhas com o mesmo CDI podem ter valores diferentes: o histórico pesa. O valor gravado no banco é referência; o que a tela mostra é o resultado desse cálculo.

### 5.3 Posição de um ativo

Quantidade e preço médio **não são campos editáveis**. Vêm dos lançamentos, em ordem de data (`AssetCalculator`):

- **Compra** — preço médio ponderado; taxas entram no custo.
- **Venda** — realiza o lucro (preço de venda − preço médio − taxas) e reduz a quantidade, sem mexer no preço médio. Vender tudo zera a posição; a próxima compra recomeça do zero.
- **Provento** — só acumula. O dinheiro já está no saldo; não infla o valor da posição.

Valor de mercado = quantidade × cotação. Sem cotação informada, a posição vale o que custou (não inventa valorização).

Rentabilidade considera valorização + proventos + lucro já realizado nas vendas.

A cotação entra no patrimônio da home, dos relatórios e do Formigueiro.

### 5.4 Patrimônio (fonte única)

`PatrimonyCalculator` é a conta que dashboard, relatórios, transferências e Formigueiro usam:

```
saldo       → MonthlyBalanceCalculator
caixinhas   → ReserveCalculator em cada uma
investimentos → posições de mercado + eventuais investimentos legado
patrimônio  → soma dos três
rendimento  → juros das caixinhas + resultado da carteira
```

Assim não existem fórmulas divergentes entre telas.

### 5.5 Formigueiro (só leitura)

`AnthillService` recebe as mesmas listas do dashboard e devolve um `AnthillSnapshot`:

- **Folhinhas** = valores em reais arredondados (R$ 1 = 1 folhinha).
- **Nível da formiga** por patrimônio: Iniciante (0), Trabalhadora (1.000), Dedicada (5.000), Guardiã (10.000), Rainha (25.000).
- **Inverno** — meta simbólica de 6 meses de despesa média, pelo menos 3 armazéns e 3 meses seguidos guardando. Data simbólica: 21 de junho.
- **Energia** — leitura do hábito do mês (registrar, guardar, fechar positivo).
- **Missões do mês** — guardar no mês, fechar economizando, registrar 5 movimentações, ter caixinha, ter meta.
- **Conquistas** — 16 regras que só leem fatos já calculados (primeira movimentação, 3 caixinhas, 50 lançamentos, patrimônio de 25 mil, etc.).

Quando uma conquista é alcançada pela primeira vez, o app grava a data e pode mostrar uma comemoração. Isso não muda saldo nem patrimônio.

### 5.6 Autocomplete de ativos

A B3 não libera API para pessoa física. A busca usa `GET https://brapi.dev/api/v2/tickers?search=…`, que devolve símbolo, nome e último preço **sem token**, com CORS liberado (funciona no Flutter Web). Limite informal: da ordem de 20 consultas por minuto. Cotações pontuais (`/api/quote/{ticker}`) pedem cadastro; por isso a cotação de um papel já na carteira também passa pela busca, pegando o match exato do ticker.

---

## 6. Mapa de telas

### Acesso

| Tela | Rota | Função |
| --- | --- | --- |
| Splash | `/splash` | Logo, inicia Firebase, manda para a home da experiência salva |
| Login | `/auth/login` | E-mail e senha |
| Cadastro | `/auth/register` | Nome, e-mail, senha; atalho para quem já tem conta |
| Esqueci a senha | `/auth/forgot-password` | Envia e-mail de redefinição |

### Experiência financeira (`MainShell`)

Navegação inferior no celular; rail na lateral a partir de 900 px de largura.

| Tela | Rota | Função |
| --- | --- | --- |
| Início | `/` | Saldo do mês, receitas, despesas, economia, caixinhas, investimentos, banner para o Formigueiro |
| Movimentos | `/transactions` | Extrato unificado (transações + transferências) |
| Carteira | `/carteira` | Abas Caixinhas e Investimentos |
| Metas | `/goals` | Lista de objetivos |
| Relatórios | `/reports` | Gráficos e estatísticas |

O botão **Novo** abre um menu: receita, despesa, transferir, caixinha, investimento (lançamento), meta.

### Telas de formulário (fora da barra)

| Tela | Rota |
| --- | --- |
| Nova / editar transação | `/transaction/new`, `/transaction/edit/:id` |
| Nova caixinha / detalhe / editar | `/reserve/new`, `/reserve/:id`, `/reserve/edit/:id` |
| Transferência | `/transfer` |
| Novo lançamento de ativo | `/lancamento/novo` |
| Detalhe do ativo | `/ativo/:id` |
| Nova / editar meta | `/goal/new`, `/goal/edit/:id` |
| Categorias | `/categories` |
| Perfil | `/profile` |
| Configurações | `/settings` |

### Experiência Formigueiro (`AnthillShell`)

| Sala | Rota |
| --- | --- |
| Entrada | `/formigueiro` |
| O mês | `/formigueiro/mes` |
| Armazéns | `/formigueiro/armazens` |
| Missões | `/formigueiro/missoes` |
| Conquistas | `/formigueiro/conquistas` |
| Cuidar da formiga | `/formigueiro/formiga` |

Quem não está logado é mandado para `/auth/login`. Quem está logado e cai numa rota de auth volta para a home da experiência atual.

---

## 7. Tecnologias

| Camada | Tecnologia | Para quê |
| --- | --- | --- |
| App | Flutter / Dart 3.12+ | Android, iOS e Web com um código só |
| Estado | Riverpod 2 | Providers de stream (dados ao vivo) e de cálculo derivado |
| Rotas | GoRouter | Duas shells, redirect de auth, query params (`?aba=investimentos`) |
| Autenticação | Firebase Auth | E-mail/senha, reset, `userChanges()` para perfil e logout |
| Banco | Firebase Realtime Database | JSON por usuário, sincronização em tempo real |
| Observabilidade | Analytics + Crashlytics | Abertura do app; crashes no mobile |
| Preferências locais | SharedPreferences | Tema e modo Formetas/Formigueiro |
| Gráficos | fl_chart | Relatórios |
| Tipografia | google_fonts | Identidade visual |
| HTTP | package `http` | Busca de tickers na brapi |
| IDs | uuid | Chaves de lançamentos e entidades |
| Igualdade de entidades | equatable | Comparar objetos de domínio |
| Animação | flutter_animate + CustomPainter | Formiga e cena do formigueiro |
| Web | Flutter Web na Vercel | `vercel.json` + script que instala o Flutter no build |
| Testes | flutter_test | Núcleo financeiro, carteira, Formigueiro e layout |

Identidade visual: verde ` #2F4F3F `, creme de fundo, laranja de acento. Logo em `assets/images/logo.png`; favicon web em `logo-sem-fundo.png`. Locale fixo: `pt_BR`.

---

## 8. Hierarquia do código

Clean Architecture enxuta: a tela não calcula patrimônio; o Firebase não decide se a transferência é válida.

```
formetas/lib/
  main.dart                 → bootstrap()
  app.dart                  → MaterialApp.router, tema, locale

  core/                     → o que qualquer camada pode usar
    config/                 → Firebase options, URL do RTDB
    constants/              → cores, textos, categorias padrão, catálogo do formigueiro
    router/                 → GoRouter e redirect de auth
    theme/                  → claro / escuro
    layout/                 → breakpoints (900 px desktop, 1100 px rail estendido)
    utils/                  → calculadoras (saldo, caixinha, ativo, patrimônio, folhinhas)

  domain/                   → regras de negócio, sem Flutter e sem Firebase
    entities/               → Transaction, Reserve, Asset, Transfer, Goal, AnthillSnapshot…
    repositories/           → contratos (interfaces)
    services/               → TransferService, AssetTradeService, DashboardService, AnthillService

  data/                     → implementação dos contratos
    datasources/            → Auth, RTDB, brapi
    models/                 → toMap / fromMap (campos em português no banco)
    repositories/           → *Impl que só delega ao datasource

  presentation/             → Flutter
    providers/              → Riverpod (auth, dados, modo do app, formigueiro)
    screens/                → uma pasta por área
    widgets/                → cards, logo, seções da carteira, formiga, salas
```

### Como um dado atravessa as camadas

Exemplo: **comprar MXRF11**.

1. A tela `AssetTradeFormScreen` busca o ticker na brapi e monta quantidade × preço.
2. Chama `AssetTradeService.registerTrade`.
3. O serviço valida saldo (`PatrimonyCalculator` + `CurrencyFormatter.exceeds` em centavos), cria uma `TransferEntity` (saldo → investimento) e um `AssetTradeEntity`.
4. Os repositórios gravam em `users/{uid}/transfers` e `users/{uid}/ativos/{id}/lancamentos`.
5. Os `StreamProvider` disparam. `portfolioProvider` recalcula a posição. `dashboardStatsProvider` e `anthillSnapshotProvider` atualizam sozinhos.

Nenhuma tela soma patrimônio na mão.

### Providers que valem a pena citar no slide de arquitetura

| Provider | Papel |
| --- | --- |
| `authStateProvider` | Usuário logado (stream `userChanges`) |
| `transactionsProvider`, `transfersProvider`, `reservesWithMovementsProvider`, `assetsProvider` | Listas ao vivo do RTDB |
| `portfolioProvider` | Posições agrupadas por seção |
| `dashboardStatsProvider` | Números da home |
| `anthillSnapshotProvider` | Tradução gamificada |
| `appModeProvider` | Qual shell abrir |
| `routerProvider` | GoRouter que escuta o auth |

### O que dá para arrancar sem quebrar o financeiro

Pastas `presentation/screens/anthill/` e `presentation/widgets/anthill/`, `anthill_providers.dart` e o `ShellRoute` do formigueiro. O restante continua igual: a gamificação é camada, não núcleo.

---

## 9. Estrutura do banco

Firebase Realtime Database (projeto `formetas-85c14`). Tudo de uma pessoa vive sob o UID dela. Não há coleção global de transações.

```
users/{uid}/
  profile/                          # nome, e-mail, data de cadastro
  settings/                         # moeda, tema, taxa CDI, 1º dia do mês
  transactions/{id}/
  transfers/{id}/
  reserves/{id}/
    movimentacoes/{id}/             # aportes e resgates da caixinha
  investments/{id}/                 # carteira legado (balde único)
  ativos/{id}/                      # papéis da carteira por ativo
    lancamentos/{id}/
  goals/{id}/
  categories/{id}/                  # só as personalizadas
  formigueiro/                      # nome da formiga, conquistas, animações
```

O Realtime Database é um JSON. Cada `{id}` é um filho com mapa de campos. Os models aceitam chaves em português (`valor`, `data`) e inglês (`amount`, `date`) para não quebrar dados antigos.

### Campos principais

**Perfil (`profile`)**

| Campo | Significado |
| --- | --- |
| `nome` | Nome exibido |
| `email` | E-mail da conta |
| `dataCadastro` | ISO 8601 |
| `emailVerified` | Se o e-mail foi verificado no Auth |

**Configurações (`settings`)**

| Campo | Significado |
| --- | --- |
| `moeda` | `BRL` |
| `tema` | `light`, `dark`, `system` |
| `cdiRate` | Taxa anual do CDI (ex.: 13.25) |
| `primeiroDiaDoMes` | Dia em que o “mês” começa |
| `notificações` | Preferência (reservada) |

**Transação**

| Campo | Significado |
| --- | --- |
| `tipo` | `income`, `expense` (há também `investment` legado) |
| `categoria`, `valor`, `data`, `descrição` | Lançamento |
| `recorrente`, `formaPagamento`, `pago`, `parcelada` | Extras |

**Transferência**

| Campo | Significado |
| --- | --- |
| `deTipo` / `paraTipo` | `balance`, `reserve`, `investment` |
| `deId` / `paraId` | ID da caixinha ou do ativo, quando couber |
| `valor`, `data`, `descricao` | Movimento interno |

**Caixinha**

| Campo | Significado |
| --- | --- |
| `nome`, `tipo`, `banco` | Identidade |
| `valorInicial`, `dataInicio` | Ponto de partida |
| `percentualCDI` ou `taxaFixa` | Regra de rendimento |
| `movimentacoes/{id}` | `tipo` = `aporte` \| `resgate`, `valor`, `data` |

**Ativo de mercado**

| Campo | Significado |
| --- | --- |
| `ticker`, `nome`, `classe` | `acao`, `fii`, `etf`, `bdr`, `cripto`… |
| `precoAtual`, `precoAtualizadoEm` | Cotação |
| `metaPercentual` | Alvo de alocação |
| `lancamentos/{id}` | `tipo` `buy` \| `sell` \| `dividend`, quantidade, preço, taxas, `valor`, `transferenciaId` |

O `transferenciaId` liga o lançamento à transferência do saldo. Apagar o lançamento desfaz o movimento no saldo.

**Meta**

`nome`, `valorMeta`, `valorAtual`, `dataObjetivo`.

**Formigueiro**

`nomeFormiga`, `animacoes`, `nivelCelebrado`, `conquistas/{id}` = data em que desbloqueou.

### O que o banco não guarda

- Saldo disponível (é derivado).
- Valor atualizado da caixinha (é derivado).
- Quantidade e preço médio do ativo (são derivados).
- Nível da formiga, missões e se a conquista “já foi alcançada” em termos financeiros (o catálogo recalcula; o banco só lembra *quando* celebrou).

### Auth versus banco

O Firebase Auth guarda e-mail, senha e `displayName`. O nó `profile` no RTDB é a cópia que o app lê para a tela de perfil. Atualizar o nome mexe nos dois.

---

## 10. Layout e identidade

- **&lt; 900 px:** barra inferior + FAB “Novo”.
- **≥ 900 px:** menu na lateral; conteúdo em tela cheia.
- **≥ 1100 px:** rail com rótulos ao lado dos ícones.
- Carteira de investimentos: no celular cada ativo é um cartão; no desktop (≥ 820 px na seção) vira tabela (ticker, quantidade, preço médio, cotação, variação, rentabilidade, saldo, % carteira, comprar?).
- Salas do Formigueiro em tela larga usam duas colunas (`AnthillRoom`).
- Tema claro (creme + verde) e escuro (superfícies `#1A1F1A` / `#2A332A`).

---

## 11. Testes

A suíte cobre o que a apresentação chama de “núcleo”:

| Arquivo | O que garante |
| --- | --- |
| `financial_core_test.dart` | Saldo, transferências e patrimônio não quebraram com a gamificação |
| `asset_wallet_test.dart` | Preço médio, venda, provento, seções, patrimônio com cotação |
| `asset_wallet_widgets_test.dart` | Tabela da carteira cabe no celular e no desktop |
| `market_quote_mapper_test.dart` | Tipo brapi → seção da carteira; nome curto de FII |
| `anthill_service_test.dart` | Snapshot, níveis, missões |
| `anthill_rooms_test.dart` / `anthill_widgets_test.dart` | Salas e formiga renderizam claro/escuro, estreito e largo |

```bash
cd formetas
flutter test
```

---

## 12. Como rodar e publicar

Pré-requisito: [Flutter SDK](https://docs.flutter.dev/get-started/install).

```bash
cd formetas
flutter pub get
flutter run                 # dispositivo / emulador
flutter run -d chrome       # web local
flutter build web --release --no-wasm-dry-run
```

**Vercel:** `vercel.json` na raiz do repositório chama `scripts/vercel-build.sh`, que instala o Flutter e gera `formetas/build/web`. Há rewrite para `index.html` (rotas do GoRouter na web) e cache longo nos JS imutáveis.

No [Firebase Console](https://console.firebase.google.com) → Authentication → Settings → **Authorized domains**, incluir `*.vercel.app` (e o domínio próprio). Sem isso o login na web falha.

Crashlytics só no mobile; na web o `bootstrap` não registra o handler nativo.

---

## 13. Princípio de produto (para fechar a apresentação)

O Formetas assume que o hábito aparece quando o registro é honesto:

- o que saiu da conta **para guardar** não é gasto
- o que voltou **de um resgate** não é salário
- a ação que valorizou **muda o patrimônio**, e isso precisa aparecer na home e no formigueiro com o mesmo número
- a formiga evolui porque o patrimônio evoluiu, não porque alguém marcou um checkbox

Cada tela reforça isso com mensagens curtas, sem tom de cobrança. O objetivo é tornar o próximo passo óbvio — formiguinha por formiguinha.

---

## 14. Roteiro sugerido de slides

Use as seções acima nesta ordem, uma ideia por slide:

1. **Capa** — Formetas, tagline, logo.
2. **O problema** — receita/despesa mente quando o dinheiro só mudou de lugar.
3. **A ideia** — três bolsos + trabalho de formiguinha.
4. **Os três bolsos** — tabela da seção 2.
5. **Patrimônio** — a soma; fonte única (`PatrimonyCalculator`).
6. **Duas experiências** — Formetas × Formigueiro, mesmos dados.
7. **Tour financeiro** — Início, Movimentos, Carteira, Metas, Relatórios (prints).
8. **Caixinha** — juros dia a dia, aportes com data.
9. **Carteira de ativos** — seções, lançamento, busca tipo Investidor10.
10. **Transferência** — o mecanismo que costura os bolsos.
11. **Formigueiro** — salas, folhinhas, níveis, inverno, missões, conquistas.
12. **Camada de leitura** — o que se apaga sem quebrar o financeiro.
13. **Arquitetura** — `core` / `domain` / `data` / `presentation` + o fluxo da compra.
14. **Banco** — árvore `users/{uid}`; o que é derivado vs. o que é gravado.
15. **Stack** — Flutter, Riverpod, GoRouter, Firebase, brapi, Vercel.
16. **Layout** — mobile × desktop.
17. **Demo ao vivo** — cadastrar despesa, guardar na caixinha, comprar um FII, entrar no formigueiro.
18. **O que não é** — sem Open Finance, sem B3 B2B, sem ordem na corretora.
19. **Fechamento** — disciplina como acumulação; o app só torna o hábito visível.
