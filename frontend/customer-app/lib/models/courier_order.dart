class CourierOrderItem {
  const CourierOrderItem({
    required this.name,
    required this.size,
    required this.quantity,
  });

  final String name;
  final String size;
  final int quantity;

  String get sizeLabel => switch (size) {
    'small' => 'Small',
    'medium' => 'Medium',
    'large' => 'Large',
    '' => 'Not specified',
    _ => size,
  };

  factory CourierOrderItem.fromJson(Map<String, dynamic> json) {
    return CourierOrderItem(
      name: (json['product_name'] ?? json['name'] ?? 'Product').toString(),
      size: (json['product_size'] ?? json['size'] ?? '').toString(),
      quantity: int.tryParse('${json['quantity'] ?? 0}') ?? 0,
    );
  }
}

class CourierOrder {
  const CourierOrder({
    required this.publicId,
    required this.status,
    required this.lockerName,
    required this.lockerCode,
    required this.lockerAddress,
    required this.lockerLatitude,
    required this.lockerLongitude,
    required this.drawerNumber,
    required this.items,
  });

  final String publicId;
  final String status;
  final String? lockerName;
  final String? lockerCode;
  final String? lockerAddress;
  final double? lockerLatitude;
  final double? lockerLongitude;
  final int? drawerNumber;
  final List<CourierOrderItem> items;

  factory CourierOrder.fromJson(Map<String, dynamic> json) {
    final rawItems = json['items'];
    final locker = json['locker_station'] ?? json['locker'];
    return CourierOrder(
      publicId: (json['public_id'] ?? '').toString(),
      status: (json['status'] ?? 'unknown').toString(),
      lockerName: _readNullableString(
        json['locker_name'] ?? (locker is Map ? locker['name'] : null),
      ),
      lockerCode: _readNullableString(
        json['locker_code'] ?? (locker is Map ? locker['code'] : null),
      ),
      lockerAddress: _readNullableString(
        json['locker_address'] ?? (locker is Map ? locker['address'] : null),
      ),
      lockerLatitude: _readNullableDouble(
        json['locker_latitude'] ?? (locker is Map ? locker['latitude'] : null),
      ),
      lockerLongitude: _readNullableDouble(
        json['locker_longitude'] ??
            (locker is Map ? locker['longitude'] : null),
      ),
      drawerNumber: int.tryParse(
        '${json['drawer_number'] ?? json['assigned_drawer_number'] ?? ''}',
      ),
      items:
          rawItems is List
              ? rawItems
                  .whereType<Map>()
                  .map(
                    (item) => CourierOrderItem.fromJson(
                      Map<String, dynamic>.from(item),
                    ),
                  )
                  .toList(growable: false)
              : const [],
    );
  }

  static String? _readNullableString(dynamic value) {
    if (value == null || '$value'.trim().isEmpty) return null;
    return '$value';
  }

  static double? _readNullableDouble(dynamic value) {
    if (value == null) return null;
    return double.tryParse('$value');
  }

  String get shortReference =>
      publicId.length > 8
          ? publicId.substring(0, 8).toUpperCase()
          : publicId.toUpperCase();
}
