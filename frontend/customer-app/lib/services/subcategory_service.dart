import 'package:shopease_mobile/core/network/api_client.dart';
import 'package:shopease_mobile/core/network/api_error.dart';
import 'package:shopease_mobile/models/subcategory.dart';

class SubcategoryService {
  SubcategoryService({required ApiClient client}) : _client = client;

  final ApiClient _client;

  Future<List<Subcategory>> fetchSubcategories(String categoryId) async {
    final response = await _client.get<dynamic>(
      '/categories/${Uri.encodeComponent(categoryId)}/subcategories',
    );
    return _readList(response, wrapperKeys: const ['subcategories', 'data', 'items']);
  }

  List<Subcategory> _readList(dynamic response, {required List<String> wrapperKeys}) {
    final rawList = switch (response) {
      final List<dynamic> value => value,
      final Map<String, dynamic> value => _listFromWrappedResponse(value, wrapperKeys),
      _ => throw const ApiException(message: 'The server returned an unexpected list response.'),
    };
    return rawList.map((entry) => Subcategory.fromJson(_ensureObject(entry))).toList(growable: false);
  }

  List<dynamic> _listFromWrappedResponse(Map<String, dynamic> response, List<String> wrapperKeys) {
    for (final key in wrapperKeys) {
      final value = response[key];
      if (value is List<dynamic>) return value;
    }
    throw const ApiException(message: 'The server returned an unexpected list response.');
  }

  Map<String, dynamic> _ensureObject(dynamic entry) {
    if (entry is Map<String, dynamic>) return entry;
    throw const ApiException(message: 'The server returned an unexpected item response.');
  }
}