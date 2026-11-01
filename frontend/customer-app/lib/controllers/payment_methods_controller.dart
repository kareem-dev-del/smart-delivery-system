import 'package:shopease_mobile/models/payment_method.dart';
import 'package:shopease_mobile/repositories/payment_method_repository.dart';

class PaymentMethodsController {
  PaymentMethodsController({required PaymentMethodRepository paymentMethodRepository})
      : _paymentMethodRepository = paymentMethodRepository;

  final PaymentMethodRepository _paymentMethodRepository;

  Future<List<PaymentMethod>> loadMethods() => _paymentMethodRepository.loadMethods();

  Future<List<PaymentMethod>> addMethod(
    List<PaymentMethod> current, {
    required PaymentMethodType type,
    String? lastFour,
    String? expiry,
    String? holderName,
  }) =>
      _paymentMethodRepository.addMethod(
        current,
        type: type,
        lastFour: lastFour,
        expiry: expiry,
        holderName: holderName,
      );

  Future<List<PaymentMethod>> removeMethod(List<PaymentMethod> current, String id) =>
      _paymentMethodRepository.removeMethod(current, id);

  Future<List<PaymentMethod>> setDefault(List<PaymentMethod> current, String id) =>
      _paymentMethodRepository.setDefault(current, id);
}
