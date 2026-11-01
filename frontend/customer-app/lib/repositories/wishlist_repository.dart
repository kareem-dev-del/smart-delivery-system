import 'package:shopease_mobile/models/product.dart';
import 'package:shopease_mobile/services/wishlist_service.dart';

class WishlistRepository {
  WishlistRepository({required WishlistService wishlistService})
      : _wishlistService = wishlistService;

  final WishlistService _wishlistService;

  Future<List<Product>> loadWishlist() {
    return _wishlistService.loadWishlist();
  }

  Future<List<Product>> addProduct(
    List<Product> current,
    Product product,
  ) async {
    if (current.any((p) => p.id == product.id)) {
      return current;
    }

    await _wishlistService.addToWishlist(product.id);

    return [...current, product];
  }

  Future<List<Product>> removeProduct(
    List<Product> current,
    String productId,
  ) async {
    if (!current.any((p) => p.id == productId)) {
      return current;
    }

    await _wishlistService.removeFromWishlist(productId);

    return current.where((p) => p.id != productId).toList();
  }

  Future<List<Product>> toggle(
    List<Product> current,
    Product product,
  ) {
    final exists = current.any((p) => p.id == product.id);

    return exists
        ? removeProduct(current, product.id)
        : addProduct(current, product);
  }

  Future<List<Product>> clearAll() async {
    await _wishlistService.clearWishlist();
    return const [];
  }
}