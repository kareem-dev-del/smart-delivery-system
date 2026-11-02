import 'package:shopease_mobile/core/config/app_config.dart';
import 'package:shopease_mobile/core/network/api_client.dart';
import 'package:shopease_mobile/core/network/api_error.dart';
import 'package:shopease_mobile/models/courier_order.dart';

class CourierService {
  CourierService({required ApiClient client}) : _client = client;

  final ApiClient _client;

  Future<List<CourierOrder>> getAssignments() async {
    return _readOrders(
      await _client.get<dynamic>(AppConfig.courierAssignmentsPath),
    );
  }

  Future<List<CourierOrder>> getReturns() async {
    return _readOrders(
      await _client.get<dynamic>(AppConfig.courierReturnsPath),
    );
  }

  Future<bool> getIsOnShift() async {
    final response = await _client.get<Map<String, dynamic>>(
      AppConfig.courierShiftPath,
    );
    final value = response['is_on_shift'];
    if (value is! bool) {
      throw const ApiException(
        message: 'The server returned an invalid shift status.',
      );
    }
    return value;
  }

  Future<bool> setShift(bool isOnShift) async {
    final response = await _client.patch<Map<String, dynamic>>(
      AppConfig.courierShiftPath,
      body: {'is_on_shift': isOnShift},
    );
    final value = response['is_on_shift'];
    if (value is! bool) {
      throw const ApiException(
        message: 'The server returned an invalid shift status.',
      );
    }
    return value;
  }

  List<CourierOrder> _readOrders(dynamic response) {
    final rawList =
        response is List
            ? response
            : response is Map<String, dynamic> && response['results'] is List
            ? response['results'] as List
            : null;
    if (rawList == null) {
      throw const ApiException(
        message: 'The server returned an unexpected orders response.',
      );
    }
    return rawList
        .whereType<Map>()
        .map((item) => CourierOrder.fromJson(Map<String, dynamic>.from(item)))
        .where((order) => order.publicId.isNotEmpty)
        .toList(growable: false);
  }
}
