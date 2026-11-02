import 'package:shopease_mobile/core/network/api_client.dart';
import 'package:shopease_mobile/models/product.dart';

class WishlistService {
  WishlistService({required ApiClient apiClient}) : _apiClient = apiClient;

  final ApiClient _apiClient;

  Future<List<Product>> loadWishlist() {
    return _apiClient.get<List<Product>>(
      '/wishlist',
      parser: (data) {
        final items = data as List<dynamic>;
        return items.map((item) => Product.fromJson(item as Map<String, dynamic>)).toList();
      },
    );
  }

  Future<Product> addToWishlist(String productId) {
    return _apiClient.post<Product>(
      '/wishlist',
      body: {'productId': productId},
      parser: (data) => Product.fromJson(data as Map<String, dynamic>),
    );
  }

  Future<void> removeFromWishlist(String productId) async {
    await _apiClient.delete<dynamic>('/wishlist/$productId');
  }

  Future<void> clearWishlist() async {
    await _apiClient.delete<dynamic>('/wishlist');
  }
}