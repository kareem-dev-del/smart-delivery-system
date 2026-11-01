import 'package:shopease_mobile/models/payment_method.dart';
import 'package:shopease_mobile/services/payment_method_service.dart';

class PaymentMethodRepository {
  PaymentMethodRepository({required PaymentMethodService paymentMethodService})
      : _paymentMethodService = paymentMethodService;

  final PaymentMethodService _paymentMethodService;

  Future<List<PaymentMethod>> loadMethods() {
    return _paymentMethodService.fetchPaymentMethods();
  }

  Future<List<PaymentMethod>> addMethod(
    List<PaymentMethod> current, {
    required PaymentMethodType type,
    String? lastFour,
    String? expiry,
    String? holderName,
  }) async {
    final newMethod = await _paymentMethodService.addPaymentMethod(
      type: type,
      lastFour: lastFour,
      expiry: expiry,
      holderName: holderName,
    );

    return [...current, newMethod];
  }

  Future<List<PaymentMethod>> removeMethod(
    List<PaymentMethod> current,
    String id,
  ) async {
    final exists = current.any((m) => m.id == id);
    if (!exists) return current;

    await _paymentMethodService.removePaymentMethod(id);

    return current.where((m) => m.id != id).toList();
  }

  Future<List<PaymentMethod>> setDefault(
    List<PaymentMethod> current,
    String id,
  ) async {
    await _paymentMethodService.setDefaultPaymentMethod(id);

    return current.map((m) => m.copyWith(isDefault: m.id == id)).toList();
  }
}
