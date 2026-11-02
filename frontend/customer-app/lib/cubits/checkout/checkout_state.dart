import 'package:shopease_mobile/models/order.dart';

class CheckoutState {
  const CheckoutState({
    this.isSubmitting = false,
    this.orderPlaced = false,
    this.placedOrder,
    this.error,
  });

  final bool isSubmitting;
  final bool orderPlaced;
  final Order? placedOrder;
  final String? error;

  CheckoutState copyWith({
    bool? isSubmitting,
    bool? orderPlaced,
    Order? placedOrder,
    String? error,
    bool clearError = false,
  }) =>
      CheckoutState(
        isSubmitting: isSubmitting ?? this.isSubmitting,
        orderPlaced: orderPlaced ?? this.orderPlaced,
        placedOrder: placedOrder ?? this.placedOrder,
        error: clearError ? null : (error ?? this.error),
      );
}
