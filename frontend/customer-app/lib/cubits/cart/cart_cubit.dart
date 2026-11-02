import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shopease_mobile/controllers/cart_controller.dart';
import 'package:shopease_mobile/models/product.dart';

import 'cart_state.dart';

export 'cart_state.dart';

class CartCubit extends Cubit<CartState> {
  CartCubit({required this.cartController}) : super(const CartState(isLoading: true));

  final CartController cartController;

  Future<void> restoreCart() async {
    emit(state.copyWith(isLoading: true));
    try {
      final items = await cartController.loadCart();
      emit(CartState(items: items, isLoading: false));
    } catch (_) {
      emit(CartState(isLoading: false));
    }
  }

  Future<void> addToCart(Product product) async {
    emit(state.copyWith(items: await cartController.addToCart(state.items, product)));
  }

  Future<void> removeFromCart(String productId) async {
    emit(state.copyWith(items: await cartController.removeFromCart(state.items, productId)));
  }

  Future<void> incrementQuantity(String productId) async {
    emit(state.copyWith(items: await cartController.incrementQuantity(state.items, productId)));
  }

  Future<void> decrementQuantity(String productId) async {
    emit(state.copyWith(items: await cartController.decrementQuantity(state.items, productId)));
  }

  Future<void> updateQuantity(String productId, int quantity) async {
    emit(state.copyWith(items: await cartController.updateQuantity(state.items, productId, quantity)));
  }

  Future<void> clearCart() async {
    emit(state.copyWith(items: await cartController.clearCart()));
  }
}