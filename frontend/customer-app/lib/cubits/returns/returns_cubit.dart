import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shopease_mobile/controllers/returns_controller.dart';

import 'returns_state.dart';

export 'returns_state.dart';

class ReturnsCubit extends Cubit<ReturnsState> {
  ReturnsCubit({required this.returnsController})
      : super(const ReturnsState(isLoading: true));

  final ReturnsController returnsController;

  Future<void> loadReturns() async {
    emit(state.copyWith(isLoading: true, clearError: true));
    try {
      final returns = await returnsController.fetchReturns();
      emit(state.copyWith(returns: returns, isLoading: false));
    } catch (e) {
      emit(state.copyWith(
        isLoading: false,
        error: e.toString().replaceFirst('Exception: ', ''),
      ));
    }
  }

  // بيحط الـreturn الجديد فوق الليستة الحالية على طول (زي CartCubit) من غير
  // reload كامل. بيرجع true/false عشان الـUI (bottom sheet) يعرف يقفل نفسه
  // أو يوري error.
  Future<bool> submitReturn({required String orderId, String? reason}) async {
    emit(state.copyWith(isSubmitting: true, clearError: true));
    try {
      final newReturn = await returnsController.submitReturn(
        orderId: orderId,
        reason: reason,
      );
      emit(state.copyWith(
        returns: [newReturn, ...state.returns],
        isSubmitting: false,
      ));
      return true;
    } catch (e) {
      emit(state.copyWith(
        isSubmitting: false,
        error: e.toString().replaceFirst('Exception: ', ''),
      ));
      return false;
    }
  }
}
