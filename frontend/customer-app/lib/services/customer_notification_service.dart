import 'package:shopease_mobile/core/network/api_client.dart';
import 'package:shopease_mobile/models/customer_notification.dart';

class CustomerNotificationService {
  CustomerNotificationService({required ApiClient client}) : _client = client;

  final ApiClient _client;

  Future<int> getUnreadCount() async {
    final response = await _client.get<dynamic>(
      '/api/notifications/?unread=true&page_size=1',
    );
    if (response is Map<String, dynamic>) {
      final count = response['count'];
      if (count is int) return count;
      final results = response['results'];
      if (results is List) return results.length;
    }
    if (response is List) return response.length;
    return 0;
  }

  Future<List<CustomerNotification>> getNotifications() async {
    final response = await _client.get<dynamic>('/api/notifications/');
    final rawList =
        response is List
            ? response
            : response is Map<String, dynamic> && response['results'] is List
            ? response['results'] as List
            : null;
    if (rawList == null) {
      throw const FormatException('Unexpected notifications response.');
    }
    return rawList
        .whereType<Map>()
        .map(
          (item) =>
              CustomerNotification.fromJson(Map<String, dynamic>.from(item)),
        )
        .where((notification) => notification.id > 0)
        .toList(growable: false);
  }

  Future<void> markRead(int id) async {
    await _client.post<Map<String, dynamic>>('/api/notifications/$id/read/');
  }

  Future<void> markAllRead() async {
    await _client.post<Map<String, dynamic>>('/api/notifications/read-all/');
  }
}
