import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/utils/asset_calculator.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../core/utils/number_formatter.dart';
import '../../../domain/entities/asset_entity.dart';
import '../../../domain/entities/market_quote.dart';
import '../../../domain/entities/asset_trade_entity.dart';
import '../../../domain/repositories/market_quote_repository.dart';
import '../../providers/core_providers.dart';
import '../../providers/data_providers.dart';
import '../../widgets/wallet/asset_section.dart';

class AssetDetailScreen extends ConsumerWidget {
  const AssetDetailScreen({super.key, required this.assetId});

  final String assetId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final assets = ref.watch(assetsProvider);

    return assets.when(
      loading: () => const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      ),
      error: (e, _) => Scaffold(
        appBar: AppBar(),
        body: Center(child: Text('Erro: $e')),
      ),
      data: (list) {
        final item = list.where((a) => a.asset.id == assetId).firstOrNull;
        if (item == null) {
          return Scaffold(
            appBar: AppBar(),
            body: const Center(child: Text('Ativo não encontrado')),
          );
        }

        final position = AssetCalculator.position(
          asset: item.asset,
          trades: item.trades,
        );
        final portfolio = ref.watch(portfolioProvider).valueOrNull;

        return _AssetDetailView(
          item: item,
          position: position,
          share: portfolio?.share(position.currentValue) ?? 0,
        );
      },
    );
  }
}

class _AssetDetailView extends ConsumerWidget {
  const _AssetDetailView({
    required this.item,
    required this.position,
    required this.share,
  });

  final AssetWithTrades item;
  final AssetPosition position;
  final double share;

  AssetEntity get asset => item.asset;

  Future<void> _editPrice(BuildContext context, WidgetRef ref) async {
    final value = await showDialog<double>(
      context: context,
      builder: (_) => _NumberDialog(
        title: 'Preço atual',
        label: 'Preço por ${AssetClassLabels.unitLabel(asset.assetClass)}',
        prefix: 'R\$ ',
        initialValue: asset.currentPrice,
        helper: 'Informe a cotação do dia para acompanhar a valorização.',
      ),
    );
    if (value == null) return;
    await ref.read(assetTradeServiceProvider).updatePrice(asset, value);
  }

  Future<void> _fetchQuote(BuildContext context, WidgetRef ref) async {
    try {
      final quote =
          await ref.read(marketQuoteRepositoryProvider).lookup(asset.ticker);
      if (!context.mounted) return;
      final price = quote?.price;
      if (quote == null || price == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Não achei cotação para ${asset.ticker}'),
          ),
        );
        return;
      }
      await ref.read(assetTradeServiceProvider).saveAsset(
            asset.copyWith(
              name: asset.name.trim().isEmpty ? quote.name : asset.name,
              currentPrice: price,
              priceUpdatedAt: DateTime.now(),
            ),
          );
    } on MarketQuoteException catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message), backgroundColor: AppColors.expense),
      );
    }
  }

  Future<void> _editTarget(BuildContext context, WidgetRef ref) async {
    final value = await showDialog<double>(
      context: context,
      builder: (_) => _NumberDialog(
        title: 'Meta de alocação',
        label: 'Percentual ideal',
        suffix: '%',
        initialValue: asset.targetPercent,
        helper: 'Quanto esse ativo deveria representar da carteira.',
      ),
    );
    if (value == null) return;
    await ref
        .read(assetTradeServiceProvider)
        .saveAsset(asset.copyWith(targetPercent: value));
  }

  Future<void> _confirmDelete(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('Remover ${asset.ticker}?'),
        content: const Text(
          'Os lançamentos são apagados e o dinheiro que eles moveram volta '
          'para o saldo como estava antes.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            style: FilledButton.styleFrom(backgroundColor: AppColors.expense),
            child: const Text('Remover'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;
    await ref.read(assetTradeServiceProvider).deleteAsset(item);
    if (context.mounted) context.pop();
  }

  Future<void> _removeTrade(
    BuildContext context,
    WidgetRef ref,
    AssetTradeEntity trade,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Apagar lançamento?'),
        content: const Text(
          'A posição é recalculada e o saldo volta ao que era antes.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            style: FilledButton.styleFrom(backgroundColor: AppColors.expense),
            child: const Text('Apagar'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;
    await ref.read(assetTradeServiceProvider).removeTrade(trade);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(
        title: Text(asset.ticker),
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_outline_rounded),
            tooltip: 'Remover ativo',
            onPressed: () => _confirmDelete(context, ref),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          _Header(position: position, share: share),
          const SizedBox(height: 20),
          _Metrics(
            position: position,
            onEditPrice: () => _editPrice(context, ref),
            onFetchQuote: MarketQuoteMapper.isListed(asset.assetClass)
                ? () => _fetchQuote(context, ref)
                : null,
          ),
          const SizedBox(height: 20),
          _Actions(assetId: asset.id, hasPosition: position.isOpen),
          const SizedBox(height: 20),
          _TargetCard(
            asset: asset,
            share: share,
            onEdit: () => _editTarget(context, ref),
          ),
          const SizedBox(height: 24),
          Text(
            'Lançamentos',
            style: Theme.of(context)
                .textTheme
                .titleMedium
                ?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          if (position.trades.isEmpty)
            Text(
              'Nenhum lançamento ainda.',
              style: TextStyle(color: AppColors.gray),
            )
          else
            for (final trade in position.trades)
              _TradeTile(
                trade: trade,
                asset: asset,
                onDelete: () => _removeTrade(context, ref, trade),
              ),
        ],
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.position, required this.share});

  final AssetPosition position;
  final double share;

  @override
  Widget build(BuildContext context) {
    final asset = position.asset;

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppColors.investment, AppColors.primary],
        ),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                assetClassIcon(asset.assetClass),
                color: Colors.white.withValues(alpha: 0.85),
                size: 18,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  asset.name.trim().isEmpty
                      ? AssetClassLabels.singular(asset.assetClass)
                      : asset.name,
                  style: TextStyle(color: Colors.white.withValues(alpha: 0.85)),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              CurrencyFormatter.format(position.currentValue),
              style: const TextStyle(
                color: Colors.white,
                fontSize: 30,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '${NumberFormatter.quantity(position.quantity)} × '
            '${NumberFormatter.price(position.currentPrice)}'
            ' · ${NumberFormatter.percent(share, decimals: 1)} da carteira',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.8),
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}

String _priceHint(AssetPosition position) {
  if (!position.hasQuote) {
    return 'Sem cotação informada. Enquanto isso, a posição vale o que custou.';
  }
  final updated = position.asset.priceUpdatedAt;
  if (updated == null) return 'Toque para atualizar a cotação.';
  return 'Atualizado em ${updated.day}/${updated.month}/${updated.year}.';
}

class _Metrics extends StatelessWidget {
  const _Metrics({
    required this.position,
    required this.onEditPrice,
    this.onFetchQuote,
  });

  final AssetPosition position;
  final VoidCallback onEditPrice;
  final VoidCallback? onFetchQuote;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            _Line(
              label: 'Preço médio',
              value: NumberFormatter.price(position.averagePrice),
            ),
            const Divider(height: 20),
            InkWell(
              onTap: onEditPrice,
              borderRadius: BorderRadius.circular(8),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Preço atual',
                        style: TextStyle(color: AppColors.gray, fontSize: 13),
                      ),
                    ),
                    Text(
                      NumberFormatter.price(position.currentPrice),
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: position.hasQuote ? null : AppColors.gray,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Icon(
                      Icons.edit_outlined,
                      size: 16,
                      color: AppColors.investment,
                    ),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      _priceHint(position),
                      style: TextStyle(color: AppColors.gray, fontSize: 11),
                    ),
                  ),
                  if (onFetchQuote != null)
                    TextButton(
                      onPressed: onFetchQuote,
                      child: const Text('Buscar cotação'),
                    ),
                ],
              ),
            ),
            const Divider(height: 20),
            _Line(
              label: 'Variação',
              value: NumberFormatter.signedPercent(position.priceChange),
              color: valueColor(position.priceChange),
            ),
            const Divider(height: 20),
            _Line(
              label: 'Rentabilidade',
              value: NumberFormatter.signedPercent(position.profitability),
              color: valueColor(position.profitability),
            ),
            const Divider(height: 20),
            _Line(
              label: 'Resultado',
              value: NumberFormatter.signedCurrency(
                position.totalProfit,
                CurrencyFormatter.format,
              ),
              color: valueColor(position.totalProfit),
            ),
            const Divider(height: 20),
            _Line(
              label: 'Investido',
              value: CurrencyFormatter.format(position.investedCost),
            ),
            const Divider(height: 20),
            _Line(
              label: 'Proventos recebidos',
              value: CurrencyFormatter.format(position.dividends),
            ),
          ],
        ),
      ),
    );
  }
}

class _Line extends StatelessWidget {
  const _Line({required this.label, required this.value, this.color});

  final String label;
  final String value;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            label,
            style: TextStyle(color: AppColors.gray, fontSize: 13),
          ),
        ),
        Text(
          value,
          style: TextStyle(fontWeight: FontWeight.w600, color: color),
        ),
      ],
    );
  }
}

class _Actions extends StatelessWidget {
  const _Actions({required this.assetId, required this.hasPosition});

  final String assetId;
  final bool hasPosition;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: [
        FilledButton.icon(
          onPressed: () => context.push('/lancamento/novo?ativo=$assetId'),
          icon: const Icon(Icons.add_rounded, size: 18),
          label: const Text('Comprar'),
          style: FilledButton.styleFrom(backgroundColor: AppColors.investment),
        ),
        OutlinedButton.icon(
          onPressed: hasPosition
              ? () => context.push('/lancamento/novo?ativo=$assetId&tipo=venda')
              : null,
          icon: const Icon(Icons.remove_rounded, size: 18),
          label: const Text('Vender'),
        ),
        OutlinedButton.icon(
          onPressed: () =>
              context.push('/lancamento/novo?ativo=$assetId&tipo=provento'),
          icon: const Icon(Icons.payments_outlined, size: 18),
          label: const Text('Provento'),
        ),
      ],
    );
  }
}

class _TargetCard extends StatelessWidget {
  const _TargetCard({
    required this.asset,
    required this.share,
    required this.onEdit,
  });

  final AssetEntity asset;
  final double share;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    final target = asset.targetPercent;
    final current = share * 100;

    return Card(
      child: InkWell(
        onTap: onEdit,
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Meta de alocação',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      target == null
                          ? 'Defina quanto esse ativo deveria pesar na carteira.'
                          : 'Hoje ${NumberFormatter.percent(share, decimals: 1)} '
                              'de ${NumberFormatter.percent(target / 100, decimals: 0)}',
                      style: TextStyle(color: AppColors.gray, fontSize: 12),
                    ),
                  ],
                ),
              ),
              if (target != null && current < target)
                const _PlainTag(text: 'Aportar')
              else if (target != null)
                const _PlainTag(text: 'No alvo', muted: true),
              const SizedBox(width: 8),
              Icon(Icons.edit_outlined, size: 16, color: AppColors.investment),
            ],
          ),
        ),
      ),
    );
  }
}

class _PlainTag extends StatelessWidget {
  const _PlainTag({required this.text, this.muted = false});

  final String text;
  final bool muted;

  @override
  Widget build(BuildContext context) {
    final color = muted ? AppColors.gray : AppColors.income;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: color,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _TradeTile extends StatelessWidget {
  const _TradeTile({
    required this.trade,
    required this.asset,
    required this.onDelete,
  });

  final AssetTradeEntity trade;
  final AssetEntity asset;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final color = switch (trade.type) {
      AssetTradeType.buy => AppColors.investment,
      AssetTradeType.sell => AppColors.expense,
      AssetTradeType.dividend => AppColors.income,
    };

    final icon = switch (trade.type) {
      AssetTradeType.buy => Icons.add_rounded,
      AssetTradeType.sell => Icons.remove_rounded,
      AssetTradeType.dividend => Icons.payments_outlined,
    };

    final subtitle = trade.type == AssetTradeType.dividend
        ? '${trade.date.day}/${trade.date.month}/${trade.date.year}'
        : '${NumberFormatter.quantity(trade.quantity)} × '
            '${NumberFormatter.price(trade.unitPrice)} · '
            '${trade.date.day}/${trade.date.month}/${trade.date.year}';

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: color, size: 18),
        ),
        title: Text(AssetTradeLabels.label(trade.type)),
        subtitle: Text(subtitle),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              CurrencyFormatter.format(trade.amount),
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            IconButton(
              icon: const Icon(Icons.close_rounded, size: 18),
              tooltip: 'Apagar lançamento',
              onPressed: onDelete,
            ),
          ],
        ),
      ),
    );
  }
}

/// Diálogo com controller próprio: manter o [TextEditingController] dentro do
/// widget evita descartá-lo enquanto a árvore do diálogo ainda existe.
class _NumberDialog extends StatefulWidget {
  const _NumberDialog({
    required this.title,
    required this.label,
    this.initialValue,
    this.prefix,
    this.suffix,
    this.helper,
  });

  final String title;
  final String label;
  final double? initialValue;
  final String? prefix;
  final String? suffix;
  final String? helper;

  @override
  State<_NumberDialog> createState() => _NumberDialogState();
}

class _NumberDialogState extends State<_NumberDialog> {
  late final TextEditingController _controller = TextEditingController(
    text: widget.initialValue == null
        ? ''
        : CurrencyFormatter.formatForInput(widget.initialValue!),
  );

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    final value = CurrencyFormatter.parse(_controller.text);
    if (value == null || value <= 0) {
      Navigator.pop(context);
      return;
    }
    Navigator.pop(context, value);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.title),
      content: TextField(
        controller: _controller,
        autofocus: true,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        decoration: InputDecoration(
          labelText: widget.label,
          prefixText: widget.prefix,
          suffixText: widget.suffix,
          helperText: widget.helper,
          helperMaxLines: 3,
        ),
        onSubmitted: (_) => _submit(),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancelar'),
        ),
        FilledButton(onPressed: _submit, child: const Text('Salvar')),
      ],
    );
  }
}
