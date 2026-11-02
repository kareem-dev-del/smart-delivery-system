import 'package:shopease_mobile/models/order.dart';
import 'package:shopease_mobile/services/orders_service.dart';

class OrdersRepository {
  OrdersRepository({required OrdersService ordersService})
      : _ordersService = ordersService;

  final OrdersService _ordersService;

  Future<List<Order>> fetchOrders() => _ordersService.fetchOrders();

  Future<Order?> fetchOrderById(String id) =>
      _ordersService.fetchOrderById(id);

  Future<Order> cancelOrder(String id) => _ordersService.cancelOrder(id);
}
