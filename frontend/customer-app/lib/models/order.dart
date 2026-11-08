import 'package:shopease_mobile/models/payment_method.dart';
import 'package:shopease_mobile/models/product.dart';

enum OrderStatus {
  pending,
  awaitingLocker,
  assigned,
  readyForPickup,
  collected,
  expired,
  cancelled,
  returned,
}

extension OrderStatusLabel on OrderStatus {
  String get label => switch (this) {
        OrderStatus.pending => 'Pending',
        OrderStatus.awaitingLocker => 'Awaiting locker',
        OrderStatus.assigned => 'Locker assigned',
        OrderStatus.readyForPickup => 'Ready for pickup',
        OrderStatus.collected => 'Collected',
        OrderStatus.expired => 'Expired',
        OrderStatus.cancelled => 'Cancelled',
        OrderStatus.returned => 'Returned',
      };
}

class OrderItem {
  const OrderItem({
    required this.productId,
    required this.name,
    required this.imageUrl,
    required this.price,
    required this.quantity,
  });

  final String productId;
  final String name;
  final String imageUrl;
  final double price;
  final int quantity;

  double get subtotal => price * quantity;

  Product toProduct() => Product(
        id: productId,
        name: name,
        price: price,
        description: '',
        category: '',
        rating: 0,
        reviewCount: 0,
        imageUrl: imageUrl,
        inStock: true,
      );

  factory OrderItem.fromJson(Map<String, dynamic> json) => OrderItem(
        productId: '${json['product'] ?? json['product_id'] ?? json['productId'] ?? ''}',
        name: '${json['product_name'] ?? json['name'] ?? ''}',
        imageUrl: '${json['image_url'] ?? json['imageUrl'] ?? ''}',
        price: double.tryParse('${json['unit_price'] ?? json['price'] ?? 0}') ?? 0,
        quantity: int.tryParse('${json['quantity'] ?? 1}') ?? 1,
      );

  Map<String, dynamic> toJson() => {
        'productId': productId,
        'name': name,
        'imageUrl': imageUrl,
        'price': price,
        'quantity': quantity,
      };
}

class Order {
  const Order({
    required this.id,
    required this.date,
    required this.total,
    required this.status,
    required this.items,
    this.lockerName,
    this.estimatedDelivery,
    this.deliveredDate,
    this.paymentMethod,
  });

  final String id;
  final String date;
  final double total;
  final OrderStatus status;
  final List<OrderItem> items;
  final String? lockerName;
  final String? estimatedDelivery;
  final String? deliveredDate;
  final PaymentMethod? paymentMethod;

  int get itemCount => items.fold(0, (sum, item) => sum + item.quantity);

  bool get isCancellable =>
      status == OrderStatus.awaitingLocker || status == OrderStatus.assigned;

  String get statusLabel => status.label;

  factory Order.fromJson(Map<String, dynamic> json) {
    final rawItems = json['items'];
    final items = rawItems is List
        ? rawItems
            .whereType<Map<String, dynamic>>()
            .map(OrderItem.fromJson)
            .toList()
        : <OrderItem>[];
    final rawLocker = json['locker'];
    final rawPaymentMethod = json['paymentMethod'] ?? json['payment_method'];

    return Order(
      id: '${json['public_id'] ?? json['id'] ?? json['_id'] ?? ''}',
      date: '${json['created_at'] ?? json['date'] ?? ''}',
      total: _toDouble(json['total_amount'] ?? json['total']),
      status: _parseStatus('${json['status'] ?? 'pending'}'),
      items: items,
      lockerName: rawLocker is Map<String, dynamic>
          ? rawLocker['name'] as String?
          : null,
      estimatedDelivery: (json['delivery_deadline'] ??
          json['estimatedDelivery'] ??
          json['estimated_delivery']) as String?,
      deliveredDate: (json['collected_at'] ??
          json['deliveredDate'] ??
          json['delivered_date']) as String?,
      paymentMethod: rawPaymentMethod is Map<String, dynamic>
          ? PaymentMethod.fromJson(rawPaymentMethod)
          : null,
    );
  }

  Map<String, dynamic> toJson() => {
        'public_id': id,
        'created_at': date,
        'total_amount': total,
        'status': _statusToApi(status),
        'locker': lockerName == null ? null : {'name': lockerName},
        'items': items.map((item) => item.toJson()).toList(),
      };

  Order copyWith({OrderStatus? status}) => Order(
        id: id,
        date: date,
        total: total,
        status: status ?? this.status,
        items: items,
        lockerName: lockerName,
        estimatedDelivery: estimatedDelivery,
        deliveredDate: deliveredDate,
        paymentMethod: paymentMethod,
      );

  static OrderStatus _parseStatus(String value) => switch (value.toLowerCase()) {
        'pending' => OrderStatus.pending,
        'awaiting_locker' => OrderStatus.awaitingLocker,
        'assigned' => OrderStatus.assigned,
        'ready_for_pickup' => OrderStatus.readyForPickup,
        'collected' => OrderStatus.collected,
        'expired' => OrderStatus.expired,
        'cancelled' => OrderStatus.cancelled,
        'returned' => OrderStatus.returned,
        _ => OrderStatus.pending,
      };

  static String _statusToApi(OrderStatus status) => switch (status) {
        OrderStatus.pending => 'pending',
        OrderStatus.awaitingLocker => 'awaiting_locker',
        OrderStatus.assigned => 'assigned',
        OrderStatus.readyForPickup => 'ready_for_pickup',
        OrderStatus.collected => 'collected',
        OrderStatus.expired => 'expired',
        OrderStatus.cancelled => 'cancelled',
        OrderStatus.returned => 'returned',
      };

  static double _toDouble(dynamic value) {
    if (value is num) return value.toDouble();
    return double.tryParse('$value') ?? 0;
  }

}
