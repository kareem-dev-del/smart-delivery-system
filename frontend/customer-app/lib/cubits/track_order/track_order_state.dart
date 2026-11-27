import 'package:shopease_mobile/models/order_tracking.dart';

class TrackOrderState {
  const TrackOrderState({
    this.tracking,
    this.isLoading = false,
    this.error,
    this.pickupQrToken,
    this.pickupQrExpiresAt,
    this.isGeneratingPickupQr = false,
    this.pickupQrError,
  });

  final OrderTracking? tracking;
  final bool isLoading;
  final String? error;
  final String? pickupQrToken;
  final String? pickupQrExpiresAt;
  final bool isGeneratingPickupQr;
  final String? pickupQrError;

  TrackOrderState copyWith({
    OrderTracking? tracking,
    bool? isLoading,
    String? error,
    bool clearError = false,
    String? pickupQrToken,
    String? pickupQrExpiresAt,
    bool? isGeneratingPickupQr,
    String? pickupQrError,
    bool clearPickupQrError = false,
  }) {
    return TrackOrderState(
      tracking: tracking ?? this.tracking,
      isLoading: isLoading ?? this.isLoading,
      error: clearError ? null : (error ?? this.error),
      pickupQrToken: pickupQrToken ?? this.pickupQrToken,
      pickupQrExpiresAt: pickupQrExpiresAt ?? this.pickupQrExpiresAt,
      isGeneratingPickupQr: isGeneratingPickupQr ?? this.isGeneratingPickupQr,
      pickupQrError: clearPickupQrError ? null : (pickupQrError ?? this.pickupQrError),
    );
  }
}
