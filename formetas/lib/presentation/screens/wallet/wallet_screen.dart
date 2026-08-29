import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'investments_view.dart';
import 'reserves_view.dart';

/// Reúne onde o dinheiro fica guardado: caixinhas e investimentos.
/// Antes eram duas telas soltas — as caixinhas só apareciam por um atalho
/// escondido na Home.
class WalletScreen extends StatefulWidget {
  const WalletScreen({super.key, this.initialTab = WalletTab.reserves});

  final WalletTab initialTab;

  @override
  State<WalletScreen> createState() => _WalletScreenState();
}

enum WalletTab {
  reserves,
  investments;

  static WalletTab fromQuery(String? value) =>
      value == 'investimentos' ? WalletTab.investments : WalletTab.reserves;
}

class _WalletScreenState extends State<WalletScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _controller = TabController(
    length: WalletTab.values.length,
    initialIndex: widget.initialTab.index,
    vsync: this,
  )..addListener(_syncTab);

  late int _tabIndex = widget.initialTab.index;

  void _syncTab() {
    if (_controller.index == _tabIndex) return;
    setState(() => _tabIndex = _controller.index);
  }

  @override
  void dispose() {
    _controller.removeListener(_syncTab);
    _controller.dispose();
    super.dispose();
  }

  void _createCurrent() {
    context.push(
      _tabIndex == WalletTab.reserves.index
          ? '/reserve/new'
          : '/lancamento/novo',
    );
  }

  @override
  Widget build(BuildContext context) {
    final isReserves = _tabIndex == WalletTab.reserves.index;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Carteira'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add_rounded),
            tooltip: isReserves ? 'Nova caixinha' : 'Novo lançamento',
            onPressed: _createCurrent,
          ),
        ],
        bottom: TabBar(
          controller: _controller,
          tabs: const [
            Tab(icon: Icon(Icons.savings_outlined), text: 'Caixinhas'),
            Tab(icon: Icon(Icons.trending_up_rounded), text: 'Investimentos'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _controller,
        children: const [ReservesView(), InvestmentsView()],
      ),
    );
  }
}
