class LockerStation {
  const LockerStation({
    required this.id,
    required this.name,
    required this.code,
    required this.address,
    required this.availableDrawersCount,
    this.distanceKm,
  });

  final int id;
  final String name;
  final String code;
  final String address;
  final int availableDrawersCount;
  final double? distanceKm;

  factory LockerStation.fromJson(Map<String, dynamic> json) => LockerStation(
        id: (json['id'] as num).toInt(),
        name: '${json['name'] ?? ''}',
        code: '${json['code'] ?? ''}',
        address: '${json['address'] ?? ''}',
        availableDrawersCount:
            (json['available_drawers_count'] as num?)?.toInt() ?? 0,
        distanceKm: (json['distance_km'] as num?)?.toDouble(),
      );
}

class LockerSearchResult {
  const LockerSearchResult({
    required this.stations,
    required this.usedDeviceLocation,
  });

  final List<LockerStation> stations;
  final bool usedDeviceLocation;
}
