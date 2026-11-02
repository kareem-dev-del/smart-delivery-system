class ProductReview {
  const ProductReview({
    required this.id,
    required this.productId,
    required this.userId,
    required this.name,
    required this.rating,
    required this.date,
    required this.text,
    required this.verified,
    this.helpfulCount = 0,
  });

  final String id;
  final String productId;
  final String userId;
  final String name;
  final int rating;
  final String date;
  final String text;
  final bool verified;
  final int helpfulCount;

  factory ProductReview.fromJson(Map<String, dynamic> json) {
    return ProductReview(
      id: _readString(json, const ['id', '_id']),
      productId: _readString(json, const ['productId', 'product_id']),
      userId: _readString(json, const ['userId', 'user_id']),
      name: _readString(json, const ['name', 'userName', 'reviewerName'], fallback: 'Anonymous'),
      rating: _toInt(json['rating']),
      date: _readString(json, const ['date', 'createdAt', 'created_at']),
      text: _readString(json, const ['text', 'comment', 'body']),
      verified: _toBool(_readOptional(json, const ['verified', 'isVerifiedPurchase'])),
      helpfulCount: _toInt(_readOptional(json, const ['helpfulCount', 'helpful_count'])),
    );
  }

  Map<String, dynamic> toJson() => {
        'productId': productId,
        'rating': rating,
        'text': text,
      };

  static int _toInt(dynamic value) {
    if (value is num) return value.toInt();
    return int.tryParse('$value') ?? 0;
  }

  static bool _toBool(dynamic value) {
    if (value is bool) return value;
    return '$value'.toLowerCase() == 'true';
  }

  static String _readString(Map<String, dynamic> json, List<String> keys, {String fallback = ''}) {
    final value = _readOptional(json, keys);
    return value == null ? fallback : '$value';
  }

  static dynamic _readOptional(Map<String, dynamic> json, List<String> keys) {
    for (final key in keys) {
      if (json.containsKey(key)) return json[key];
    }
    return null;
  }
}
