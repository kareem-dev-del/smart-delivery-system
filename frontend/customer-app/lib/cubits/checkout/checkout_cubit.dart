import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shopease_mobile/controllers/checkout_controller.dart';
import 'package:shopease_mobile/core/network/api_error.dart';
import 'package:shopease_mobile/models/cart_item.dart';

import 'checkout_state.dart';

export 'checkout_state.dart';

class CheckoutCubit extends Cubit<CheckoutState> {
  CheckoutCubit({required this.checkoutController})
      : super(const CheckoutState());

  final CheckoutController checkoutController;

  void reset() => emit(const CheckoutState());

  Future<bool> placeOrder({
    required List<CartItem> cartItems,
    required int lockerStationId,
  }) async {
    if (state.isSubmitting) return false;
    if (cartItems.isEmpty) {
      emit(state.copyWith(error: 'Your cart is empty.'));
      return false;
    }

    emit(state.copyWith(isSubmitting: true, orderPlaced: false, clearError: true));
    try {
      final order = await checkoutController.placeOrder(
        cartItems: cartItems,
        lockerStationId: lockerStationId,
      );
      emit(state.copyWith(
        isSubmitting: false,
        orderPlaced: true,
        placedOrder: order,
      ));
      return true;
    } on ApiException catch (error) {
      emit(state.copyWith(isSubmitting: false, error: error.message));
      return false;
    } catch (_) {
      emit(state.copyWith(
        isSubmitting: false,
        error: 'Something went wrong while placing your order.',
      ));
      return false;
    }
  }
}
