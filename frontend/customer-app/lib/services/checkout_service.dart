import 'package:shopease_mobile/core/network/api_client.dart';
import 'package:shopease_mobile/core/network/api_error.dart';
import 'package:shopease_mobile/models/order.dart';

class CheckoutService {
  CheckoutService({required ApiClient client}) : _client = client;

  final ApiClient _client;

  Future<Order> placeOrder({
    required List<OrderItem> items,
    required int lockerStationId,
  }) async {
    if (items.isEmpty) {
      throw const ApiException(message: 'Your cart is empty.');
    }

    final response = await _client.post<Map<String, dynamic>>(
      '/api/orders/',
      body: {
        'locker_station_id': lockerStationId,
        'items': items
            .map((item) => {
                  'product_id': int.tryParse(item.productId),
                  'quantity': item.quantity,
                })
            .toList(),
      },
    );

    return Order.fromJson(response);
  }
}
