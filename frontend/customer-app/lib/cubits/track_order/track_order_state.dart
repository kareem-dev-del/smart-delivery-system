import 'package:shopease_mobile/models/order_tracking.dart';

class TrackOrderState {
  const TrackOrderState({
    this.tracking,
    this.isLoading = false,
    this.error,
  });

  final OrderTracking? tracking;
  final bool isLoading;
  final String? error;

  TrackOrderState copyWith({
    OrderTracking? tracking,
    bool? isLoading,
    String? error,
    bool clearError = false,
  }) {
    return TrackOrderState(
      tracking: tracking ?? this.tracking,
      isLoading: isLoading ?? this.isLoading,
      error: clearError ? null : (error ?? this.error),
    );
  }
}
