import 'package:shopease_mobile/models/product.dart';
import 'package:shopease_mobile/repositories/wishlist_repository.dart';

class WishlistController {
  WishlistController({required WishlistRepository wishlistRepository})
      : _wishlistRepository = wishlistRepository;

  final WishlistRepository _wishlistRepository;

  Future<List<Product>> loadWishlist() => _wishlistRepository.loadWishlist();

  Future<List<Product>> addProduct(List<Product> current, Product product) =>
      _wishlistRepository.addProduct(current, product);

  Future<List<Product>> removeProduct(List<Product> current, String productId) =>
      _wishlistRepository.removeProduct(current, productId);

  Future<List<Product>> toggle(List<Product> current, Product product) =>
      _wishlistRepository.toggle(current, product);

  Future<List<Product>> clearAll() => _wishlistRepository.clearAll();
}
