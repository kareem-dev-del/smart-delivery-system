import 'package:shopease_mobile/core/network/api_client.dart';
import 'package:shopease_mobile/models/payment_method.dart';

class PaymentMethodService {
  PaymentMethodService({required ApiClient apiClient}) : _apiClient = apiClient;

  final ApiClient _apiClient;

  Future<List<PaymentMethod>> fetchPaymentMethods() {
    return _apiClient.get<List<PaymentMethod>>(
      '/payment-methods',
      parser: (data) {
        final items = data as List<dynamic>;
        return items
            .map((item) => PaymentMethod.fromJson(item as Map<String, dynamic>))
            .toList();
      },
    );
  }

  Future<PaymentMethod> addPaymentMethod({
    required PaymentMethodType type,
    String? lastFour,
    String? expiry,
    String? holderName,
  }) {
    return _apiClient.post<PaymentMethod>(
      '/payment-methods',
      body: {
        'type': type.name,
        'lastFour': lastFour,
        'expiry': expiry,
        'holderName': holderName,
      },
      parser: (data) => PaymentMethod.fromJson(data as Map<String, dynamic>),
    );
  }

  Future<void> removePaymentMethod(String id) async {
    await _apiClient.delete<dynamic>('/payment-methods/$id');
  }

  Future<void> setDefaultPaymentMethod(String id) async {
    await _apiClient.patch<dynamic>('/payment-methods/$id/default');
  }
}
