// Tracking data is kept separate from the order summary so the tracking page
// only requests the delivery status, station assignment, and timeline.
class TrackingStep {
  const TrackingStep({
    required this.title,
    this.description,
    this.timestamp,
    required this.isCompleted,
    required this.isCurrent,
  });

  final String title;
  final String? description;
  final String? timestamp;
  final bool isCompleted;
  final bool isCurrent;

  factory TrackingStep.fromJson(Map<String, dynamic> json) {
    return TrackingStep(
      title: '${json['title'] ?? ''}',
      description: json['description'] as String?,
      timestamp: json['timestamp'] as String?,
      isCompleted: json['isCompleted'] as bool? ?? false,
      isCurrent: json['isCurrent'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toJson() => {
    'title': title,
    'description': description,
    'timestamp': timestamp,
    'isCompleted': isCompleted,
    'isCurrent': isCurrent,
  };
}

class OrderTracking {
  const OrderTracking({
    required this.orderId,
    required this.status,
    this.trackingNumber,
    this.courier,
    this.estimatedDelivery,
    this.currentLocation,
    this.lockerName,
    this.lockerAddress,
    this.lockerCode,
    this.drawerNumber,
    required this.steps,
  });

  final String orderId;
  final String status;
  final String? trackingNumber;
  final String? courier;
  final String? estimatedDelivery;
  final String? currentLocation;
  final String? lockerName;
  final String? lockerAddress;
  final String? lockerCode;
  final int? drawerNumber;
  final List<TrackingStep> steps;

  factory OrderTracking.fromJson(Map<String, dynamic> json) {
    final rawSteps = json['steps'] ?? json['timeline'];
    final steps =
        rawSteps is List
            ? rawSteps
                .map((e) => TrackingStep.fromJson(e as Map<String, dynamic>))
                .toList()
            : <TrackingStep>[];

    return OrderTracking(
      orderId: '${json['orderId'] ?? json['order_id'] ?? ''}',
      status: '${json['status'] ?? 'pending'}',
      trackingNumber:
          (json['trackingNumber'] ?? json['tracking_number']) as String?,
      courier: json['courier'] as String?,
      estimatedDelivery:
          (json['estimatedDelivery'] ?? json['estimated_delivery']) as String?,
      currentLocation:
          (json['currentLocation'] ?? json['current_location']) as String?,
      lockerName: json['locker_name'] as String?,
      lockerAddress: json['locker_address'] as String?,
      lockerCode: json['locker_code'] as String?,
      drawerNumber: _toInt(json['drawer_number']),
      steps: steps,
    );
  }

  Map<String, dynamic> toJson() => {
    'orderId': orderId,
    'status': status,
    'trackingNumber': trackingNumber,
    'courier': courier,
    'estimatedDelivery': estimatedDelivery,
    'currentLocation': currentLocation,
    'locker_name': lockerName,
    'locker_address': lockerAddress,
    'locker_code': lockerCode,
    'drawer_number': drawerNumber,
    'steps': steps.map((s) => s.toJson()).toList(),
  };
}

int? _toInt(dynamic value) => value is int ? value : int.tryParse('$value');
