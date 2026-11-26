class LockerStation {
  const LockerStation({
    required this.id,
    required this.name,
    required this.code,
    required this.address,
    required this.availableDrawersCount,
    required this.recommendationScore,
    required this.recommendationReasons,
    required this.deviceReady,
    this.distanceKm,
  });

  final int id;
  final String name;
  final String code;
  final String address;
  final int availableDrawersCount;
  final int recommendationScore;
  final List<String> recommendationReasons;
  final bool deviceReady;
  final double? distanceKm;

  factory LockerStation.fromJson(Map<String, dynamic> json) => LockerStation(
        id: (json['id'] as num).toInt(),
        name: '${json['name'] ?? ''}',
        code: '${json['code'] ?? ''}',
        address: '${json['address'] ?? ''}',
        availableDrawersCount:
            (json['available_drawers_count'] as num?)?.toInt() ?? 0,
        recommendationScore:
            (json['recommendation_score'] as num?)?.toInt() ?? 0,
        recommendationReasons: (json['recommendation_reasons'] as List<dynamic>?)
                ?.whereType<String>()
                .toList(growable: false) ??
            const [],
        deviceReady: json['device_ready'] == true,
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
