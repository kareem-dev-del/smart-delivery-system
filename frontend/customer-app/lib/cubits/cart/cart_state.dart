import 'package:shopease_mobile/models/cart_item.dart';

class CartState {
  const CartState({
    this.items = const [],
    this.isLoading = false,
  });

  final List<CartItem> items;
  final bool isLoading;

  int get totalItems => items.fold<int>(0, (sum, item) => sum + item.quantity);

  // [تعديل] — round لأقرب قرش بعد الـfold عشان جمع أكتر من منتج فوق
  // بعضه بيسبب floating point error (زي 29.97 + 19.99 = 49.959999999999994)
  double get totalPrice {
    final raw = items.fold<double>(
      0,
      (sum, item) => sum + item.product.price * item.quantity,
    );
    return (raw * 100).round() / 100;
  }

  bool isInCart(String productId) =>
      items.any((item) => item.product.id == productId);

  int quantityOf(String productId) {
    try {
      return items.firstWhere((item) => item.product.id == productId).quantity;
    } catch (_) {
      return 0;
    }
  }

  CartState copyWith({
    List<CartItem>? items,
    bool? isLoading,
  }) {
    return CartState(
      items: items ?? this.items,
      isLoading: isLoading ?? this.isLoading,
    );
  }
}