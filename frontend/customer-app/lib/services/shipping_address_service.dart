import 'package:shopease_mobile/core/network/api_client.dart';
import 'package:shopease_mobile/core/network/api_error.dart';
import 'package:shopease_mobile/models/shipping_address.dart';

class ShippingAddressService {
  ShippingAddressService({required ApiClient client}) : _client = client;

  final ApiClient _client;

  Future<ShippingAddress?> fetchAddress() async {
    try {
      final response = await _client.get<Map<String, dynamic>>('/users/me/shipping-address');
      final addressJson = response['address'] ?? response['data'] ?? response;
      if (addressJson is! Map<String, dynamic> || addressJson.isEmpty) return null;
      return ShippingAddress.fromJson(addressJson);
    } on ApiException catch (e) {
      if (e.isNotFound) return null; // المستخدم لسه ماحفظش عنوان
      rethrow;
    }
  }

  Future<ShippingAddress> saveAddress(ShippingAddress address) async {
    final response = await _client.put<Map<String, dynamic>>(
      '/users/me/shipping-address',
      body: address.toJson(),
    );
    final addressJson = response['address'] ?? response['data'] ?? response;
    if (addressJson is! Map<String, dynamic>) {
      throw const ApiException(message: 'The server returned an unexpected address response.');
    }
    return ShippingAddress.fromJson(addressJson);
  }
}