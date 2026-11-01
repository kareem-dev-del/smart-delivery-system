class Subcategory {
  const Subcategory({
    required this.id,
    required this.name,
    required this.categoryId,
    this.imageUrl = '',
  });

  final String id;
  final String name;
  final String categoryId;
  final String imageUrl;

  factory Subcategory.fromJson(Map<String, dynamic> json) {
    return Subcategory(
      id: _readString(json, const ['id', '_id', 'slug']),
      name: _readString(json, const ['name', 'title']),
      categoryId: _readString(json, const ['categoryId', 'category_id', 'category']),
      imageUrl: _readString(json, const ['imageUrl', 'image_url'], fallback: ''),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'categoryId': categoryId,
        'imageUrl': imageUrl,
      };

  static String _readString(Map<String, dynamic> json, List<String> keys, {String fallback = ''}) {
    for (final key in keys) {
      if (json.containsKey(key)) return '${json[key]}';
    }
    return fallback;
  }
}