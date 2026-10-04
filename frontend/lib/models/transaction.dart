enum TransactionType { deposit, withdraw }

class BankTransaction {
  const BankTransaction({required this.type, required this.value});

  final TransactionType type;
  final double value;

  bool get isDeposit => type == TransactionType.deposit;

  factory BankTransaction.fromJson(Map<String, dynamic> json) {
    return BankTransaction(
      type: json['tipo'] == 'deposito'
          ? TransactionType.deposit
          : TransactionType.withdraw,
      value: (json['valor'] as num).toDouble(),
    );
  }
}
