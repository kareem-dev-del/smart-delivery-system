import 'package:shopease_mobile/core/network/api_client.dart';
import 'package:shopease_mobile/core/network/api_error.dart';
import 'package:shopease_mobile/models/order.dart';

class OrdersService {
  OrdersService({required ApiClient client}) : _client = client;

  final ApiClient _client;

  // Customer orders endpoint returns this user's orders only.
  Future<List<Order>> fetchOrders() {
    return _client.get<List<Order>>(
      '/api/orders/',
      parser: (data) {
        final raw = data is Map<String, dynamic>
            ? (data['results'] ?? data['orders'] ?? data['data'] ?? const [])
            : data;
        final list = raw as List<dynamic>;
        return list
            .map((e) => Order.fromJson(e as Map<String, dynamic>))
            .toList();
      },
    );
  }

  // GET /orders/:id — مفيدة لشاشة تفاصيل أوردر لاحقًا (زي "Buy Again" /
  // "Track Order" الموجودين في التصميم بس من غير أي منطق حاليًا)
  Future<Order?> fetchOrderById(String id) async {
    try {
      final response = await _client.get<Map<String, dynamic>>('/api/orders/$id/');
      final orderJson = response['order'] ?? response['data'] ?? response;
      if (orderJson is! Map<String, dynamic>) return null;
      return Order.fromJson(orderJson);
    } on ApiException catch (e) {
      if (e.isNotFound) return null;
      rethrow;
    }
  }

  // POST /api/orders/:id/cancel/ returns the updated order.
  // لـ'cancelled' من السيرفر (مش بنغيره محليًا فقط عشان لو فيه business rule
  // زي "متأخر أوي على الإلغاء" السيرفر هو اللي يقرر ويرفض لو محتاج)
  Future<Order> cancelOrder(String id) {
    return _client.post<Order>(
      '/api/orders/$id/cancel/',
      parser: (data) {
        final orderJson = data is Map<String, dynamic>
            ? (data['order'] ?? data['data'] ?? data)
            : data;
        return Order.fromJson(orderJson as Map<String, dynamic>);
      },
    );
  }
}
