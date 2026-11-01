import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shopease_mobile/controllers/orders_controller.dart';

import 'order_details_state.dart';

export 'order_details_state.dart';

// [ملاحظة] — مفيش OrderDetailsService/Repository/Controller جديدة عمدًا:
// جلب أوردر واحد (fetchOrderById) وإلغاؤه (cancelOrder) أصلًا موجودين
// وشغالين في OrdersController/OrdersRepository/OrdersService (اتضافوا وقت
// شغل شاشة الـOrders list). عمل نسخة موازية منهم هنا كان هيبقى duplicate
// كامل لنفس الـmodel ونفس الـendpoints. الطبقة الوحيدة الناقصة فعليًا كانت
// الـcubit/state بتاعة شاشة التفاصيل نفسها، فده اللي اتضاف هنا.
class OrderDetailsCubit extends Cubit<OrderDetailsState> {
  OrderDetailsCubit({required this.ordersController})
      : super(const OrderDetailsState(isLoading: true));

  final OrdersController ordersController;

  Future<void> loadOrder(String id) async {
    emit(state.copyWith(isLoading: true, clearError: true));
    try {
      final order = await ordersController.fetchOrderById(id);
      if (order == null) {
        emit(state.copyWith(isLoading: false, error: 'Order not found.'));
        return;
      }
      emit(state.copyWith(order: order, isLoading: false));
    } catch (e) {
      emit(state.copyWith(
        isLoading: false,
        error: e.toString().replaceFirst('Exception: ', ''),
      ));
    }
  }

  // بيرجع true لو الإلغاء نجح عشان الشاشة تعرف تحدث رسالة/تنقل، وbيسيب
  // مسؤولية مزامنة شاشة الـOrders list (OrdersCubit) للـUI نفسه، مش الـcubit
  // ده — الاتنين cubits مستقلين عن بعض عمدًا.
  Future<bool> cancelOrder() async {
    final order = state.order;
    if (order == null) return false;

    emit(state.copyWith(isCancelling: true, clearError: true));
    try {
      final updated = await ordersController.cancelOrder(order.id);
      emit(state.copyWith(order: updated, isCancelling: false));
      return true;
    } catch (e) {
      emit(state.copyWith(
        isCancelling: false,
        error: e.toString().replaceFirst('Exception: ', ''),
      ));
      return false;
    }
  }
}
