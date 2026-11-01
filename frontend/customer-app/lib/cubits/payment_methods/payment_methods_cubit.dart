import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shopease_mobile/controllers/payment_methods_controller.dart';
import 'package:shopease_mobile/models/payment_method.dart';

import 'payment_methods_state.dart';

export 'payment_methods_state.dart';

class PaymentMethodsCubit extends Cubit<PaymentMethodsState> {
  PaymentMethodsCubit({required this.paymentMethodsController})
      : super(const PaymentMethodsState(isLoading: true));

  final PaymentMethodsController paymentMethodsController;

  Future<void> loadMethods() async {
    emit(state.copyWith(isLoading: true, clearError: true));
    try {
      final methods = await paymentMethodsController.loadMethods();
      emit(PaymentMethodsState(methods: methods, isLoading: false));
    } catch (e) {
      emit(state.copyWith(isLoading: false, error: _readableError(e)));
    }
  }

  Future<bool> addCard({
    required PaymentMethodType type,
    required String lastFour,
    required String expiry,
    required String holderName,
  }) async {
    emit(state.copyWith(isMutating: true, clearError: true));
    try {
      final methods = await paymentMethodsController.addMethod(
        state.methods,
        type: type,
        lastFour: lastFour,
        expiry: expiry,
        holderName: holderName,
      );
      emit(state.copyWith(methods: methods, isMutating: false));
      return true;
    } catch (e) {
      emit(state.copyWith(isMutating: false, error: _readableError(e)));
      return false;
    }
  }

  Future<bool> removeMethod(String id) async {
    emit(state.copyWith(isMutating: true, clearError: true));
    try {
      final methods = await paymentMethodsController.removeMethod(state.methods, id);
      emit(state.copyWith(methods: methods, isMutating: false));
      return true;
    } catch (e) {
      emit(state.copyWith(isMutating: false, error: _readableError(e)));
      return false;
    }
  }

  Future<void> setDefault(String id) async {
    final previous = state.methods;
    // [تفاؤلي] بنحدّث الليستة محليًا الأول عشان الـUI يستجيب فورًا،
    // ولو الـrequest فشل بنرجع الحالة القديمة.
    emit(state.copyWith(
      methods: previous.map((m) => m.copyWith(isDefault: m.id == id)).toList(),
      clearError: true,
    ));
    try {
      final methods = await paymentMethodsController.setDefault(previous, id);
      emit(state.copyWith(methods: methods));
    } catch (e) {
      emit(state.copyWith(methods: previous, error: _readableError(e)));
    }
  }

  String _readableError(Object error) {
    return error.toString().replaceFirst('Exception: ', '');
  }
}
