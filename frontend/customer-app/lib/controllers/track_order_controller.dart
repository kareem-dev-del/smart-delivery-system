import 'package:shopease_mobile/models/order_tracking.dart';
import 'package:shopease_mobile/repositories/track_order_repository.dart';

class TrackOrderController {
  TrackOrderController({required TrackOrderRepository trackOrderRepository})
      : _trackOrderRepository = trackOrderRepository;

  final TrackOrderRepository _trackOrderRepository;

  Future<OrderTracking> fetchTracking(String orderId) =>
      _trackOrderRepository.fetchTracking(orderId);
}
