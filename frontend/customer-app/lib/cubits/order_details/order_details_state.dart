import 'package:shopease_mobile/models/order.dart';

class OrderDetailsState {
  const OrderDetailsState({
    this.order,
    this.isLoading = false,
    this.error,
    this.isCancelling = false,
  });

  final Order? order;
  final bool isLoading;
  final String? error;
  final bool isCancelling;

  OrderDetailsState copyWith({
    Order? order,
    bool? isLoading,
    String? error,
    bool clearError = false,
    bool? isCancelling,
  }) {
    return OrderDetailsState(
      order: order ?? this.order,
      isLoading: isLoading ?? this.isLoading,
      error: clearError ? null : (error ?? this.error),
      isCancelling: isCancelling ?? this.isCancelling,
    );
  }
}
