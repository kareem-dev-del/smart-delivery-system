import 'package:shopease_mobile/models/order.dart';

class OrdersState {
  const OrdersState({
    this.orders = const [],
    this.isLoading = false,
    this.error,
    this.cancellingOrderId,
  });

  final List<Order> orders;
  final bool isLoading;
  final String? error;

  // [جديد] — id الأوردر اللي بيتلغي دلوقتي، عشان الـUI يقدر يعرض
  // loading indicator على زرار الـCancel بتاع الكارت ده بس، مش الشاشة كلها
  final String? cancellingOrderId;

  bool get isEmpty => !isLoading && error == null && orders.isEmpty;

  OrdersState copyWith({
    List<Order>? orders,
    bool? isLoading,
    String? error,
    bool clearError = false,
    String? cancellingOrderId,
    bool clearCancelling = false,
  }) {
    return OrdersState(
      orders: orders ?? this.orders,
      isLoading: isLoading ?? this.isLoading,
      error: clearError ? null : (error ?? this.error),
      cancellingOrderId: clearCancelling
          ? null
          : (cancellingOrderId ?? this.cancellingOrderId),
    );
  }
}
