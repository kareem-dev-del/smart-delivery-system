enum PaymentMethodType { visa, mastercard, amex, paypal, cashOnDelivery }

class PaymentMethod {
  const PaymentMethod({
    required this.id,
    required this.type,
    this.lastFour,
    this.expiry,
    this.holderName,
    this.isDefault = false,
  });

  final String id;
  final PaymentMethodType type;
  final String? lastFour;
  final String? expiry;
  final String? holderName;
  final bool isDefault;

  bool get isCard =>
      type == PaymentMethodType.visa ||
      type == PaymentMethodType.mastercard ||
      type == PaymentMethodType.amex;

  String get displayName => switch (type) {
        PaymentMethodType.visa => 'Visa',
        PaymentMethodType.mastercard => 'Mastercard',
        PaymentMethodType.amex => 'Amex',
        PaymentMethodType.paypal => 'PayPal',
        PaymentMethodType.cashOnDelivery => 'Cash on Delivery',
      };

  PaymentMethod copyWith({bool? isDefault}) => PaymentMethod(
        id: id,
        type: type,
        lastFour: lastFour,
        expiry: expiry,
        holderName: holderName,
        isDefault: isDefault ?? this.isDefault,
      );

  factory PaymentMethod.fromJson(Map<String, dynamic> json) {
    final typeStr = '${json['type'] ?? 'visa'}';
    final type = switch (typeStr.toLowerCase()) {
      'mastercard' => PaymentMethodType.mastercard,
      'amex' => PaymentMethodType.amex,
      'paypal' => PaymentMethodType.paypal,
      'cashondelivery' || 'cash_on_delivery' =>
        PaymentMethodType.cashOnDelivery,
      _ => PaymentMethodType.visa,
    };
    return PaymentMethod(
      id: '${json['id'] ?? ''}',
      type: type,
      lastFour: json['lastFour'] as String?,
      expiry: json['expiry'] as String?,
      holderName: json['holderName'] as String?,
      isDefault: json['isDefault'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'type': type.name,
        'lastFour': lastFour,
        'expiry': expiry,
        'holderName': holderName,
        'isDefault': isDefault,
      };
}
