import 'package:shopease_mobile/models/order_tracking.dart';
import 'package:shopease_mobile/services/track_order_service.dart';

class TrackOrderRepository {
  TrackOrderRepository({required TrackOrderService trackOrderService})
      : _trackOrderService = trackOrderService;

  final TrackOrderService _trackOrderService;

  Future<OrderTracking> fetchTracking(String orderId) =>
      _trackOrderService.fetchTracking(orderId);
}
