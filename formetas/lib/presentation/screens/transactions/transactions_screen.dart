import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../core/utils/date_utils.dart';
import '../../../domain/entities/movement_entry.dart';
import '../../providers/auth_provider.dart';
import '../../providers/core_providers.dart';
import '../../providers/data_providers.dart';
import '../../widgets/movement_tile.dart';

class TransactionsScreen extends ConsumerStatefulWidget {
  const TransactionsScreen({super.key});

  @override
  ConsumerState<TransactionsScreen> createState() => _TransactionsScreenState();
}

class _TransactionsScreenState extends ConsumerState<TransactionsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _tabController.addListener(() {
      if (!_tabController.indexIsChanging) setState(() {});
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _deleteTransaction(String id) async {
    final user = ref.read(currentUserProvider);
    if (user == null) return;
    await ref.read(transactionRepositoryProvider).deleteTransaction(user.id, id);
  }

  List<MovementEntry> _applyFilters(List<MovementEntry> list) {
    final selectedMonth = ref.read(selectedMonthProvider);
    final query = _searchController.text.trim().toLowerCase();

    return list.where((item) {
      if (item.date.month != selectedMonth.month ||
          item.date.year != selectedMonth.year) {
        return false;
      }

      switch (_tabController.index) {
        case 1:
          if (item.kind != MovementKind.income) return false;
        case 2:
          if (item.kind != MovementKind.expense) return false;
        case 3:
          if (item.kind != MovementKind.transfer) return false;
      }

      if (query.isNotEmpty) {
        final haystack = '${item.title} ${item.subtitle}'.toLowerCase();
        if (!haystack.contains(query)) return false;
      }

      return true;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final movements = ref.watch(movementsProvider);
    final selectedMonth = ref.watch(selectedMonthProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Movimentações'),
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          tabAlignment: TabAlignment.start,
          tabs: const [
            Tab(text: 'Todas'),
            Tab(text: 'Receitas'),
            Tab(text: 'Despesas'),
            Tab(text: 'Transferências'),
          ],
        ),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Pesquisar movimentação...',
                prefixIcon: const Icon(Icons.search_rounded),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _searchController.clear();
                          setState(() {});
                        },
                      )
                    : null,
              ),
              onChanged: (_) => setState(() {}),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                IconButton(
                  onPressed: () {
                    ref.read(selectedMonthProvider.notifier).state =
                        DateTime(selectedMonth.year, selectedMonth.month - 1);
                  },
                  icon: const Icon(Icons.chevron_left),
                ),
                Text(
                  '${selectedMonth.month.toString().padLeft(2, '0')}/${selectedMonth.year}',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                IconButton(
                  onPressed: () {
                    ref.read(selectedMonthProvider.notifier).state =
                        DateTime(selectedMonth.year, selectedMonth.month + 1);
                  },
                  icon: const Icon(Icons.chevron_right),
                ),
              ],
            ),
          ),
          Expanded(
            child: movements.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text('Erro: $e')),
              data: (list) {
                final filtered = _applyFilters(list);

                if (filtered.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.receipt_long_outlined,
                          size: 64,
                          color: AppColors.gray.withValues(alpha: 0.5),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Nenhuma movimentação neste mês',
                          style: TextStyle(color: AppColors.gray),
                        ),
                      ],
                    ),
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: filtered.length,
                  itemBuilder: (context, index) {
                    final item = filtered[index];
                    return MovementTile(
                      entry: item,
                      onTap: () {
                        final tx = item.transaction;
                        if (tx != null) {
                          context.push('/transaction/edit/${tx.id}');
                          return;
                        }
                        _showTransferDetails(item);
                      },
                      onDelete: item.transaction != null
                          ? () => _deleteTransaction(item.id)
                          : null,
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  void _showTransferDetails(MovementEntry item) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Transferência'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              item.title,
              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
            ),
            const SizedBox(height: 8),
            Text(item.subtitle, style: TextStyle(color: AppColors.gray)),
            const SizedBox(height: 12),
            Text(
              CurrencyFormatter.format(item.amount),
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 20,
                color: AppColors.primary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              AppDateUtils.formatDate(item.date),
              style: TextStyle(color: AppColors.gray, fontSize: 13),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Fechar'),
          ),
        ],
      ),
    );
  }
}
