import 'package:shopease_mobile/core/network/api_client.dart';
import 'package:shopease_mobile/models/return_request.dart';

class ReturnsService {
  ReturnsService({required ApiClient client}) : _client = client;

  final ApiClient _client;

  // GET /returns — بيرجع array (خام أو تحت 'returns'/'data')، بنتعامل مع
  // الحالتين زي OrdersService.fetchOrders بالظبط
  Future<List<ReturnRequest>> fetchReturns() {
    return _client.get<List<ReturnRequest>>(
      '/returns',
      parser: (data) {
        final raw = data is Map<String, dynamic>
            ? (data['returns'] ?? data['data'] ?? const [])
            : data;
        final list = raw as List<dynamic>;
        return list
            .map((e) => ReturnRequest.fromJson(e as Map<String, dynamic>))
            .toList();
      },
    );
  }

  // POST /returns — بيبعت orderId (وreason اختياري) وبيرجع الـReturnRequest
  // اللي اتعمل عشان نحطه فوق الليستة على طول من غير ما نعمل reload كامل
  Future<ReturnRequest> submitReturn({
    required String orderId,
    String? reason,
  }) {
    return _client.post<ReturnRequest>(
      '/returns',
      body: {
        'orderId': orderId,
        if (reason != null && reason.trim().isNotEmpty) 'reason': reason,
      },
      parser: (data) {
        final returnJson = data is Map<String, dynamic>
            ? (data['return'] ?? data['data'] ?? data)
            : data;
        return ReturnRequest.fromJson(returnJson as Map<String, dynamic>);
      },
    );
  }
}
