import 'dart:async';
import 'dart:convert';

import '../../../core/network/api_client.dart';
import '../../../core/network/api_exception.dart';
import '../models/customer_transaction.dart';

abstract interface class CustomerTransactionService {
  Future<List<CustomerTransaction>> getTransactions({int limit = 50});
}

class ApiCustomerTransactionService implements CustomerTransactionService {
  ApiCustomerTransactionService({
    ApiClient? apiClient,
    this.timeout = const Duration(seconds: 15),
  }) : _apiClient = apiClient ?? ApiClient();

  final ApiClient _apiClient;
  final Duration timeout;

  @override
  Future<List<CustomerTransaction>> getTransactions({int limit = 50}) async {
    if (limit < 1 || limit > 50) {
      throw ArgumentError.value(limit, 'limit', 'must be from 1 to 50');
    }

    final response = await _apiClient
        .authenticatedGet('/api/customer/transactions?limit=$limit')
        .timeout(timeout);
    if (response.statusCode != 200) {
      throw ApiException(
        response.statusCode,
        'Unable to retrieve customer transactions',
      );
    }

    try {
      final body = jsonDecode(response.body) as Map<String, dynamic>;
      if (body['success'] != true) throw const FormatException();
      final data = body['data'] as Map<String, dynamic>;
      final transactions = data['transactions'] as List<dynamic>;
      final parsed = transactions
          .map(
            (item) =>
                CustomerTransaction.fromJson(item as Map<String, dynamic>),
          )
          .toList(growable: false);
      parsed.sort((left, right) => right.createdAt.compareTo(left.createdAt));
      return parsed;
    } on FormatException {
      throw const ApiException(200, 'Invalid transaction history response');
    } on TypeError {
      throw const ApiException(200, 'Invalid transaction history response');
    }
  }
}
