import 'package:geolocator/geolocator.dart';
import 'package:shopease_mobile/core/network/api_client.dart';
import 'package:shopease_mobile/core/network/api_error.dart';
import 'package:shopease_mobile/models/locker_station.dart';

class LockerStationService {
  LockerStationService({required ApiClient client}) : _client = client;

  final ApiClient _client;

  Future<LockerSearchResult> findEligibleStations({
    required List<String> productIds,
  }) async {
    final position = await _readDevicePosition();
    final response = await _client.get<dynamic>(
      '/api/lockers/nearby/',
      queryParameters: {
        'product_ids': productIds.join(','),
        if (position != null) 'latitude': position.latitude.toString(),
        if (position != null) 'longitude': position.longitude.toString(),
      },
    );

    if (response is! List<dynamic>) {
      throw const ApiException(
        message: 'The server returned an unexpected locker list.',
      );
    }
    final stations = response
        .whereType<Map<String, dynamic>>()
        .map(LockerStation.fromJson)
        .toList(growable: false);
    return LockerSearchResult(
      stations: stations,
      usedDeviceLocation: position != null,
    );
  }

  Future<Position?> _readDevicePosition() async {
    try {
      if (!await Geolocator.isLocationServiceEnabled()) return null;

      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        return null;
      }

      return Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.low,
          timeLimit: Duration(seconds: 10),
        ),
      );
    } catch (_) {
      return null;
    }
  }
}
