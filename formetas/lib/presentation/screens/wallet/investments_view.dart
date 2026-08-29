import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../domain/entities/investment_entity.dart';
import '../../../domain/entities/market_quote.dart';
import '../../../domain/repositories/market_quote_repository.dart';
import '../../providers/core_providers.dart';
import '../../providers/data_providers.dart';
import '../../widgets/wallet/asset_section.dart';

/// Carteira de investimentos por ativo, agrupada em seções.
/// Vive dentro da Carteira, por isso não tem Scaffold.
class InvestmentsView extends ConsumerStatefulWidget {
  const InvestmentsView({super.key});

  @override
  ConsumerState<InvestmentsView> createState() => _InvestmentsViewState();
}

class _InvestmentsViewState extends ConsumerState<InvestmentsView> {
  bool _refreshing = false;

  Future<void> _refreshQuotes() async {
    final portfolio = ref.read(portfolioProvider).valueOrNull;
    if (portfolio == null || _refreshing) return;

    setState(() => _refreshing = true);
    var updated = 0;
    try {
      final quotes = ref.read(marketQuoteRepositoryProvider);
      final trades = ref.read(assetTradeServiceProvider);
      for (final position in portfolio.openPositions) {
        if (!MarketQuoteMapper.isListed(position.asset.assetClass)) continue;
        final quote = await quotes.lookup(position.asset.ticker);
        final price = quote?.price;
        if (price == null) continue;
        await trades.saveAsset(
          position.asset.copyWith(
            name: position.asset.name.trim().isEmpty
                ? quote!.name
                : position.asset.name,
            currentPrice: price,
            priceUpdatedAt: DateTime.now(),
          ),
        );
        updated += 1;
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            updated == 0
                ? 'Nenhuma cotação encontrada agora'
                : '$updated cotações atualizadas',
          ),
        ),
      );
    } on MarketQuoteException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message), backgroundColor: AppColors.expense),
      );
    } finally {
      if (mounted) setState(() => _refreshing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final portfolio = ref.watch(portfolioProvider);
    final investments = ref.watch(investmentsProvider);

    return portfolio.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Erro: $e')),
      data: (summary) {
        final legacy = investments.valueOrNull ?? const <InvestmentEntity>[];

        return ListView(
          padding: const EdgeInsets.all(20),
          children: [
            PortfolioHeaderCard(portfolio: summary),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: () => context.push('/lancamento/novo'),
              icon: const Icon(Icons.add_rounded),
              label: const Text('Novo lançamento'),
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.investment,
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
            ),
            if (summary.openPositions.isNotEmpty) ...[
              const SizedBox(height: 8),
              OutlinedButton.icon(
                onPressed: _refreshing ? null : _refreshQuotes,
                icon: _refreshing
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.refresh_rounded),
                label: Text(
                  _refreshing ? 'Atualizando cotações...' : 'Atualizar cotações',
                ),
              ),
            ],
            const SizedBox(height: 24),
            if (summary.isEmpty)
              const _EmptyPortfolio()
            else
              for (final group in summary.groups)
                AssetClassSection(
                  summary: group,
                  portfolio: summary,
                  onOpenAsset: (position) =>
                      context.push('/ativo/${position.asset.id}'),
                ),
            if (legacy.isNotEmpty) ...[
              const SizedBox(height: 8),
              _LegacyInvestments(investments: legacy),
            ],
          ],
        );
      },
    );
  }
}

class _EmptyPortfolio extends StatelessWidget {
  const _EmptyPortfolio();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const SizedBox(height: 24),
        Icon(
          Icons.pie_chart_outline_rounded,
          size: 64,
          color: AppColors.gray.withValues(alpha: 0.5),
        ),
        const SizedBox(height: 16),
        const Text(
          'Sua carteira está vazia',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        ),
        const SizedBox(height: 8),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Text(
            'Registre a primeira compra de uma ação, FII, ETF ou cripto. '
            'O valor sai do seu saldo e passa a valer pela cotação.',
            style: TextStyle(color: AppColors.gray, fontSize: 13),
            textAlign: TextAlign.center,
          ),
        ),
      ],
    );
  }
}

/// Valores lançados no formato antigo, antes da carteira por ativo.
/// Ficam visíveis para que ninguém perca dinheiro de vista.
class _LegacyInvestments extends StatelessWidget {
  const _LegacyInvestments({required this.investments});

  final List<InvestmentEntity> investments;

  @override
  Widget build(BuildContext context) {
    final total = investments.fold(0.0, (sum, i) => sum + i.currentValue);
    if (total <= 0) return const SizedBox.shrink();

    return Card(
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Outros investimentos',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      Text(
                        'Lançados antes da carteira por ativo',
                        style: TextStyle(color: AppColors.gray, fontSize: 12),
                      ),
                    ],
                  ),
                ),
                Text(
                  CurrencyFormatter.format(total),
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ),
          for (final investment in investments)
            if (investment.currentValue > 0)
              ListTile(
                title: Text(investment.name),
                trailing: Text(
                  CurrencyFormatter.format(investment.currentValue),
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                onTap: () => context.push('/investment/edit/${investment.id}'),
              ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => context.push(
                      '/transfer?from=balance&to=investment'
                      '&toId=${investments.first.id}',
                    ),
                    icon: const Icon(Icons.add_rounded, size: 18),
                    label: const Text('Aportar'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => context.push(
                      '/transfer?from=investment'
                      '&fromId=${investments.first.id}&to=balance',
                    ),
                    icon: const Icon(Icons.remove_rounded, size: 18),
                    label: const Text('Resgatar'),
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
