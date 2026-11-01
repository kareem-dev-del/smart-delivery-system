import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shopease_mobile/controllers/track_order_controller.dart';

import 'track_order_state.dart';

export 'track_order_state.dart';

class TrackOrderCubit extends Cubit<TrackOrderState> {
  TrackOrderCubit({required this.trackOrderController})
      : super(const TrackOrderState(isLoading: true));

  final TrackOrderController trackOrderController;

  Future<void> loadTracking(String orderId) async {
    emit(state.copyWith(isLoading: true, clearError: true));
    try {
      final tracking = await trackOrderController.fetchTracking(orderId);
      emit(state.copyWith(tracking: tracking, isLoading: false));
    } catch (e) {
      emit(state.copyWith(
        isLoading: false,
        error: e.toString().replaceFirst('Exception: ', ''),
      ));
    }
  }
}
