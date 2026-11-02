import 'package:shopease_mobile/core/network/api_client.dart';
import 'package:shopease_mobile/models/order_tracking.dart';

class TrackOrderService {
  TrackOrderService({required ApiClient client}) : _client = client;

  final ApiClient _client;

  // The tracking endpoint returns the customer's own order status, locker,
  // assigned courier, and a timeline built from persisted order timestamps.
  Future<OrderTracking> fetchTracking(String orderId) {
    return _client.get<OrderTracking>(
      '/orders/$orderId/tracking/',
      parser: (data) {
        final trackingJson =
            data is Map<String, dynamic>
                ? (data['tracking'] ?? data['data'] ?? data)
                : data;
        return OrderTracking.fromJson(trackingJson as Map<String, dynamic>);
      },
    );
  }
}
