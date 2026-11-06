import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_strings.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../domain/entities/onboarding_draft.dart';
import '../../../domain/entities/settings_entity.dart';
import '../../providers/app_mode_provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/core_providers.dart';
import '../../providers/data_providers.dart';
import '../../providers/onboarding_provider.dart';
import '../../widgets/app_logo.dart';

class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  final _pageController = PageController();
  final _balanceController = TextEditingController();
  final _caixinhas = <_CaixinhaDraft>[];

  int _page = 0;
  bool _saving = false;
  bool _leaving = false;

  @override
  void dispose() {
    _pageController.dispose();
    _balanceController.dispose();
    for (final item in _caixinhas) {
      item.dispose();
    }
    super.dispose();
  }

  double get _balance => CurrencyFormatter.parse(_balanceController.text) ?? 0;

  OnboardingDraft get _draft {
    return OnboardingDraft(
      availableBalance: _balance,
      reserves: [
        for (final item in _caixinhas)
          if (item.nameController.text.trim().isNotEmpty && item.amount > 0)
            OnboardingReserveDraft(
              name: item.nameController.text,
              amount: item.amount,
            ),
      ],
    );
  }

  Future<void> _goTo(int page) async {
    setState(() => _page = page);
    await _pageController.animateToPage(
      page,
      duration: const Duration(milliseconds: 320),
      curve: Curves.easeOutCubic,
    );
  }

  Future<void> _markComplete(SettingsEntity settings) async {
    final user = ref.read(currentUserProvider);
    if (user == null) return;
    await ref
        .read(onboardingServiceProvider)
        .markCompleted(userId: user.id, settings: settings);
    await ref
        .read(settingsLocalDataSourceProvider)
        .setOnboardingComplete(user.id);
  }

  Future<void> _leaveToHome() async {
    if (!mounted) return;
    context.go(ref.read(appModeProvider).homeRoute);
  }

  Future<void> _skipExistingAccount(SettingsEntity settings) async {
    if (_leaving) return;
    _leaving = true;
    await _markComplete(settings);
    await _leaveToHome();
  }

  Future<void> _finish() async {
    if (_saving) return;
    final user = ref.read(currentUserProvider);
    if (user == null) return;

    final unnamed = _caixinhas.any(
      (item) => item.amount > 0 && item.nameController.text.trim().isEmpty,
    );
    if (unnamed) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Dê um nome para cada caixinha.')),
      );
      return;
    }

    if (_balanceController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Informe quanto tem na conta. Se estiver zerada, digite 0.',
          ),
        ),
      );
      return;
    }

    setState(() => _saving = true);
    try {
      final settings =
          ref.read(settingsProvider).valueOrNull ?? const SettingsEntity();
      await ref
          .read(onboardingServiceProvider)
          .complete(userId: user.id, draft: _draft, settings: settings);
      await ref
          .read(settingsLocalDataSourceProvider)
          .setOnboardingComplete(user.id);
      await _leaveToHome();
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Não foi possível salvar a configuração. Tente de novo.',
          ),
          backgroundColor: AppColors.expense,
        ),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _continueFromBalance() {
    if (_balanceController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Informe quanto tem na conta. Se estiver zerada, digite 0.',
          ),
        ),
      );
      return;
    }
    _goTo(2);
  }

  void _addCaixinha() {
    setState(() => _caixinhas.add(_CaixinhaDraft()));
  }

  void _removeCaixinha(int index) {
    setState(() {
      _caixinhas.removeAt(index).dispose();
    });
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(currentUserProvider);
    final settings = ref.watch(settingsProvider);
    final transactions = ref.watch(transactionsProvider);
    final reserves = ref.watch(reservesWithMovementsProvider);

    if (user == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final pending =
        settings.isLoading ||
        (transactions.isLoading && !transactions.hasValue) ||
        (reserves.isLoading && !reserves.hasValue);

    if (pending) {
      return const Scaffold(
        backgroundColor: AppColors.background,
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final currentSettings = settings.valueOrNull ?? const SettingsEntity();
    final hasHistory =
        (transactions.valueOrNull?.isNotEmpty ?? false) ||
        (reserves.valueOrNull?.isNotEmpty ?? false);

    if (!_leaving && (currentSettings.onboardingCompleted || hasHistory)) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _skipExistingAccount(currentSettings);
      });
      return const Scaffold(
        backgroundColor: AppColors.background,
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 8, 20, 0),
              child: Row(
                children: [
                  if (_page > 0)
                    IconButton(
                      onPressed: _saving ? null : () => _goTo(_page - 1),
                      icon: const Icon(Icons.arrow_back_rounded),
                    )
                  else
                    const SizedBox(width: 48),
                  const Spacer(),
                  _Dots(index: _page),
                  const Spacer(),
                  const SizedBox(width: 48),
                ],
              ),
            ),
            Expanded(
              child: PageView(
                controller: _pageController,
                physics: const NeverScrollableScrollPhysics(),
                onPageChanged: (value) => setState(() => _page = value),
                children: [
                  _IntroPage(onContinue: () => _goTo(1)),
                  _BalancePage(
                    controller: _balanceController,
                    onChanged: () => setState(() {}),
                    onContinue: _continueFromBalance,
                  ),
                  _ReservesPage(
                    items: _caixinhas,
                    balance: _balance,
                    saving: _saving,
                    onAdd: _addCaixinha,
                    onRemove: _removeCaixinha,
                    onChanged: () => setState(() {}),
                    onFinish: () => _finish(),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CaixinhaDraft {
  _CaixinhaDraft()
    : nameController = TextEditingController(),
      amountController = TextEditingController();

  final TextEditingController nameController;
  final TextEditingController amountController;

  double get amount => CurrencyFormatter.parse(amountController.text) ?? 0;

  void dispose() {
    nameController.dispose();
    amountController.dispose();
  }
}

class _Dots extends StatelessWidget {
  const _Dots({required this.index});

  final int index;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 0; i < 3; i++)
          AnimatedContainer(
            duration: const Duration(milliseconds: 220),
            margin: const EdgeInsets.symmetric(horizontal: 4),
            width: i == index ? 22 : 8,
            height: 8,
            decoration: BoxDecoration(
              color: i == index
                  ? AppColors.primary
                  : AppColors.primary.withValues(alpha: 0.22),
              borderRadius: BorderRadius.circular(99),
            ),
          ),
      ],
    );
  }
}

class _IntroPage extends StatelessWidget {
  const _IntroPage({required this.onContinue});

  final VoidCallback onContinue;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
      child: Column(
        children: [
          Expanded(
            child: ListView(
              children: [
                const SizedBox(height: 12),
                const Center(
                  child: AppLogo(size: 96, showShadow: true),
                ).animate().scale(duration: 500.ms, curve: Curves.easeOutBack),
                const SizedBox(height: 28),
                Text(
                  'Bem-vindo ao ${AppStrings.appName}',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: AppColors.primary,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  AppStrings.tagline,
                  textAlign: TextAlign.center,
                  style: TextStyle(color: AppColors.gray, height: 1.4),
                ),
                const SizedBox(height: 32),
                const _IntroPoint(
                  icon: Icons.savings_outlined,
                  title: 'Saldo e caixinhas separados',
                  body:
                      'O disponível na conta é um bolso. O que já está guardado é outro. Assim o patrimônio não se mistura.',
                ),
                const SizedBox(height: 14),
                const _IntroPoint(
                  icon: Icons.today_rounded,
                  title: 'Você começa a partir de hoje',
                  body:
                      'Informe o que tem agora. Daqui pra frente, cada receita e despesa entra limpa, sem inventar o passado.',
                ),
                const SizedBox(height: 14),
                const _IntroPoint(
                  icon: Icons.pets_rounded,
                  title: 'Trabalho de formiguinha',
                  body:
                      'Não precisa acertar tudo de uma vez. O Formetas existe para ir juntando o caminho, um passo por dia.',
                ),
              ],
            ),
          ),
          FilledButton(
            onPressed: onContinue,
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.primary,
              minimumSize: const Size.fromHeight(52),
            ),
            child: const Text('Vamos configurar'),
          ),
        ],
      ),
    );
  }
}

class _IntroPoint extends StatelessWidget {
  const _IntroPoint({
    required this.icon,
    required this.title,
    required this.body,
  });

  final IconData icon;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: AppColors.primary, size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    color: AppColors.primary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  body,
                  style: TextStyle(
                    color: AppColors.gray,
                    height: 1.35,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _BalancePage extends StatelessWidget {
  const _BalancePage({
    required this.controller,
    required this.onChanged,
    required this.onContinue,
  });

  final TextEditingController controller;
  final VoidCallback onChanged;
  final VoidCallback onContinue;

  @override
  Widget build(BuildContext context) {
    final value = CurrencyFormatter.parse(controller.text) ?? 0;

    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
      child: Column(
        children: [
          Expanded(
            child: ListView(
              children: [
                Text(
                  'Quanto você tem disponível hoje?',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: AppColors.primary,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  'É o dinheiro livre na conta, o que dá para gastar agora. Caixinhas e investimentos entram no próximo passo.',
                  style: TextStyle(color: AppColors.gray, height: 1.4),
                ),
                const SizedBox(height: 28),
                TextField(
                  controller: controller,
                  autofocus: true,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  inputFormatters: CurrencyFormatter.inputFormatters,
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: AppColors.primary,
                  ),
                  decoration: const InputDecoration(
                    labelText: 'Saldo disponível',
                    prefixText: 'R\$ ',
                  ),
                  onChanged: (_) => onChanged(),
                ),
                const SizedBox(height: 16),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.secondary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Text(
                    value <= 0
                        ? 'Digite 0 se a conta está zerada. Esse dia fica gravado: o que for anterior entra no histórico e não mexe no saldo.'
                        : 'Esse valor é o saldo de hoje e não entra como receita. Lançamentos anteriores a este dia ficam no histórico.',
                    style: TextStyle(color: AppColors.primary, height: 1.35),
                  ),
                ),
              ],
            ),
          ),
          FilledButton(
            onPressed: onContinue,
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.primary,
              minimumSize: const Size.fromHeight(52),
            ),
            child: const Text('Continuar'),
          ),
        ],
      ),
    );
  }
}

class _ReservesPage extends StatelessWidget {
  const _ReservesPage({
    required this.items,
    required this.balance,
    required this.saving,
    required this.onAdd,
    required this.onRemove,
    required this.onChanged,
    required this.onFinish,
  });

  final List<_CaixinhaDraft> items;
  final double balance;
  final bool saving;
  final VoidCallback onAdd;
  final ValueChanged<int> onRemove;
  final VoidCallback onChanged;
  final VoidCallback onFinish;

  @override
  Widget build(BuildContext context) {
    final reservesTotal = items.fold(0.0, (sum, item) => sum + item.amount);
    final netWorth = balance + reservesTotal;

    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
      child: Column(
        children: [
          Expanded(
            child: ListView(
              children: [
                Text(
                  'Você tem caixinhas?',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: AppColors.primary,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  'Se já tem dinheiro separado (emergência, viagem, reserva), cadastre o valor de hoje. Depósitos e saques anteriores a este dia não mudam esse valor.',
                  style: TextStyle(color: AppColors.gray, height: 1.4),
                ),
                const SizedBox(height: 20),
                if (items.isEmpty)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: AppColors.white,
                      borderRadius: BorderRadius.circular(18),
                    ),
                    child: Column(
                      children: [
                        Icon(
                          Icons.inventory_2_outlined,
                          size: 36,
                          color: AppColors.gray.withValues(alpha: 0.7),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          'Nenhuma caixinha ainda. Pode pular se não tiver.',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: AppColors.gray),
                        ),
                      ],
                    ),
                  )
                else
                  for (var i = 0; i < items.length; i++) ...[
                    _CaixinhaCard(
                      item: items[i],
                      onChanged: onChanged,
                      onRemove: () => onRemove(i),
                    ),
                    const SizedBox(height: 12),
                  ],
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton.icon(
                    onPressed: saving ? null : onAdd,
                    icon: const Icon(Icons.add_rounded),
                    label: Text(
                      items.isEmpty ? 'Adicionar caixinha' : 'Adicionar outra',
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.primary,
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Como o Formetas vai abrir',
                        style: TextStyle(
                          color: AppColors.white.withValues(alpha: 0.8),
                          fontSize: 12,
                        ),
                      ),
                      const SizedBox(height: 10),
                      _SummaryLine(
                        label: 'Saldo disponível',
                        value: CurrencyFormatter.format(balance),
                      ),
                      _SummaryLine(
                        label: 'Caixinhas',
                        value: CurrencyFormatter.format(reservesTotal),
                      ),
                      const Divider(color: Colors.white24),
                      _SummaryLine(
                        label: 'Patrimônio inicial',
                        value: CurrencyFormatter.format(netWorth),
                        emphasize: true,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          FilledButton(
            onPressed: saving ? null : onFinish,
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.secondary,
              minimumSize: const Size.fromHeight(52),
            ),
            child: saving
                ? const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.4,
                      color: Colors.white,
                    ),
                  )
                : const Text('Começar a usar'),
          ),
        ],
      ),
    );
  }
}

class _CaixinhaCard extends StatelessWidget {
  const _CaixinhaCard({
    required this.item,
    required this.onChanged,
    required this.onRemove,
  });

  final _CaixinhaDraft item;
  final VoidCallback onChanged;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 8, 8, 16),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Caixinha',
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    color: AppColors.primary,
                  ),
                ),
              ),
              IconButton(
                onPressed: onRemove,
                icon: const Icon(Icons.close_rounded),
                tooltip: 'Remover',
              ),
            ],
          ),
          TextField(
            controller: item.nameController,
            textCapitalization: TextCapitalization.sentences,
            decoration: const InputDecoration(
              labelText: 'Nome',
              hintText: 'Emergência, viagem, reforma...',
            ),
            onChanged: (_) => onChanged(),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: item.amountController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: CurrencyFormatter.inputFormatters,
            decoration: const InputDecoration(
              labelText: 'Quanto tem hoje',
              prefixText: 'R\$ ',
            ),
            onChanged: (_) => onChanged(),
          ),
        ],
      ),
    );
  }
}

class _SummaryLine extends StatelessWidget {
  const _SummaryLine({
    required this.label,
    required this.value,
    this.emphasize = false,
  });

  final String label;
  final String value;
  final bool emphasize;

  @override
  Widget build(BuildContext context) {
    final style = TextStyle(
      color: AppColors.white,
      fontWeight: emphasize ? FontWeight.w800 : FontWeight.w500,
      fontSize: emphasize ? 16 : 14,
    );
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          Expanded(child: Text(label, style: style)),
          Text(value, style: style),
        ],
      ),
    );
  }
}
