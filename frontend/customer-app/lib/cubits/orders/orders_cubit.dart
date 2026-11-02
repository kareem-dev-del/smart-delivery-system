import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shopease_mobile/controllers/orders_controller.dart';

import 'orders_state.dart';

export 'orders_state.dart';

class OrdersCubit extends Cubit<OrdersState> {
  OrdersCubit({required this.ordersController})
      : super(const OrdersState(isLoading: true));

  final OrdersController ordersController;

  Future<void> loadOrders() async {
    emit(state.copyWith(isLoading: true, clearError: true));
    try {
      final orders = await ordersController.fetchOrders();
      emit(state.copyWith(orders: orders, isLoading: false));
    } catch (e) {
      emit(state.copyWith(
        isLoading: false,
        error: e.toString().replaceFirst('Exception: ', ''),
      ));
    }
  }

  // [جديد] — بيلغي أوردر واحد ويحدّثه مكانه جوه الليستة الحالية (مش بيعمل
  // reload كامل عشان الشاشة متترجعش لأول الليستة وتفقد الـscroll position).
  // لو الطلب فشل، بنمسح الـcancellingOrderId ونعرض error من غير ما نلمس
  // حالة الأوردر نفسها (يفضل زي ما هو لحد ما يتظبط).
  Future<void> cancelOrder(String id) async {
    emit(state.copyWith(cancellingOrderId: id, clearError: true));
    try {
      final updated = await ordersController.cancelOrder(id);
      final orders = [
        for (final order in state.orders)
          if (order.id == id) updated else order,
      ];
      emit(state.copyWith(orders: orders, clearCancelling: true));
    } catch (e) {
      emit(state.copyWith(
        clearCancelling: true,
        error: e.toString().replaceFirst('Exception: ', ''),
      ));
    }
  }
}
