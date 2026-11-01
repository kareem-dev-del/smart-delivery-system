import 'package:shopease_mobile/models/shipping_address.dart';
import 'package:shopease_mobile/services/shipping_address_service.dart';

class ShippingAddressRepository {
  ShippingAddressRepository({required ShippingAddressService shippingAddressService})
      : _shippingAddressService = shippingAddressService;

  final ShippingAddressService _shippingAddressService;

  Future<ShippingAddress?> fetchAddress() => _shippingAddressService.fetchAddress();

  Future<ShippingAddress> saveAddress(ShippingAddress address) =>
      _shippingAddressService.saveAddress(address);
}