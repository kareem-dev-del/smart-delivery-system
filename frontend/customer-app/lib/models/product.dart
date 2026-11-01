class Product {
  const Product({
    required this.id,
    required this.name,
    required this.price,
    this.originalPrice,
    required this.description,
    required this.category,
    this.categoryId,
    this.subcategoryId,
    this.subcategoryName,
    required this.rating,
    required this.reviewCount,
    required this.imageUrl,
    this.images = const <String>[],
    this.badge,
    required this.inStock,
    this.brand,
    this.stockCount,
    this.soldCount,
    this.specs = const <String, String>{},
  });

  final String id;
  final String name;
  final double price;
  final double? originalPrice;
  final String description;
  final String category;
  final String? categoryId;
  final String? subcategoryId;
  final String? subcategoryName;
  final double rating;
  final int reviewCount;
  final String imageUrl;
  // صور إضافية للمنتج (gallery) — لو فاضية، الشاشات بترجع لـ imageUrl بس
  // عن طريق الـ getter galleryImages تحت.
  final List<String> images;
  final String? badge;
  final bool inStock;
  // اسم البراند/الماركة — اختياري، ممكن يكون مش موجود لكل المنتجات
  final String? brand;
  // العدد المتبقي في المخزون — لو null يبقى معندناش رقم دقيق، بس نعرف
  // إنه متاح أو لأ من inStock
  final int? stockCount;
  // عدد القطع اللي اتباعت من المنتج ده (لعرض "X sold")
  final int? soldCount;
  // مواصفات إضافية زي (الخامة، الوزن، بلد المنشأ...) كـ key/value
  final Map<String, String> specs;

  // بيرجّع كل الصور المتاحة للمنتج؛ لو مفيش صور إضافية بيرجّع الصورة
  // الرئيسية بس عشان أي مكان بيلف على الصور يفضل شغال زي ما هو
  List<String> get galleryImages =>
      images.isNotEmpty ? images : (imageUrl.isEmpty ? const [] : [imageUrl]);

  // نسبة الخصم محسوبة تلقائيًا من originalPrice و price، بدل ما تتكتب
  // يدويًا كـ badge نصي. بترجع null لو مفيش originalPrice أو مفيش خصم فعلي
  int? get discountPercent {
    final original = originalPrice;
    if (original == null || original <= price) return null;
    return (((original - price) / original) * 100).round();
  }

  // true لو المخزون منخفض (اتحدد هنا بـ 5 قطع فأقل) عشان نوري رسالة
  // "X left" بدل ما نسيبها للشاشات تحسب الرقم بنفسها في كل مكان
  bool get isLowStock =>
      inStock && stockCount != null && stockCount! > 0 && stockCount! <= 5;

  factory Product.fromJson(Map<String, dynamic> json) {
    final originalPrice = _readOptional(json, const <String>[
      'originalPrice',
      'original_price',
    ]);
    final stockValue = _readOptional(json, const <String>[
      'inStock',
      'in_stock',
      'stock',
    ]);

    return Product(
      id: _readString(json, const <String>['id', '_id']),
      name: _readString(json, const <String>['name', 'title']),
      price: _toDouble(json['price']),
      originalPrice: originalPrice == null ? null : _toDouble(originalPrice),
      description: _readString(json, const <String>['description']),
      category: _readCategory(json),
      categoryId: _readCategoryId(json),
      subcategoryId: _readSubcategoryId(json),
      subcategoryName: _readSubcategoryName(json),
      rating: _toDouble(json['rating']),
      reviewCount: _toInt(
        _readOptional(json, const <String>['reviewCount', 'review_count']),
      ),
      imageUrl: _readImageUrl(json),
      images: _readImages(json),
      badge: _readNullableString(json, const <String>['badge']),
      inStock: stockValue == null ? true : _toBool(stockValue),
      brand: _readNullableString(json, const <String>['brand']),
      stockCount: _readNullableInt(json, const <String>[
        'stockCount',
        'stock_count',
        'stock',
      ]),
      soldCount: _readNullableInt(json, const <String>[
        'soldCount',
        'sold_count',
      ]),
      specs: _readSpecs(json),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'price': price,
      'originalPrice': originalPrice,
      'description': description,
      'category': category,
      'categoryId': categoryId,
      'subcategoryId': subcategoryId,
      'subcategoryName': subcategoryName,
      'rating': rating,
      'reviewCount': reviewCount,
      'imageUrl': imageUrl,
      'images': images,
      'badge': badge,
      'inStock': inStock,
      'brand': brand,
      'stockCount': stockCount,
      'soldCount': soldCount,
      'specs': specs,
    };
  }

  static double _toDouble(dynamic value) {
    if (value is num) return value.toDouble();
    return double.tryParse('$value') ?? 0;
  }

  static int _toInt(dynamic value) {
    if (value is num) return value.toInt();
    return int.tryParse('$value') ?? 0;
  }

  static bool _toBool(dynamic value) {
    if (value is bool) return value;
    if (value is num) return value > 0;

    final text = '$value'.toLowerCase().trim();
    return text == 'true' || text == '1' || text == 'yes';
  }

  static String _readString(Map<String, dynamic> json, List<String> keys) {
    return _readNullableString(json, keys) ?? '';
  }

  static String? _readNullableString(
    Map<String, dynamic> json,
    List<String> keys,
  ) {
    final value = _readOptional(json, keys);
    return value == null ? null : '$value';
  }

  static dynamic _readOptional(Map<String, dynamic> json, List<String> keys) {
    for (final key in keys) {
      if (json.containsKey(key)) {
        return json[key];
      }
    }

    return null;
  }

  static String _readImageUrl(Map<String, dynamic> json) {
    final value = _readOptional(json, const <String>[
      'imageUrl',
      'image_url',
      'image',
      'thumbnail',
    ]);
    if (value != null) {
      return '$value';
    }

    final images = json['images'];
    if (images is List<dynamic> && images.isNotEmpty) {
      return '${images.first}';
    }

    return '';
  }

  static List<String> _readImages(Map<String, dynamic> json) {
    final value = json['images'];
    if (value is List<dynamic>) {
      return value.map((e) => '$e').where((e) => e.isNotEmpty).toList();
    }
    return const <String>[];
  }

  static int? _readNullableInt(Map<String, dynamic> json, List<String> keys) {
    final value = _readOptional(json, keys);
    return value == null ? null : _toInt(value);
  }

  static Map<String, String> _readSpecs(Map<String, dynamic> json) {
    final value = json['specs'];
    if (value is Map<String, dynamic>) {
      return value.map((key, v) => MapEntry(key, '$v'));
    }
    return const <String, String>{};
  }

  static String _readCategory(Map<String, dynamic> json) {
    final categoryName = json['category_name'];
    if (categoryName is String && categoryName.isNotEmpty) return categoryName;

    final value = _readOptional(json, const <String>['category', 'categoryId']);
    if (value is Map<String, dynamic>) {
      return _readString(value, const <String>['name', 'title']);
    }

    return value == null ? 'Uncategorized' : '$value';
  }

  bool matchesCategory(String value) =>
      category == value || categoryId == value;

  static String? _readCategoryId(Map<String, dynamic> json) {
    final value = _readOptional(json, const <String>[
      'categoryId',
      'category_id',
      'category',
    ]);
    if (value is Map<String, dynamic>) {
      final id = _readString(value, const <String>['id', '_id']);
      return id.isEmpty ? null : id;
    }
    return value == null ? null : '$value';
  }

  static String? _readSubcategoryId(Map<String, dynamic> json) {
    final value = _readOptional(json, const <String>[
      'subcategory',
      'subcategoryId',
      'subCategoryId',
    ]);
    if (value is Map<String, dynamic>) {
      final id = _readString(value, const <String>['id', '_id', 'slug']);
      return id.isEmpty ? null : id;
    }

    return value == null ? null : '$value';
  }

  static String? _readSubcategoryName(Map<String, dynamic> json) {
    final value = _readOptional(json, const <String>['subcategory']);
    if (value is Map<String, dynamic>) {
      final name = _readString(value, const <String>['name', 'title']);
      return name.isEmpty ? null : name;
    }

    return null;
  }
}
