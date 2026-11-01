import 'package:shopease_mobile/models/cart_item.dart';
import 'package:shopease_mobile/models/product.dart';
import 'package:shopease_mobile/repositories/cart_repository.dart';

class CartController {
  CartController({required CartRepository cartRepository})
      : _cartRepository = cartRepository;

  final CartRepository _cartRepository;

  Future<List<CartItem>> loadCart() => _cartRepository.loadCart();

  Future<List<CartItem>> addToCart(List<CartItem> current, Product product) =>
      _cartRepository.addToCart(current, product);

  Future<List<CartItem>> removeFromCart(List<CartItem> current, String productId) =>
      _cartRepository.removeFromCart(current, productId);

  Future<List<CartItem>> incrementQuantity(List<CartItem> current, String productId) =>
      _cartRepository.incrementQuantity(current, productId);

  Future<List<CartItem>> decrementQuantity(List<CartItem> current, String productId) =>
      _cartRepository.decrementQuantity(current, productId);

  Future<List<CartItem>> updateQuantity(List<CartItem> current, String productId, int quantity) =>
      _cartRepository.updateQuantity(current, productId, quantity);

  Future<List<CartItem>> clearCart() => _cartRepository.clearCart();
}