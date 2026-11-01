import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shopease_mobile/controllers/shipping_address_controller.dart';
import 'package:shopease_mobile/models/shipping_address.dart';

import 'shipping_address_state.dart';

export 'shipping_address_state.dart';

class ShippingAddressCubit extends Cubit<ShippingAddressState> {
  ShippingAddressCubit({required this.shippingAddressController})
      : super(const ShippingAddressState(isLoading: true));

  final ShippingAddressController shippingAddressController;

  Future<void> loadAddress() async {
    emit(state.copyWith(isLoading: true, clearError: true));
    try {
      final address = await shippingAddressController.fetchAddress();
      // [جديد] — clearAddress صريحة عشان لو السيرفر رجّع null (مفيش عنوان
      // محفوظ)، الحالة فعلاً تتصفّر بدل ما تفضل مسكة آخر قيمة كانت متخزنة
      emit(state.copyWith(
        address: address,
        clearAddress: address == null,
        isLoading: false,
      ));
    } catch (e) {
      emit(state.copyWith(isLoading: false, error: e.toString().replaceFirst('Exception: ', '')));
    }
  }

  Future<bool> saveAddress(ShippingAddress address) async {
    emit(state.copyWith(isSaving: true, clearError: true));
    try {
      final saved = await shippingAddressController.saveAddress(address);
      emit(state.copyWith(address: saved, isSaving: false));
      return true;
    } catch (e) {
      emit(state.copyWith(isSaving: false, error: e.toString().replaceFirst('Exception: ', '')));
      return false;
    }
  }
}