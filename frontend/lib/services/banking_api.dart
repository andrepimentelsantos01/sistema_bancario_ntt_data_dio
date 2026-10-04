import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/transaction.dart';

class BankState {
  const BankState({
    required this.balance,
    required this.withdrawalLimit,
    required this.withdrawals,
    required this.withdrawalCountLimit,
  });

  final double balance;
  final double withdrawalLimit;
  final int withdrawals;
  final int withdrawalCountLimit;

  factory BankState.fromJson(Map<String, dynamic> json) {
    return BankState(
      balance: (json['saldo'] as num).toDouble(),
      withdrawalLimit: (json['limite_saque'] as num).toDouble(),
      withdrawals: json['numero_saques'] as int,
      withdrawalCountLimit: json['limite_saques'] as int,
    );
  }
}

class OperationResult {
  const OperationResult({required this.success, required this.message});

  final bool success;
  final String message;

  factory OperationResult.fromJson(Map<String, dynamic> json) {
    return OperationResult(
      success: json['sucesso'] as bool? ?? false,
      message: json['mensagem'] as String? ?? 'Não foi possível concluir a operação.',
    );
  }
}

class BankingApiException implements Exception {
  const BankingApiException(this.message);

  final String message;
}

class BankingApi {
  BankingApi({http.Client? client}) : _client = client ?? http.Client();

  static const _baseUrl = 'http://127.0.0.1:8000';
  static const _timeout = Duration(seconds: 5);

  final http.Client _client;

  Future<BankState> fetchState() async {
    final response = await _get('/state');
    return BankState.fromJson(_decodeMap(response));
  }

  Future<List<BankTransaction>> fetchStatement() async {
    final response = await _get('/statement');
    final data = jsonDecode(utf8.decode(response.bodyBytes)) as List<dynamic>;
    return data
        .map((item) => BankTransaction.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  Future<OperationResult> deposit(double value) => _operation('/deposit', value);

  Future<OperationResult> withdraw(double value) => _operation('/withdraw', value);

  Future<OperationResult> reset() => _post('/reset', const {});

  Future<OperationResult> _operation(String path, double value) {
    return _post(path, {'valor': value});
  }

  Future<OperationResult> _post(String path, Map<String, dynamic> body) async {
    try {
      final response = await _client
          .post(
            Uri.parse('$_baseUrl$path'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode(body),
          )
          .timeout(_timeout);
      return OperationResult.fromJson(_decodeMap(response));
    } on TimeoutException {
      throw const BankingApiException('Não foi possível conectar ao servidor local.');
    } on http.ClientException {
      throw const BankingApiException('Não foi possível conectar ao servidor local.');
    } on FormatException {
      throw const BankingApiException('O servidor retornou uma resposta inválida.');
    }
  }

  Future<http.Response> _get(String path) async {
    try {
      final response = await _client
          .get(Uri.parse('$_baseUrl$path'))
          .timeout(_timeout);
      if (response.statusCode != 200) {
        throw const BankingApiException('Não foi possível carregar os dados da conta.');
      }
      return response;
    } on TimeoutException {
      throw const BankingApiException('Não foi possível conectar ao servidor local.');
    } on http.ClientException {
      throw const BankingApiException('Não foi possível conectar ao servidor local.');
    }
  }

  Map<String, dynamic> _decodeMap(http.Response response) {
    final data = jsonDecode(utf8.decode(response.bodyBytes));
    if (data is! Map<String, dynamic>) {
      throw const FormatException();
    }
    return data;
  }

  void close() => _client.close();
}
