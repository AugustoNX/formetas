import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/utils/number_formatter.dart';
import '../../../domain/entities/asset_entity.dart';
import '../../../domain/entities/market_quote.dart';
import '../../../domain/repositories/market_quote_repository.dart';
import '../../providers/core_providers.dart';
import 'asset_section.dart';

/// Campo de busca no catálogo da B3, no mesmo espírito do Investidor10:
/// a pessoa digita "mx" e escolhe "MXRF11 · FII Maxi Renda".
class AssetSearchField extends ConsumerStatefulWidget {
  const AssetSearchField({
    super.key,
    required this.assetClass,
    required this.onSelected,
    this.onCleared,
    this.selected,
  });

  final AssetClass assetClass;
  final MarketQuote? selected;
  final ValueChanged<MarketQuote> onSelected;
  final VoidCallback? onCleared;

  @override
  ConsumerState<AssetSearchField> createState() => _AssetSearchFieldState();
}

class _AssetSearchFieldState extends ConsumerState<AssetSearchField> {
  final _controller = TextEditingController();
  final _focus = FocusNode();
  Timer? _debounce;
  int _requestId = 0;

  List<MarketQuote> _results = const [];
  bool _loading = false;
  String? _error;
  bool _showResults = false;

  @override
  void initState() {
    super.initState();
    _syncText();
    _focus.addListener(_onFocusChange);
  }

  @override
  void didUpdateWidget(AssetSearchField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.selected?.ticker != widget.selected?.ticker) {
      _cancelSearch();
      _syncText();
      _results = const [];
      _loading = false;
      _error = null;
      _showResults = false;
    }
    if (oldWidget.assetClass != widget.assetClass) {
      _cancelSearch();
      _results = const [];
      _error = null;
      _loading = false;
      _showResults = false;
    }
  }

  void _cancelSearch() {
    _debounce?.cancel();
    _requestId++;
    _loading = false;
  }

  void _onFocusChange() {
    if (_focus.hasFocus &&
        widget.selected == null &&
        (_results.isNotEmpty || _loading || _error != null)) {
      setState(() => _showResults = true);
    }
  }

  void _syncText() {
    final selected = widget.selected;
    if (selected == null) return;
    final label = selected.label;
    if (_controller.text == label) return;
    _controller.value = TextEditingValue(
      text: label,
      selection: TextSelection.collapsed(offset: label.length),
    );
  }

  void _onChanged(String value) {
    if (widget.selected != null) return;
    _debounce?.cancel();
    if (value.trim().length < 2) {
      setState(() {
        _results = const [];
        _loading = false;
        _error = null;
        _showResults = false;
      });
      return;
    }
    _debounce = Timer(const Duration(milliseconds: 280), () => _search(value));
  }

  Future<void> _search(String value) async {
    if (widget.selected != null) return;
    final id = ++_requestId;
    setState(() {
      _loading = true;
      _error = null;
      _showResults = true;
    });

    try {
      final results = await ref.read(marketQuoteRepositoryProvider).search(
            value,
            assetClass: widget.assetClass,
          );
      if (!mounted || id != _requestId) return;
      setState(() {
        _results = results;
        _loading = false;
        _showResults = true;
      });
    } on MarketQuoteException catch (e) {
      if (!mounted || id != _requestId) return;
      setState(() {
        _results = const [];
        _loading = false;
        _error = e.message;
        _showResults = true;
      });
    } catch (_) {
      if (!mounted || id != _requestId) return;
      setState(() {
        _results = const [];
        _loading = false;
        _error = 'Não foi possível buscar ativos agora.';
        _showResults = true;
      });
    }
  }

  void _pick(MarketQuote quote) {
    if (widget.selected?.ticker == quote.ticker) return;
    _cancelSearch();
    setState(() {
      _results = const [];
      _loading = false;
      _error = null;
      _showResults = false;
    });
    _focus.unfocus();
    widget.onSelected(quote);
  }

  void _clear() {
    _debounce?.cancel();
    _controller.clear();
    setState(() {
      _results = const [];
      _loading = false;
      _error = null;
      _showResults = false;
    });
    widget.onCleared?.call();
    _focus.requestFocus();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _focus.removeListener(_onFocusChange);
    _controller.dispose();
    _focus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final selected = widget.selected;
    final showList = selected == null &&
        _showResults &&
        (_loading || _error != null || _results.isNotEmpty);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(
          controller: _controller,
          focusNode: _focus,
          textCapitalization: TextCapitalization.characters,
          readOnly: selected != null,
          decoration: InputDecoration(
            labelText: 'Ativo',
            hintText: 'Digite o código ou o nome',
            prefixIcon: Icon(
              selected == null
                  ? Icons.search_rounded
                  : Icons.check_circle_rounded,
              color: selected == null ? null : AppColors.income,
            ),
            suffixIcon: selected != null
                ? IconButton(
                    icon: const Icon(Icons.close_rounded),
                    tooltip: 'Limpar',
                    onPressed: _clear,
                  )
                : _loading
                    ? const Padding(
                        padding: EdgeInsets.all(12),
                        child: SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      )
                    : _controller.text.isEmpty
                        ? null
                        : IconButton(
                            icon: const Icon(Icons.close_rounded),
                            tooltip: 'Limpar',
                            onPressed: _clear,
                          ),
          ),
          onChanged: _onChanged,
        ),
        if (showList) ...[
          const SizedBox(height: 8),
          _ResultsCard(
            results: _results,
            loading: _loading,
            error: _error,
            onSelected: _pick,
          ),
        ],
      ],
    );
  }
}

class _ResultsCard extends StatelessWidget {
  const _ResultsCard({
    required this.results,
    required this.loading,
    required this.error,
    required this.onSelected,
  });

  final List<MarketQuote> results;
  final bool loading;
  final String? error;
  final ValueChanged<MarketQuote> onSelected;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      borderRadius: BorderRadius.circular(12),
      clipBehavior: Clip.antiAlias,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxHeight: 280),
        child: error != null
            ? Padding(
                padding: const EdgeInsets.all(16),
                child: Text(
                  error!,
                  style: TextStyle(color: AppColors.gray, fontSize: 13),
                ),
              )
            : results.isEmpty && !loading
                ? Padding(
                    padding: const EdgeInsets.all(16),
                    child: Text(
                      'Nenhum ativo encontrado.',
                      style: TextStyle(color: AppColors.gray, fontSize: 13),
                    ),
                  )
                : ListView.separated(
                    shrinkWrap: true,
                    padding: EdgeInsets.zero,
                    itemCount: results.length,
                    separatorBuilder: (_, _) => const Divider(height: 1),
                    itemBuilder: (context, index) {
                      final quote = results[index];
                      // PointerDown chega antes do TextField perder o foco. Se
                      // a lista sumir no unfocus, o onTap do ListTile nunca
                      // dispara e o formulário fica como se nada tivesse sido
                      // escolhido.
                      return Listener(
                        behavior: HitTestBehavior.opaque,
                        onPointerDown: (_) => onSelected(quote),
                        child: ListTile(
                          dense: true,
                          mouseCursor: SystemMouseCursors.click,
                          leading: Icon(
                            assetClassIcon(quote.assetClass),
                            color: AppColors.investment,
                            size: 20,
                          ),
                          title: Text(
                            quote.ticker,
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          subtitle: Text(
                            quote.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          trailing: quote.price == null
                              ? null
                              : Text(
                                  NumberFormatter.price(quote.price!),
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                        ),
                      );
                    },
                  ),
      ),
    );
  }
}
