class Category {
  const Category({
    required this.id,
    required this.name,
    required this.icon,
    required this.colorHex,
    required this.productCount,
    this.imageUrl = '',
    this.subcategories = const [],
  });

  final String id;
  final String name;
  final String icon;
  final String colorHex;
  final int productCount;
  final String imageUrl;
  final List<String> subcategories;

  factory Category.fromJson(Map<String, dynamic> json) {
    final subcatsRaw = json['subcategories'] ?? json['sub_categories'];
    final subcats = subcatsRaw is List
        ? subcatsRaw.map((e) => '$e').toList()
        : <String>[];

    return Category(
      id: _readString(json, const <String>['id', '_id', 'slug']),
      name: _readString(json, const <String>['name', 'title']),
      icon: _readString(json, const <String>['icon'], fallback: 'category'),
      colorHex: _readString(
        json,
        const <String>['colorHex', 'color_hex'],
        fallback: '#6C63FF',
      ),
      productCount: _toInt(
        _readOptional(json, const <String>['productCount', 'product_count']),
      ),
      imageUrl: _readString(
        json,
        const <String>['imageUrl', 'image_url'],
        fallback: '',
      ),
      subcategories: subcats,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'icon': icon,
      'colorHex': colorHex,
      'productCount': productCount,
      'imageUrl': imageUrl,
      'subcategories': subcategories,
    };
  }

  static int _toInt(dynamic value) {
    if (value is num) return value.toInt();
    return int.tryParse('$value') ?? 0;
  }

  static String _readString(
    Map<String, dynamic> json,
    List<String> keys, {
    String fallback = '',
  }) {
    final value = _readOptional(json, keys);
    return value == null ? fallback : '$value';
  }

  static dynamic _readOptional(Map<String, dynamic> json, List<String> keys) {
    for (final key in keys) {
      if (json.containsKey(key)) {
        return json[key];
      }
    }
    return null;
  }
}
