import 'package:shopease_mobile/core/network/api_error.dart';
import 'package:shopease_mobile/models/cart_item.dart';
import 'package:shopease_mobile/models/order.dart';
import 'package:shopease_mobile/services/checkout_service.dart';

class CheckoutRepository {
  CheckoutRepository({required CheckoutService checkoutService})
      : _checkoutService = checkoutService;

  final CheckoutService _checkoutService;

  Future<Order> placeOrder({
    required List<CartItem> cartItems,
    required int lockerStationId,
  }) {
    if (cartItems.isEmpty) {
      throw const ApiException(message: 'Your cart is empty.');
    }

    final items = <OrderItem>[];
    for (final cartItem in cartItems) {
      if (int.tryParse(cartItem.product.id) == null) {
        throw const ApiException(
          message: 'A product in your cart has an invalid ID. Remove it and add it again.',
        );
      }
      items.add(OrderItem(
        productId: cartItem.product.id,
        name: cartItem.product.name,
        imageUrl: cartItem.product.imageUrl,
        price: cartItem.product.price,
        quantity: cartItem.quantity,
      ));
    }

    return _checkoutService.placeOrder(
      items: items,
      lockerStationId: lockerStationId,
    );
  }
}
