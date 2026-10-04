import 'package:flutter/material.dart';

import '../models/transaction.dart';
import '../services/banking_api.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final BankingApi _api = BankingApi();
  final GlobalKey _statementKey = GlobalKey();

  BankState? _account;
  List<BankTransaction> _transactions = [];
  bool _loading = true;
  bool _processing = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    _api.close();
    super.dispose();
  }

  Future<void> _loadData({bool showLoading = true}) async {
    if (showLoading) setState(() => _loading = true);

    try {
      final results = await Future.wait<Object>([
        _api.fetchState(),
        _api.fetchStatement(),
      ]);
      if (!mounted) return;
      setState(() {
        _account = results[0] as BankState;
        _transactions = results[1] as List<BankTransaction>;
        _error = null;
      });
    } on BankingApiException catch (exception) {
      if (!mounted) return;
      setState(() => _error = exception.message);
    } catch (_) {
      if (!mounted) return;
      setState(() => _error = 'Não foi possível carregar os dados da conta.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _openOperationSheet({required bool isDeposit}) async {
    final controller = TextEditingController();
    String? inputError;

    final value = await showModalBottomSheet<double>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      showDragHandle: true,
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            void submit() {
              var normalized = controller.text.trim().replaceAll(' ', '');
              if (normalized.contains(',')) {
                normalized = normalized.replaceAll('.', '').replaceAll(',', '.');
              }
              final parsedValue = double.tryParse(normalized);

              if (parsedValue == null) {
                setSheetState(() => inputError = 'Informe um valor numérico válido.');
                return;
              }
              Navigator.pop(sheetContext, parsedValue);
            }

            return Padding(
              padding: EdgeInsets.fromLTRB(
                24,
                8,
                24,
                24 + MediaQuery.viewInsetsOf(context).bottom,
              ),
              child: Center(
                heightFactor: 1,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 480),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        isDeposit ? 'Fazer depósito' : 'Fazer saque',
                        style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        isDeposit
                            ? 'Informe o valor que deseja adicionar à conta.'
                            : 'Informe o valor que deseja retirar da conta.',
                        style: const TextStyle(color: Color(0xFF63706F)),
                      ),
                      const SizedBox(height: 20),
                      TextField(
                        controller: controller,
                        autofocus: true,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        decoration: InputDecoration(
                          labelText: isDeposit ? 'Valor do depósito' : 'Valor do saque',
                          prefixText: 'R\$ ',
                          errorText: inputError,
                        ),
                        onSubmitted: (_) => submit(),
                      ),
                      const SizedBox(height: 20),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              onPressed: () => Navigator.pop(sheetContext),
                              child: const Text('Cancelar'),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: FilledButton(
                              onPressed: submit,
                              child: Text(isDeposit ? 'Depositar' : 'Sacar'),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );

    controller.dispose();
    if (value == null || !mounted) return;
    await _executeOperation(isDeposit: isDeposit, value: value);
  }

  Future<void> _executeOperation({required bool isDeposit, required double value}) async {
    setState(() => _processing = true);

    try {
      final result = isDeposit ? await _api.deposit(value) : await _api.withdraw(value);
      if (result.success) await _loadData(showLoading: false);
      if (!mounted) return;
      _showMessage(result.message, success: result.success);
    } on BankingApiException catch (exception) {
      if (!mounted) return;
      _showMessage(exception.message, success: false);
    } finally {
      if (mounted) setState(() => _processing = false);
    }
  }

  Future<void> _showStatement() async {
    await _loadData(showLoading: false);
    final statementContext = _statementKey.currentContext;
    if (statementContext != null) {
      await Scrollable.ensureVisible(
        statementContext,
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeOut,
      );
    }
  }

  void _showMessage(String message, {required bool success}) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: success ? const Color(0xFF126E68) : const Color(0xFFB53B3B),
        ),
      );
  }

  String _money(double value) {
    final parts = value.toStringAsFixed(2).split('.');
    final integer = parts[0].replaceAllMapped(
      RegExp(r'\B(?=(\d{3})+(?!\d))'),
      (_) => '.',
    );
    return 'R\$ $integer,${parts[1]}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _loadData,
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(20, 24, 20, 40),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 880),
                child: _loading && _account == null
                    ? const SizedBox(
                        height: 520,
                        child: Center(child: CircularProgressIndicator()),
                      )
                    : _account == null
                        ? _ConnectionError(
                            message: _error ?? 'Não foi possível conectar ao servidor local.',
                            onRetry: () => _loadData(),
                          )
                        : _buildContent(context, _account!),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildContent(BuildContext context, BankState account) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: const BoxDecoration(
                color: Color(0xFFD9EEEB),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.account_balance_wallet_outlined, color: Color(0xFF126E68)),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Olá 👋', style: Theme.of(context).textTheme.bodyLarge),
                  Text(
                    'Minha Conta',
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                  ),
                ],
              ),
            ),
            IconButton(
              tooltip: 'Atualizar',
              onPressed: _processing ? null : () => _loadData(showLoading: false),
              icon: const Icon(Icons.refresh_rounded),
            ),
          ],
        ),
        if (_error != null) ...[
          const SizedBox(height: 18),
          _InlineError(message: _error!),
        ],
        const SizedBox(height: 26),
        Container(
          padding: const EdgeInsets.all(28),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(28),
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFF143C46), Color(0xFF126E68)],
            ),
            boxShadow: const [
              BoxShadow(color: Color(0x33205258), blurRadius: 28, offset: Offset(0, 14)),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Saldo disponível', style: TextStyle(color: Color(0xFFCDE3E1))),
              const SizedBox(height: 8),
              Text(
                _money(account.balance),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 38,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -1.2,
                ),
              ),
              const SizedBox(height: 28),
              Wrap(
                spacing: 22,
                runSpacing: 10,
                children: [
                  _CardDetail(
                    icon: Icons.payments_outlined,
                    text: 'Limite por saque: ${_money(account.withdrawalLimit)}',
                  ),
                  _CardDetail(
                    icon: Icons.receipt_long_outlined,
                    text: 'Saques realizados: ${account.withdrawals}/${account.withdrawalCountLimit}',
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 30),
        Text(
          'O que você deseja fazer?',
          style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 16),
        LayoutBuilder(
          builder: (context, constraints) {
            final buttonWidth = constraints.maxWidth >= 620
                ? (constraints.maxWidth - 24) / 3
                : constraints.maxWidth;
            return Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                _ActionButton(
                  width: buttonWidth,
                  icon: Icons.add_card_rounded,
                  label: 'Depositar',
                  onPressed: _processing ? null : () => _openOperationSheet(isDeposit: true),
                ),
                _ActionButton(
                  width: buttonWidth,
                  icon: Icons.payments_rounded,
                  label: 'Sacar',
                  onPressed: _processing ? null : () => _openOperationSheet(isDeposit: false),
                ),
                _ActionButton(
                  width: buttonWidth,
                  icon: Icons.receipt_long_rounded,
                  label: 'Extrato',
                  onPressed: _processing ? null : _showStatement,
                ),
              ],
            );
          },
        ),
        const SizedBox(height: 34),
        Row(
          key: _statementKey,
          children: [
            Expanded(
              child: Text(
                'Movimentações recentes',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
              ),
            ),
            if (_processing)
              const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)),
          ],
        ),
        const SizedBox(height: 14),
        if (_transactions.isEmpty)
          const _EmptyStatement()
        else
          ..._transactions.reversed.map(
            (transaction) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _TransactionTile(transaction: transaction, money: _money),
            ),
          ),
      ],
    );
  }
}

class _ActionButton extends StatelessWidget {
  const _ActionButton({
    required this.width,
    required this.icon,
    required this.label,
    required this.onPressed,
  });

  final double width;
  final IconData icon;
  final String label;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      height: 76,
      child: FilledButton.tonalIcon(
        onPressed: onPressed,
        icon: Icon(icon),
        label: Text(label, style: const TextStyle(fontWeight: FontWeight.w700)),
      ),
    );
  }
}

class _CardDetail extends StatelessWidget {
  const _CardDetail({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: const Color(0xFFCDE3E1), size: 18),
        const SizedBox(width: 7),
        Text(text, style: const TextStyle(color: Color(0xFFE6F2F1), fontSize: 13)),
      ],
    );
  }
}

class _TransactionTile extends StatelessWidget {
  const _TransactionTile({required this.transaction, required this.money});

  final BankTransaction transaction;
  final String Function(double) money;

  @override
  Widget build(BuildContext context) {
    final deposit = transaction.isDeposit;
    final color = deposit ? const Color(0xFF187E68) : const Color(0xFFC05B39);

    return Card(
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
        leading: CircleAvatar(
          backgroundColor: color.withValues(alpha: 0.12),
          foregroundColor: color,
          child: Icon(deposit ? Icons.south_west_rounded : Icons.north_east_rounded),
        ),
        title: Text(deposit ? 'Depósito' : 'Saque', style: const TextStyle(fontWeight: FontWeight.w700)),
        subtitle: const Text('Movimentação registrada'),
        trailing: Text(
          '${deposit ? '+' : '-'} ${money(transaction.value)}',
          style: TextStyle(color: color, fontWeight: FontWeight.w800, fontSize: 15),
        ),
      ),
    );
  }
}

class _EmptyStatement extends StatelessWidget {
  const _EmptyStatement();

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(30),
        child: Column(
          children: [
            Icon(Icons.inbox_outlined, size: 38, color: Theme.of(context).colorScheme.primary),
            const SizedBox(height: 12),
            const Text('Não foram realizadas movimentações.', textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }
}

class _InlineError extends StatelessWidget {
  const _InlineError({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFFFE9E6),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          const Icon(Icons.cloud_off_outlined, color: Color(0xFF9F3434)),
          const SizedBox(width: 10),
          Expanded(child: Text(message)),
        ],
      ),
    );
  }
}

class _ConnectionError extends StatelessWidget {
  const _ConnectionError({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 520,
      child: Center(
        child: Card(
          child: Padding(
            padding: const EdgeInsets.all(30),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.cloud_off_outlined, size: 46, color: Color(0xFF9F3434)),
                const SizedBox(height: 16),
                Text(message, textAlign: TextAlign.center),
                const SizedBox(height: 20),
                FilledButton.icon(
                  onPressed: onRetry,
                  icon: const Icon(Icons.refresh),
                  label: const Text('Tentar novamente'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
