import 'package:shopease_mobile/models/payment_method.dart';

class PaymentMethodsState {
  const PaymentMethodsState({
    this.methods = const [],
    this.isLoading = false,
    this.isMutating = false,
    this.error,
  });

  final List<PaymentMethod> methods;
  final bool isLoading;
  final bool isMutating;
  final String? error;

  List<PaymentMethod> get cards => methods.where((m) => m.isCard).toList();

  PaymentMethod? get defaultMethod {
    try {
      return methods.firstWhere((m) => m.isDefault);
    } catch (_) {
      return methods.isNotEmpty ? methods.first : null;
    }
  }

  PaymentMethodsState copyWith({
    List<PaymentMethod>? methods,
    bool? isLoading,
    bool? isMutating,
    String? error,
    bool clearError = false,
  }) {
    return PaymentMethodsState(
      methods: methods ?? this.methods,
      isLoading: isLoading ?? this.isLoading,
      isMutating: isMutating ?? this.isMutating,
      error: clearError ? null : (error ?? this.error),
    );
  }
}
