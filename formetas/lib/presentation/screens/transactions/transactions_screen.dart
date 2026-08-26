import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_colors.dart';
import '../../../domain/entities/transaction_entity.dart';
import '../../../domain/repositories/transaction_repository.dart';
import '../../providers/auth_provider.dart';
import '../../providers/core_providers.dart';
import '../../providers/data_providers.dart';
import '../../widgets/transaction_tile.dart';

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
    _tabController = TabController(length: 3, vsync: this);
    _tabController.addListener(_onTabChanged);
  }

  void _onTabChanged() {
    if (!_tabController.indexIsChanging) {
      final type = switch (_tabController.index) {
        0 => null,
        1 => TransactionType.income,
        2 => TransactionType.expense,
        _ => null,
      };
      ref.read(transactionFilterProvider.notifier).state =
          TransactionFilter(type: type, searchQuery: _searchController.text.isEmpty
              ? null
              : _searchController.text);
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _deleteTransaction(TransactionEntity tx) async {
    final user = ref.read(currentUserProvider);
    if (user == null) return;
    await ref
        .read(transactionRepositoryProvider)
        .deleteTransaction(user.id, tx.id);
  }

  @override
  Widget build(BuildContext context) {
    final transactions = ref.watch(filteredTransactionsProvider);
    final selectedMonth = ref.watch(selectedMonthProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Movimentações'),
        actions: [
          IconButton(
            icon: const Icon(Icons.filter_list_rounded),
            onPressed: () => _showFilterSheet(context),
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Todas'),
            Tab(text: 'Receitas'),
            Tab(text: 'Despesas'),
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
              onChanged: (_) {
                _onTabChanged();
                setState(() {});
              },
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
            child: transactions.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text('Erro: $e')),
              data: (list) {
                final filtered = list.where((t) {
                  return t.date.month == selectedMonth.month &&
                      t.date.year == selectedMonth.year;
                }).toList();

                if (filtered.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.receipt_long_outlined,
                            size: 64, color: AppColors.gray.withValues(alpha: 0.5)),
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
                    final tx = filtered[index];
                    return TransactionTile(
                      transaction: tx,
                      onTap: () => context.push('/transaction/edit/${tx.id}'),
                      onDelete: () => _deleteTransaction(tx),
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

  void _showFilterSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Filtros', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 16),
            ListTile(
              leading: const Icon(Icons.category_outlined),
              title: const Text('Por categoria'),
              onTap: () {
                Navigator.pop(ctx);
                context.push('/categories');
              },
            ),
            ListTile(
              leading: const Icon(Icons.calendar_month_outlined),
              title: const Text('Por mês'),
              subtitle: const Text('Use o seletor acima'),
            ),
          ],
        ),
      ),
    );
  }
}
