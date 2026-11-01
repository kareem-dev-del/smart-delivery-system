import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shopease_mobile/controllers/wishlist_controller.dart';
import 'package:shopease_mobile/models/product.dart';

import 'wishlist_state.dart';

export 'wishlist_state.dart';

class WishlistCubit extends Cubit<WishlistState> {
  WishlistCubit({required this.wishlistController})
      : super(const WishlistState(isLoading: true));

  final WishlistController wishlistController;

  Future<void> restoreWishlist() async {
    emit(state.copyWith(isLoading: true));
    try {
      final items = await wishlistController.loadWishlist();
      emit(WishlistState(items: items, isLoading: false));
    } catch (_) {
      emit(WishlistState(isLoading: false));
    }
  }

  Future<void> addProduct(Product product) async {
    emit(state.copyWith(items: await wishlistController.addProduct(state.items, product)));
  }

  Future<void> removeProduct(String productId) async {
    emit(state.copyWith(items: await wishlistController.removeProduct(state.items, productId)));
  }

  Future<void> toggle(Product product) async {
    emit(state.copyWith(items: await wishlistController.toggle(state.items, product)));
  }

  Future<void> clearAll() async {
    emit(state.copyWith(items: await wishlistController.clearAll()));
  }
}