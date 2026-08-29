import 'package:flutter/material.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/utils/asset_calculator.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../core/utils/number_formatter.dart';
import '../../../domain/entities/asset_entity.dart';

/// A partir dessa largura cabe a tabela completa; abaixo dela cada ativo vira
/// um cartão para não espremer nove colunas na tela do celular.
const _tableBreakpoint = 820.0;

Color valueColor(double value) {
  if (value > 0) return AppColors.income;
  if (value < 0) return AppColors.expense;
  return AppColors.gray;
}

IconData assetClassIcon(AssetClass value) => switch (value) {
      AssetClass.acao => Icons.show_chart_rounded,
      AssetClass.fii => Icons.apartment_rounded,
      AssetClass.etf => Icons.donut_small_rounded,
      AssetClass.bdr => Icons.public_rounded,
      AssetClass.cripto => Icons.currency_bitcoin_rounded,
      AssetClass.rendaFixa => Icons.savings_rounded,
      AssetClass.outros => Icons.category_rounded,
    };

/// Resumo do topo: quanto a carteira vale e como ela está indo.
class PortfolioHeaderCard extends StatelessWidget {
  const PortfolioHeaderCard({super.key, required this.portfolio});

  final PortfolioSummary portfolio;

  @override
  Widget build(BuildContext context) {
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
          Text(
            'Patrimônio da carteira',
            style: TextStyle(color: Colors.white.withValues(alpha: 0.85)),
          ),
          const SizedBox(height: 8),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              CurrencyFormatter.format(portfolio.totalValue),
              style: const TextStyle(
                color: Colors.white,
                fontSize: 30,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 20,
            runSpacing: 12,
            children: [
              _HeaderStat(
                label: 'Investido',
                value: CurrencyFormatter.format(portfolio.totalCost),
              ),
              _HeaderStat(
                label: 'Variação',
                value: NumberFormatter.signedPercent(portfolio.variation),
              ),
              _HeaderStat(
                label: 'Rentabilidade',
                value: NumberFormatter.signedPercent(portfolio.profitability),
              ),
              _HeaderStat(
                label: 'Proventos',
                value: CurrencyFormatter.format(portfolio.dividends),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _HeaderStat extends StatelessWidget {
  const _HeaderStat({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label,
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.75),
            fontSize: 12,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 15,
          ),
        ),
      ],
    );
  }
}

/// Uma seção da carteira (Ações, FIIs...), recolhível como no Investidor 10.
class AssetClassSection extends StatefulWidget {
  const AssetClassSection({
    super.key,
    required this.summary,
    required this.portfolio,
    required this.onOpenAsset,
  });

  final AssetClassSummary summary;
  final PortfolioSummary portfolio;
  final void Function(AssetPosition position) onOpenAsset;

  @override
  State<AssetClassSection> createState() => _AssetClassSectionState();
}

class _AssetClassSectionState extends State<AssetClassSection> {
  bool _expanded = true;

  @override
  Widget build(BuildContext context) {
    final summary = widget.summary;
    final positions = summary.positions.where((p) => p.isOpen).toList();

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          InkWell(
            onTap: () => setState(() => _expanded = !_expanded),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: _SectionHeader(
                summary: summary,
                share: widget.portfolio.share(summary.totalValue),
                expanded: _expanded,
              ),
            ),
          ),
          if (_expanded) ...[
            const Divider(height: 1),
            LayoutBuilder(
              builder: (context, constraints) {
                final wide = constraints.maxWidth >= _tableBreakpoint;
                if (!wide) {
                  return Column(
                    children: [
                      for (final position in positions)
                        _AssetCard(
                          position: position,
                          share: widget.portfolio.share(position.currentValue),
                          shouldBuy: widget.portfolio.shouldBuy(position),
                          onTap: () => widget.onOpenAsset(position),
                        ),
                    ],
                  );
                }
                return Column(
                  children: [
                    const _TableHeader(),
                    for (final position in positions)
                      _AssetTableRow(
                        position: position,
                        share: widget.portfolio.share(position.currentValue),
                        shouldBuy: widget.portfolio.shouldBuy(position),
                        onTap: () => widget.onOpenAsset(position),
                      ),
                  ],
                );
              },
            ),
          ],
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({
    required this.summary,
    required this.share,
    required this.expanded,
  });

  final AssetClassSummary summary;
  final double share;
  final bool expanded;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppColors.investment.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                assetClassIcon(summary.assetClass),
                color: AppColors.investment,
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                AssetClassLabels.plural(summary.assetClass),
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            Text(
              CurrencyFormatter.format(summary.totalValue),
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            Icon(
              expanded ? Icons.expand_less_rounded : Icons.expand_more_rounded,
              color: AppColors.gray,
            ),
          ],
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 16,
          runSpacing: 8,
          children: [
            _MiniStat(
              label: 'Ativos',
              value: '${summary.assetCount}',
            ),
            _MiniStat(
              label: 'Variação',
              value: NumberFormatter.signedPercent(summary.variation),
              color: valueColor(summary.variation),
            ),
            _MiniStat(
              label: 'Rentabilidade',
              value: NumberFormatter.signedPercent(summary.profitability),
              color: valueColor(summary.profitability),
            ),
            _MiniStat(
              label: 'Na carteira',
              value: summary.hasTarget
                  ? '${NumberFormatter.percent(share, decimals: 0)} '
                      'de ${NumberFormatter.percent(summary.targetPercent / 100, decimals: 0)}'
                  : NumberFormatter.percent(share, decimals: 0),
            ),
          ],
        ),
      ],
    );
  }
}

class _MiniStat extends StatelessWidget {
  const _MiniStat({required this.label, required this.value, this.color});

  final String label;
  final String value;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label,
          style: TextStyle(color: AppColors.gray, fontSize: 11),
        ),
        Text(
          value,
          style: TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 13,
            color: color,
          ),
        ),
      ],
    );
  }
}

const _columnFlex = <int>[24, 10, 14, 14, 13, 15, 16, 11, 11];

class _TableHeader extends StatelessWidget {
  const _TableHeader();

  @override
  Widget build(BuildContext context) {
    const labels = [
      'Ativo',
      'Quant.',
      'Preço médio',
      'Preço atual',
      'Variação',
      'Rentabilidade',
      'Saldo',
      '% Carteira',
      'Comprar?',
    ];

    return Container(
      color: AppColors.gray.withValues(alpha: 0.06),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: [
          for (var i = 0; i < labels.length; i++)
            Expanded(
              flex: _columnFlex[i],
              child: Text(
                labels[i],
                textAlign: i == 0 ? TextAlign.start : TextAlign.end,
                style: TextStyle(
                  color: AppColors.gray,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
        ],
      ),
    );
  }
}

class _AssetTableRow extends StatelessWidget {
  const _AssetTableRow({
    required this.position,
    required this.share,
    required this.shouldBuy,
    required this.onTap,
  });

  final AssetPosition position;
  final double share;
  final bool shouldBuy;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cells = <Widget>[
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            position.asset.ticker,
            style: const TextStyle(fontWeight: FontWeight.bold),
            overflow: TextOverflow.ellipsis,
          ),
          if (position.asset.name.trim().isNotEmpty)
            Text(
              position.asset.name,
              style: TextStyle(color: AppColors.gray, fontSize: 11),
              overflow: TextOverflow.ellipsis,
            ),
        ],
      ),
      _cell(NumberFormatter.quantity(position.quantity)),
      _cell(NumberFormatter.price(position.averagePrice)),
      _cell(
        NumberFormatter.price(position.currentPrice),
        muted: !position.hasQuote,
      ),
      _chip(position.priceChange),
      _chip(position.profitability),
      _cell(
        CurrencyFormatter.format(position.currentValue),
        bold: true,
      ),
      _cell(NumberFormatter.percent(share)),
      Align(
        alignment: Alignment.centerRight,
        child: _BuyBadge(shouldBuy: shouldBuy, hasTarget: position.asset.targetPercent != null),
      ),
    ];

    return InkWell(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          border: Border(
            top: BorderSide(color: AppColors.gray.withValues(alpha: 0.12)),
          ),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            for (var i = 0; i < cells.length; i++)
              Expanded(flex: _columnFlex[i], child: cells[i]),
          ],
        ),
      ),
    );
  }

  Widget _cell(String text, {bool bold = false, bool muted = false}) {
    return Text(
      text,
      textAlign: TextAlign.end,
      overflow: TextOverflow.ellipsis,
      style: TextStyle(
        fontSize: 13,
        fontWeight: bold ? FontWeight.bold : FontWeight.normal,
        color: muted ? AppColors.gray : null,
      ),
    );
  }

  Widget _chip(double fraction) {
    return Align(
      alignment: Alignment.centerRight,
      child: PercentChip(fraction: fraction),
    );
  }
}

class _AssetCard extends StatelessWidget {
  const _AssetCard({
    required this.position,
    required this.share,
    required this.shouldBuy,
    required this.onTap,
  });

  final AssetPosition position;
  final double share;
  final bool shouldBuy;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final asset = position.asset;

    return InkWell(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          border: Border(
            top: BorderSide(color: AppColors.gray.withValues(alpha: 0.12)),
          ),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        asset.ticker,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        '${NumberFormatter.quantity(position.quantity)} × '
                        '${NumberFormatter.price(position.currentPrice)}',
                        style: TextStyle(color: AppColors.gray, fontSize: 12),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      CurrencyFormatter.format(position.currentValue),
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    Text(
                      '${NumberFormatter.percent(share, decimals: 1)} da carteira',
                      style: TextStyle(color: AppColors.gray, fontSize: 11),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                PercentChip(fraction: position.priceChange, prefix: 'Var.'),
                PercentChip(
                  fraction: position.profitability,
                  prefix: 'Rent.',
                ),
                _PlainChip(
                  text: 'PM ${NumberFormatter.price(position.averagePrice)}',
                ),
                if (shouldBuy)
                  const _PlainChip(text: 'Abaixo da meta', highlight: true),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class PercentChip extends StatelessWidget {
  const PercentChip({super.key, required this.fraction, this.prefix});

  final double fraction;
  final String? prefix;

  @override
  Widget build(BuildContext context) {
    final color = valueColor(fraction);
    final label = NumberFormatter.signedPercent(fraction);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        prefix == null ? label : '$prefix $label',
        style: TextStyle(
          color: color,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
        overflow: TextOverflow.ellipsis,
      ),
    );
  }
}

class _PlainChip extends StatelessWidget {
  const _PlainChip({required this.text, this.highlight = false});

  final String text;
  final bool highlight;

  @override
  Widget build(BuildContext context) {
    final color = highlight ? AppColors.accent : AppColors.gray;
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

class _BuyBadge extends StatelessWidget {
  const _BuyBadge({required this.shouldBuy, required this.hasTarget});

  final bool shouldBuy;
  final bool hasTarget;

  @override
  Widget build(BuildContext context) {
    if (!hasTarget) {
      return Text(
        '—',
        textAlign: TextAlign.end,
        style: TextStyle(color: AppColors.gray, fontSize: 13),
      );
    }

    final color = shouldBuy ? AppColors.income : AppColors.gray;
    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          shouldBuy ? Icons.check_circle_outline : Icons.remove_circle_outline,
          size: 14,
          color: color,
        ),
        const SizedBox(width: 4),
        Flexible(
          child: Text(
            shouldBuy ? 'Sim' : 'Não',
            style: TextStyle(
              color: color,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}
