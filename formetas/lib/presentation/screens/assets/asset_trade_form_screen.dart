import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:uuid/uuid.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/utils/asset_calculator.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../core/utils/number_formatter.dart';
import '../../../core/utils/patrimony_calculator.dart';
import '../../../domain/entities/asset_entity.dart';
import '../../../domain/entities/asset_trade_entity.dart';
import '../../../domain/entities/market_quote.dart';
import '../../../domain/services/asset_trade_service.dart';
import '../../providers/auth_provider.dart';
import '../../providers/core_providers.dart';
import '../../providers/data_providers.dart';
import '../../widgets/wallet/asset_search_field.dart';

class AssetTradeFormScreen extends ConsumerStatefulWidget {
  const AssetTradeFormScreen({super.key, this.assetId, this.initialType});

  final String? assetId;
  final AssetTradeType? initialType;

  @override
  ConsumerState<AssetTradeFormScreen> createState() =>
      _AssetTradeFormScreenState();
}

class _AssetTradeFormScreenState extends ConsumerState<AssetTradeFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _tickerController = TextEditingController();
  final _nameController = TextEditingController();
  final _quantityController = TextEditingController();
  final _priceController = TextEditingController();
  final _feesController = TextEditingController();
  final _amountController = TextEditingController();

  late AssetTradeType _type = widget.initialType ?? AssetTradeType.buy;
  late String? _selectedId = widget.assetId;
  AssetClass _assetClass = AssetClass.acao;
  MarketQuote? _quote;
  bool _manualTicker = false;
  DateTime _date = DateTime.now();
  bool _saving = false;

  @override
  void dispose() {
    _tickerController.dispose();
    _nameController.dispose();
    _quantityController.dispose();
    _priceController.dispose();
    _feesController.dispose();
    _amountController.dispose();
    super.dispose();
  }

  bool get _isDividend => _type == AssetTradeType.dividend;

  bool get _buyingNew => _type == AssetTradeType.buy && _selectedId == null;

  bool get _catalogSearch =>
      _buyingNew && MarketQuoteMapper.isListed(_assetClass) && !_manualTicker;

  double get _quantity => CurrencyFormatter.parse(_quantityController.text) ?? 0;

  double get _unitPrice => CurrencyFormatter.parse(_priceController.text) ?? 0;

  double get _fees => CurrencyFormatter.parse(_feesController.text) ?? 0;

  double get _dividendAmount =>
      CurrencyFormatter.parse(_amountController.text) ?? 0;

  double get _total => AssetTradeEntity.totalFor(
        type: _type,
        quantity: _quantity,
        unitPrice: _unitPrice,
        fees: _fees,
        dividendAmount: _dividendAmount,
      );

  void _changeType(AssetTradeType type) {
    setState(() {
      _type = type;
      if (type != AssetTradeType.buy) {
        _quote = null;
        _manualTicker = false;
      } else {
        _selectedId = widget.assetId;
      }
    });
  }

  void _applyQuote(MarketQuote quote, List<AssetWithTrades> assets) {
    final existing = assets
        .where((item) => item.asset.ticker == quote.ticker)
        .firstOrNull;

    setState(() {
      _quote = quote;
      _assetClass = quote.assetClass;
      _tickerController.text = quote.ticker;
      _nameController.text = quote.name;
      _selectedId = existing?.asset.id;
      _manualTicker = false;
      if (_priceController.text.trim().isEmpty && quote.price != null) {
        _priceController.text = CurrencyFormatter.formatForInput(quote.price!);
      }
    });
  }

  void _useQuotePrice() {
    final price = _quote?.price;
    if (price == null) return;
    setState(() {
      _priceController.text = CurrencyFormatter.formatForInput(price);
    });
  }

  Future<void> _save(List<AssetWithTrades> assets) async {
    if (!_formKey.currentState!.validate()) return;
    final user = ref.read(currentUserProvider);
    if (user == null) return;

    final existing =
        assets.where((item) => item.asset.id == _selectedId).firstOrNull;

    if (existing == null && _type != AssetTradeType.buy) {
      _showError('Escolha um ativo da carteira');
      return;
    }

    if (existing == null && _catalogSearch && _quote == null) {
      _showError('Escolha um ativo na busca');
      return;
    }

    final ticker = (existing?.asset.ticker ??
            _quote?.ticker ??
            _tickerController.text)
        .trim()
        .toUpperCase();
    final name = existing?.asset.name ??
        (_quote?.name ?? _nameController.text).trim();

    var asset = existing?.asset ??
        AssetEntity(
          id: const Uuid().v4(),
          userId: user.id,
          ticker: ticker,
          name: name,
          assetClass: _quote?.assetClass ?? _assetClass,
          currentPrice: _quote?.price,
          priceUpdatedAt: _quote?.price == null ? null : DateTime.now(),
          createdAt: DateTime.now(),
        );

    if (existing != null && _quote?.price != null) {
      asset = asset.copyWith(
        currentPrice: _quote!.price,
        priceUpdatedAt: DateTime.now(),
        name: asset.name.trim().isEmpty ? _quote!.name : asset.name,
      );
    }

    final position = existing == null
        ? null
        : AssetCalculator.position(
            asset: existing.asset,
            trades: existing.trades,
          );

    setState(() => _saving = true);
    try {
      await ref.read(assetTradeServiceProvider).registerTrade(
            asset: asset,
            type: _type,
            date: _date,
            position: position,
            transactions: ref.read(transactionsProvider).valueOrNull ?? [],
            transfers: ref.read(transfersProvider).valueOrNull ?? [],
            quantity: _isDividend ? 0 : _quantity,
            unitPrice: _isDividend ? 0 : _unitPrice,
            fees: _isDividend ? 0 : _fees,
            dividendAmount: _isDividend ? _dividendAmount : 0,
            isNewAsset: existing == null,
          );

      if (existing != null && _quote?.price != null) {
        await ref.read(assetTradeServiceProvider).updatePrice(
              asset,
              _quote!.price!,
            );
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${AssetTradeLabels.label(_type)} registrada'),
          backgroundColor: AppColors.secondary,
        ),
      );
      context.pop();
    } on AssetTradeException catch (e) {
      _showError(e.message);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: AppColors.expense),
    );
  }

  @override
  Widget build(BuildContext context) {
    final assets = ref.watch(assetsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Novo lançamento')),
      body: assets.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Erro: $e')),
        data: (list) => _buildForm(list),
      ),
    );
  }

  Widget _buildForm(List<AssetWithTrades> assets) {
    final balance = PatrimonyCalculator.balance(
      transactions: ref.watch(transactionsProvider).valueOrNull ?? [],
      transfers: ref.watch(transfersProvider).valueOrNull ?? [],
    );

    final selected =
        assets.where((item) => item.asset.id == _selectedId).firstOrNull;
    final position = selected == null
        ? null
        : AssetCalculator.position(
            asset: selected.asset,
            trades: selected.trades,
          );

    return Form(
      key: _formKey,
      child: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          SegmentedButton<AssetTradeType>(
            segments: const [
              ButtonSegment(
                value: AssetTradeType.buy,
                label: Text('Compra'),
                icon: Icon(Icons.add_rounded),
              ),
              ButtonSegment(
                value: AssetTradeType.sell,
                label: Text('Venda'),
                icon: Icon(Icons.remove_rounded),
              ),
              ButtonSegment(
                value: AssetTradeType.dividend,
                label: Text('Provento'),
                icon: Icon(Icons.payments_outlined),
              ),
            ],
            selected: {_type},
            onSelectionChanged: (value) => _changeType(value.first),
          ),
          const SizedBox(height: 20),
          if (_type == AssetTradeType.buy) ...[
            DropdownButtonFormField<AssetClass>(
              initialValue: _assetClass,
              decoration: const InputDecoration(labelText: 'Tipo de ativo'),
              items: [
                for (final value in AssetClassLabels.ordered)
                  DropdownMenuItem(
                    value: value,
                    child: Text(AssetClassLabels.plural(value)),
                  ),
              ],
              onChanged: (value) => setState(() {
                _assetClass = value!;
                _quote = null;
                _selectedId = null;
                _tickerController.clear();
                _nameController.clear();
              }),
            ),
            const SizedBox(height: 16),
            if (_catalogSearch)
              AssetSearchField(
                assetClass: _assetClass,
                selected: _quote,
                onSelected: (quote) => _applyQuote(quote, assets),
              )
            else if (_buyingNew)
              ..._manualFields()
            else
              _OwnedAssetDropdown(
                assets: assets,
                selectedId: _selectedId,
                onChanged: (value) => setState(() {
                  _selectedId = value;
                  _quote = null;
                }),
              ),
            if (_catalogSearch)
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton(
                  onPressed: () => setState(() {
                    _manualTicker = true;
                    _quote = null;
                  }),
                  child: const Text('Não encontrei, informar na mão'),
                ),
              ),
            if (_manualTicker && MarketQuoteMapper.isListed(_assetClass))
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton(
                  onPressed: () => setState(() => _manualTicker = false),
                  child: const Text('Voltar para a busca'),
                ),
              ),
          ] else
            _OwnedAssetDropdown(
              assets: assets,
              selectedId: _selectedId,
              onChanged: (value) => setState(() => _selectedId = value),
            ),
          if (_quote != null) ...[
            const SizedBox(height: 8),
            _QuoteBanner(quote: _quote!, onUsePrice: _useQuotePrice),
          ],
          const SizedBox(height: 16),
          if (_isDividend)
            TextFormField(
              controller: _amountController,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(
                labelText: 'Valor recebido',
                prefixText: 'R\$ ',
              ),
              onChanged: (_) => setState(() {}),
              validator: (_) =>
                  _dividendAmount <= 0 ? 'Informe o valor recebido' : null,
            )
          else ...[
            TextFormField(
              controller: _quantityController,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: InputDecoration(
                labelText: 'Quantidade',
                helperText: _type == AssetTradeType.sell && position != null
                    ? 'Você tem ${NumberFormatter.quantity(position.quantity)}'
                    : null,
              ),
              onChanged: (_) => setState(() {}),
              validator: (_) =>
                  _quantity <= 0 ? 'Informe a quantidade' : null,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _priceController,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: InputDecoration(
                labelText: 'Preço da transação',
                prefixText: 'R\$ ',
                helperText: _quote?.price == null
                    ? 'O preço que você pagou ou recebeu, não a cotação.'
                    : 'Cotação agora: ${NumberFormatter.price(_quote!.price!)}',
              ),
              onChanged: (_) => setState(() {}),
              validator: (_) => _unitPrice <= 0 ? 'Informe o preço' : null,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _feesController,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(
                labelText: 'Outros custos (opcional)',
                prefixText: 'R\$ ',
              ),
              onChanged: (_) => setState(() {}),
            ),
          ],
          const SizedBox(height: 8),
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Data da transação'),
            subtitle: Text('${_date.day}/${_date.month}/${_date.year}'),
            trailing: const Icon(Icons.calendar_today_rounded, size: 18),
            onTap: () async {
              final picked = await showDatePicker(
                context: context,
                initialDate: _date,
                firstDate: DateTime(2010),
                lastDate: DateTime.now(),
              );
              if (picked != null) setState(() => _date = picked);
            },
          ),
          const SizedBox(height: 8),
          _Summary(type: _type, total: _total, balance: balance),
          const SizedBox(height: 24),
          FilledButton(
            onPressed: _saving ? null : () => _save(assets),
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.primary,
              padding: const EdgeInsets.symmetric(vertical: 16),
            ),
            child: _saving
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Text('Salvar lançamento'),
          ),
        ],
      ),
    );
  }

  List<Widget> _manualFields() {
    return [
      TextFormField(
        controller: _tickerController,
        textCapitalization: TextCapitalization.characters,
        decoration: const InputDecoration(
          labelText: 'Código do ativo',
          hintText: 'PETR4, MXRF11, BTC...',
        ),
        validator: (v) => v?.trim().isEmpty == true ? 'Informe o código' : null,
      ),
      const SizedBox(height: 16),
      TextFormField(
        controller: _nameController,
        decoration: const InputDecoration(
          labelText: 'Nome (opcional)',
          hintText: 'Petrobras PN',
        ),
      ),
    ];
  }
}

class _OwnedAssetDropdown extends StatelessWidget {
  const _OwnedAssetDropdown({
    required this.assets,
    required this.selectedId,
    required this.onChanged,
  });

  final List<AssetWithTrades> assets;
  final String? selectedId;
  final void Function(String?) onChanged;

  @override
  Widget build(BuildContext context) {
    final items = [
      for (final item in assets)
        DropdownMenuItem(
          value: item.asset.id,
          child: Text(
            item.asset.displayName == item.asset.ticker
                ? item.asset.ticker
                : '${item.asset.ticker} · ${item.asset.name}',
            overflow: TextOverflow.ellipsis,
          ),
        ),
    ];

    final value =
        items.any((item) => item.value == selectedId) ? selectedId : null;

    return DropdownButtonFormField<String>(
      initialValue: value,
      isExpanded: true,
      decoration: const InputDecoration(labelText: 'Ativo da carteira'),
      items: items,
      onChanged: onChanged,
      validator: (v) => v == null ? 'Escolha um ativo' : null,
    );
  }
}

class _QuoteBanner extends StatelessWidget {
  const _QuoteBanner({required this.quote, required this.onUsePrice});

  final MarketQuote quote;
  final VoidCallback onUsePrice;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.investment.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  quote.label,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                  overflow: TextOverflow.ellipsis,
                ),
                if (quote.price != null)
                  Text(
                    [
                      'Cotação ${NumberFormatter.price(quote.price!)}',
                      if (quote.changePercent != null)
                        NumberFormatter.signedPercent(
                          quote.changePercent! / 100,
                        ),
                    ].join(' · '),
                    style: TextStyle(color: AppColors.gray, fontSize: 12),
                  ),
              ],
            ),
          ),
          if (quote.price != null)
            TextButton(
              onPressed: onUsePrice,
              child: const Text('Usar cotação'),
            ),
        ],
      ),
    );
  }
}

class _Summary extends StatelessWidget {
  const _Summary({
    required this.type,
    required this.total,
    required this.balance,
  });

  final AssetTradeType type;
  final double total;
  final double balance;

  @override
  Widget build(BuildContext context) {
    final isBuy = type == AssetTradeType.buy;
    final insufficient = isBuy && CurrencyFormatter.exceeds(total, balance);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: (insufficient ? AppColors.expense : AppColors.investment)
            .withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                isBuy ? 'Valor total' : 'Entra no saldo',
                style: TextStyle(color: AppColors.gray, fontSize: 13),
              ),
              Text(
                CurrencyFormatter.format(total),
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Saldo disponível',
                style: TextStyle(color: AppColors.gray, fontSize: 13),
              ),
              Text(
                CurrencyFormatter.format(balance),
                style: TextStyle(
                  color: insufficient ? AppColors.expense : AppColors.gray,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
