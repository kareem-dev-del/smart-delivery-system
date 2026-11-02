import 'package:shopease_mobile/models/shipping_address.dart';
import 'package:shopease_mobile/repositories/shipping_address_repository.dart';

class ShippingAddressController {
  ShippingAddressController({required ShippingAddressRepository shippingAddressRepository})
      : _shippingAddressRepository = shippingAddressRepository;

  final ShippingAddressRepository _shippingAddressRepository;

  Future<ShippingAddress?> fetchAddress() => _shippingAddressRepository.fetchAddress();

  Future<ShippingAddress> saveAddress(ShippingAddress address) =>
      _shippingAddressRepository.saveAddress(address);
}