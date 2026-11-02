import 'package:shopease_mobile/models/cart_item.dart';
import 'package:shopease_mobile/models/product.dart';
import 'package:shopease_mobile/services/cart_service.dart';

class CartRepository {
  CartRepository({required CartService cartService})
      : _cartService = cartService;

  final CartService _cartService;

  Future<List<CartItem>> loadCart() {
    return _cartService.loadCart();
  }

  Future<List<CartItem>> addToCart(
    List<CartItem> current,
    Product product,
  ) async {
    final existingIndex = current.indexWhere(
      (item) => item.product.id == product.id,
    );

    if (existingIndex >= 0) {
      final currentQuantity = current[existingIndex].quantity;

      final newQuantity = currentQuantity + 1;

      final items = List<CartItem>.from(current);

      items[existingIndex] = items[existingIndex].copyWith(
        quantity: newQuantity,
      );

      await _cartService.saveCart(items);
      return items;
    }

    final items = [
      ...current,
      CartItem(
        product: product,
        quantity: 1,
      ),
    ];
    await _cartService.saveCart(items);
    return items;
  }

  Future<List<CartItem>> removeFromCart(
    List<CartItem> current,
    String productId,
  ) async {
    final exists = current.any(
      (item) => item.product.id == productId,
    );

    if (!exists) return current;

    final items = current
        .where((item) => item.product.id != productId)
        .toList();
    await _cartService.saveCart(items);
    return items;
  }

  Future<List<CartItem>> incrementQuantity(
    List<CartItem> current,
    String productId,
  ) async {
    final index = current.indexWhere(
      (item) => item.product.id == productId,
    );

    if (index < 0) return current;

    final newQuantity = current[index].quantity + 1;

    final items = List<CartItem>.from(current);

    items[index] = items[index].copyWith(
      quantity: newQuantity,
    );

    await _cartService.saveCart(items);
    return items;
  }

  Future<List<CartItem>> decrementQuantity(
    List<CartItem> current,
    String productId,
  ) async {
    final index = current.indexWhere(
      (item) => item.product.id == productId,
    );

    if (index < 0) return current;

    final currentQuantity = current[index].quantity;

    if (currentQuantity <= 1) {
      final items = List<CartItem>.from(current);
      items.removeAt(index);

      await _cartService.saveCart(items);
      return items;
    }

    final newQuantity = currentQuantity - 1;

    final items = List<CartItem>.from(current);

    items[index] = items[index].copyWith(
      quantity: newQuantity,
    );

    await _cartService.saveCart(items);
    return items;
  }

  Future<List<CartItem>> updateQuantity(
    List<CartItem> current,
    String productId,
    int quantity,
  ) async {
    if (quantity <= 0) {
      return removeFromCart(current, productId);
    }

    final index = current.indexWhere(
      (item) => item.product.id == productId,
    );

    if (index < 0) return current;

    final items = List<CartItem>.from(current);

    items[index] = items[index].copyWith(
      quantity: quantity,
    );

    await _cartService.saveCart(items);
    return items;
  }

  Future<List<CartItem>> clearCart() async {
    await _cartService.clearCart();

    return const [];
  }
}
