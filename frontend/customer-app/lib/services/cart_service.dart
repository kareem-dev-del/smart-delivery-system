import 'package:shopease_mobile/models/cart_item.dart';
import 'package:shopease_mobile/services/local_storage_service.dart';

class CartService {
  CartService({required LocalStorageService storageService})
      : _storageService = storageService;

  final LocalStorageService _storageService;

  Future<List<CartItem>> loadCart() => _storageService.getCart();

  Future<void> saveCart(List<CartItem> items) =>
      _storageService.saveCart(items);

  Future<void> clearCart() => _storageService.clearCart();
}
