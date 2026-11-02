import 'package:shopease_mobile/models/product.dart';

class WishlistState {
  const WishlistState({
    this.items = const [],
    this.isLoading = false,
  });

  final List<Product> items;
  final bool isLoading;

  int get count => items.length;

  bool isWishlisted(String productId) => items.any((p) => p.id == productId);

  WishlistState copyWith({
    List<Product>? items,
    bool? isLoading,
  }) {
    return WishlistState(
      items: items ?? this.items,
      isLoading: isLoading ?? this.isLoading,
    );
  }
}