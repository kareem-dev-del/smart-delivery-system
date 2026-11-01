import 'package:shopease_mobile/models/cart_item.dart';
import 'package:shopease_mobile/models/order.dart';
import 'package:shopease_mobile/repositories/checkout_repository.dart';

class CheckoutController {
  CheckoutController({required CheckoutRepository checkoutRepository})
      : _checkoutRepository = checkoutRepository;

  final CheckoutRepository _checkoutRepository;

  Future<Order> placeOrder({
    required List<CartItem> cartItems,
    required int lockerStationId,
  }) =>
      _checkoutRepository.placeOrder(
        cartItems: cartItems,
        lockerStationId: lockerStationId,
      );
}
