import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:uuid/uuid.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_strings.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../domain/entities/goal_entity.dart';
import '../../../domain/entities/reserve_movement_entity.dart';
import '../../providers/auth_provider.dart';
import '../../providers/core_providers.dart';
import '../../providers/data_providers.dart';

class GoalFormScreen extends ConsumerStatefulWidget {
  const GoalFormScreen({super.key, this.goalId});

  final String? goalId;

  @override
  ConsumerState<GoalFormScreen> createState() => _GoalFormScreenState();
}

class _GoalFormScreenState extends ConsumerState<GoalFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _targetController = TextEditingController();
  final _currentController = TextEditingController();

  DateTime _targetDate = DateTime.now().add(const Duration(days: 365));
  String _reserveId = '';
  bool _isLoading = false;
  GoalEntity? _existing;

  @override
  void initState() {
    super.initState();
    if (widget.goalId != null) _load();
  }

  Future<void> _load() async {
    final user = ref.read(currentUserProvider);
    if (user == null) return;
    final list = await ref.read(goalRepositoryProvider).getGoals(user.id);
    final goal = list.where((g) => g.id == widget.goalId).firstOrNull;
    if (goal != null && mounted) {
      setState(() {
        _existing = goal;
        _nameController.text = goal.name;
        _targetController.text = CurrencyFormatter.formatForInput(goal.targetValue);
        _currentController.text = CurrencyFormatter.formatForInput(goal.currentValue);
        _targetDate = goal.targetDate;
        _reserveId = goal.reserveId ?? '';
      });
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _targetController.dispose();
    _currentController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    final user = ref.read(currentUserProvider);
    if (user == null) return;

    final reserves =
        ref.read(reservesWithMovementsProvider).valueOrNull ?? const <ReserveWithMovements>[];
    final linked = _reserveId.isNotEmpty &&
        reserves.any((item) => item.reserve.id == _reserveId);

    try {
      final goal = GoalEntity(
        id: _existing?.id ?? const Uuid().v4(),
        userId: user.id,
        name: _nameController.text,
        targetValue: CurrencyFormatter.parse(_targetController.text) ?? 0,
        currentValue: _reserveId.isEmpty
            ? (CurrencyFormatter.parse(_currentController.text) ?? 0)
            : (_existing?.currentValue ?? 0),
        targetDate: _targetDate,
        createdAt: _existing?.createdAt ?? DateTime.now(),
        reserveId: linked ? _reserveId : null,
      );

      final repo = ref.read(goalRepositoryProvider);
      if (_existing != null) {
        await repo.updateGoal(goal);
      } else {
        await repo.createGoal(goal);
      }

      if (mounted) {
        final message = goal.isCompleted
            ? AppStrings.goalReached
            : AppStrings.saveSuccess;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(message), backgroundColor: AppColors.secondary),
        );
        context.pop();
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final reserves =
        ref.watch(reservesWithMovementsProvider).valueOrNull ?? const <ReserveWithMovements>[];
    final linked = reserves.any((item) => item.reserve.id == _reserveId);
    final reserveValue = _reserveId.isEmpty ? '' : _reserveId;

    return Scaffold(
      appBar: AppBar(
        title: Text(_existing != null ? 'Editar meta' : 'Nova meta'),
        actions: [
          if (_existing != null)
            IconButton(
              icon: const Icon(Icons.delete_outline),
              onPressed: () async {
                final user = ref.read(currentUserProvider);
                if (user == null) return;
                await ref
                    .read(goalRepositoryProvider)
                    .deleteGoal(user.id, _existing!.id);
                if (mounted) context.pop();
              },
            ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            TextFormField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: 'Nome da meta',
                hintText: 'Ex: Reserva de emergência',
              ),
              validator: (v) => v?.isEmpty == true ? 'Informe o nome' : null,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _targetController,
              keyboardType: TextInputType.number,
              inputFormatters: CurrencyFormatter.inputFormatters,
              decoration: const InputDecoration(
                labelText: 'Valor desejado',
                prefixText: 'R\$ ',
              ),
              validator: (v) => v?.isEmpty == true ? 'Informe o valor' : null,
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              key: ValueKey(reserveValue),
              initialValue: linked || reserveValue.isEmpty ? reserveValue : '',
              decoration: const InputDecoration(labelText: 'Caixinha'),
              items: [
                const DropdownMenuItem(
                  value: '',
                  child: Text('Sem caixinha, informar valor'),
                ),
                for (final item in reserves)
                  DropdownMenuItem(
                    value: item.reserve.id,
                    child: Text(item.reserve.name),
                  ),
              ],
              onChanged: (value) {
                if (value == null || value == _reserveId) return;
                setState(() => _reserveId = value);
              },
            ),
            if (_reserveId.isEmpty) ...[
              const SizedBox(height: 16),
              TextFormField(
                controller: _currentController,
                keyboardType: TextInputType.number,
                inputFormatters: CurrencyFormatter.inputFormatters,
                decoration: const InputDecoration(
                  labelText: 'Valor atual',
                  prefixText: 'R\$ ',
                ),
              ),
            ] else ...[
              const SizedBox(height: 8),
              Text(
                'O valor atual acompanha essa caixinha.',
                style: TextStyle(color: AppColors.gray, fontSize: 13),
              ),
            ],
            const SizedBox(height: 16),
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Data objetivo'),
              subtitle: Text(
                '${_targetDate.day}/${_targetDate.month}/${_targetDate.year}',
              ),
              trailing: const Icon(Icons.calendar_today_outlined),
              onTap: () async {
                final picked = await showDatePicker(
                  context: context,
                  initialDate: _targetDate,
                  firstDate: DateTime.now(),
                  lastDate: DateTime(2040),
                );
                if (picked != null) setState(() => _targetDate = picked);
              },
            ),
            const SizedBox(height: 32),
            FilledButton(
              onPressed: _isLoading ? null : _save,
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.primary,
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
              child: _isLoading
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : const Text('Salvar meta'),
            ),
          ],
        ),
      ),
    );
  }
}
