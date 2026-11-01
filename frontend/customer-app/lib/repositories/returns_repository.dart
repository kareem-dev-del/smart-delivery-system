import 'package:shopease_mobile/models/return_request.dart';
import 'package:shopease_mobile/services/returns_service.dart';

class ReturnsRepository {
  ReturnsRepository({required ReturnsService returnsService})
      : _returnsService = returnsService;

  final ReturnsService _returnsService;

  Future<List<ReturnRequest>> fetchReturns() => _returnsService.fetchReturns();

  Future<ReturnRequest> submitReturn({
    required String orderId,
    String? reason,
  }) =>
      _returnsService.submitReturn(orderId: orderId, reason: reason);
}
