import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shopease_mobile/controllers/track_order_controller.dart';

import 'track_order_state.dart';

export 'track_order_state.dart';

class TrackOrderCubit extends Cubit<TrackOrderState> {
  TrackOrderCubit({required this.trackOrderController})
      : super(const TrackOrderState(isLoading: true));

  final TrackOrderController trackOrderController;
  bool _isLoadingTracking = false;

  Future<void> loadTracking(String orderId, {bool silent = false}) async {
    if (_isLoadingTracking) return;
    _isLoadingTracking = true;
    if (!silent) emit(state.copyWith(isLoading: true, clearError: true));
    try {
      final tracking = await trackOrderController.fetchTracking(orderId);
      emit(state.copyWith(tracking: tracking, isLoading: false, clearError: true));
    } catch (e) {
      emit(state.copyWith(
        isLoading: false,
        error: e.toString().replaceFirst('Exception: ', ''),
      ));
    } finally {
      _isLoadingTracking = false;
    }
  }
}
