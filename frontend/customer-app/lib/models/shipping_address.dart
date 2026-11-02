class ShippingAddress {
  const ShippingAddress({
    required this.name,
    required this.street,
    required this.city,
    required this.state,
    required this.zip,
    this.country = 'United States',
  });

  final String name;
  final String street;
  final String city;
  final String state;
  final String zip;
  final String country;

  String get fullAddress => '$street, $city, $state $zip, $country';

  bool get isEmpty =>
      name.isEmpty &&
      street.isEmpty &&
      city.isEmpty &&
      state.isEmpty &&
      zip.isEmpty;

  factory ShippingAddress.fromJson(Map<String, dynamic> json) {
    return ShippingAddress(
      name: '${json['name'] ?? json['fullName'] ?? ''}',
      street: '${json['street'] ?? json['address'] ?? ''}',
      city: '${json['city'] ?? ''}',
      state: '${json['state'] ?? ''}',
      zip: '${json['zip'] ?? json['zipCode'] ?? ''}',
      country: '${json['country'] ?? 'United States'}',
    );
  }

  /// Parses a flat "123 Main St, San Francisco, CA 94102" style string.
  factory ShippingAddress.fromFlatString(String flat) {
    final parts = flat.split(',').map((s) => s.trim()).toList();
    return ShippingAddress(
      name: '',
      street: parts.isNotEmpty ? parts[0] : flat,
      city: parts.length > 1 ? parts[1] : '',
      state: parts.length > 2 ? parts[2].replaceAll(RegExp(r'\d'), '').trim() : '',
      zip: parts.length > 2
          ? (RegExp(r'\d+').firstMatch(parts[2])?.group(0) ?? '')
          : '',
      country: parts.length > 3 ? parts[3] : 'United States',
    );
  }

  Map<String, dynamic> toJson() => {
        'name': name,
        'street': street,
        'city': city,
        'state': state,
        'zip': zip,
        'country': country,
      };
}
