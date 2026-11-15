import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../../core/network/api_client.dart';
import '../../../core/network/api_exception.dart';

class TopUp {
  const TopUp({
    required this.id,
    required this.status,
    required this.requestedAmount,
    this.amount,
    this.checkoutUrl,
    this.message,
    this.createdAt,
  });
  final String id;
  final String status;
  final int requestedAmount;
  final int? amount;
  final String? checkoutUrl;
  final String? message;
  final DateTime? createdAt;
  bool get isPending => status == 'PENDING' || status == 'CREATING';

  factory TopUp.fromJson(Map<String, dynamic> data) => TopUp(
    id: data['id'] as String,
    status: data['status'] as String,
    requestedAmount: data['requestedAmount'] as int,
    amount: data['amount'] as int?,
    checkoutUrl: data['checkoutUrl'] as String?,
    message: data['message'] as String?,
    createdAt: DateTime.tryParse(data['createdAt'] as String? ?? ''),
  );
}

abstract interface class TopUpService {
  Future<TopUp> create(int amount);
  Future<TopUp> get(String id);
  Future<List<TopUp>> list();
}

class ApiTopUpService implements TopUpService {
  ApiTopUpService({ApiClient? apiClient}) : _client = apiClient ?? ApiClient();
  final ApiClient _client;

  Map<String, dynamic> _parse(http.Response response, int expectedStatus) {
    try {
      final body = jsonDecode(response.body) as Map<String, dynamic>;
      if (response.statusCode != expectedStatus || body['success'] != true) {
        throw ApiException(
          response.statusCode,
          body['message'] as String? ?? 'Unable to access top-ups.',
        );
      }
      return body['data'] as Map<String, dynamic>;
    } on FormatException {
      throw ApiException(
        response.statusCode,
        'Unable to read the server response.',
      );
    } on TypeError {
      throw ApiException(
        response.statusCode,
        'Unable to read the server response.',
      );
    }
  }

  @override
  Future<TopUp> create(int amount) async {
    final response = await _client
        .authenticatedPost('/api/topups', body: {'amount': amount})
        .timeout(const Duration(seconds: 60));
    return TopUp.fromJson(
      _parse(response, 201)['topup'] as Map<String, dynamic>,
    );
  }

  @override
  Future<TopUp> get(String id) async {
    final response = await _client
        .authenticatedGet('/api/topups/${Uri.encodeComponent(id)}')
        .timeout(const Duration(seconds: 30));
    return TopUp.fromJson(
      _parse(response, 200)['topup'] as Map<String, dynamic>,
    );
  }

  @override
  Future<List<TopUp>> list() async {
    final response = await _client
        .authenticatedGet('/api/topups')
        .timeout(const Duration(seconds: 15));
    return (_parse(response, 200)['topups'] as List)
        .map((item) => TopUp.fromJson(item as Map<String, dynamic>))
        .toList();
  }
}
