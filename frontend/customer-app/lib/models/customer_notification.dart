class CustomerNotification {
  const CustomerNotification({
    required this.id,
    required this.title,
    required this.message,
    required this.notificationType,
    required this.isRead,
    this.orderPublicId,
    this.createdAt,
  });

  final int id;
  final String title;
  final String message;
  final String notificationType;
  final bool isRead;
  final String? orderPublicId;
  final String? createdAt;

  CustomerNotification copyWith({bool? isRead}) => CustomerNotification(
    id: id,
    title: title,
    message: message,
    notificationType: notificationType,
    isRead: isRead ?? this.isRead,
    orderPublicId: orderPublicId,
    createdAt: createdAt,
  );

  factory CustomerNotification.fromJson(Map<String, dynamic> json) =>
      CustomerNotification(
        id: int.tryParse('${json['id']}') ?? 0,
        title: '${json['title'] ?? 'Order update'}',
        message: '${json['message'] ?? ''}',
        notificationType: '${json['notification_type'] ?? ''}',
        isRead: json['is_read'] as bool? ?? false,
        orderPublicId: json['order_public_id'] as String?,
        createdAt: json['created_at'] as String?,
      );
}
