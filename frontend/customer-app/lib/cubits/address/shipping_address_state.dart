import 'package:shopease_mobile/models/shipping_address.dart';

class ShippingAddressState {
  const ShippingAddressState({
    this.address,
    this.isLoading = false,
    this.isSaving = false,
    this.error,
  });

  final ShippingAddress? address;
  final bool isLoading;
  final bool isSaving;
  final String? error;

  ShippingAddressState copyWith({
    ShippingAddress? address,
    bool? isLoading,
    bool? isSaving,
    String? error,
    bool clearAddress = false,   // [جديد]
    bool clearError = false,
  }) {
    return ShippingAddressState(
      address: clearAddress ? null : (address ?? this.address),   // [جديد]
      isLoading: isLoading ?? this.isLoading,
      isSaving: isSaving ?? this.isSaving,
      error: clearError ? null : (error ?? this.error),
    );
  }
}