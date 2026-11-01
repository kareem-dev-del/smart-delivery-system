import 'dart:io';

import 'package:shopease_mobile/core/network/api_error.dart';
import 'package:shopease_mobile/models/app_user.dart';
import 'package:shopease_mobile/models/category.dart';
import 'package:shopease_mobile/models/product.dart';
import 'package:shopease_mobile/core/network/api_client.dart';
import 'package:shopease_mobile/services/app_data_service.dart';

typedef JsonFactory<T> = T Function(Map<String, dynamic> json);

class ApiDataService implements AppDataService {
  const ApiDataService({required ApiClient client}) : _client = client;

  final ApiClient _client;

  @override
  Future<List<Product>> fetchProducts({String? category, String? search}) async {
    final response = await _client.get(
      '/products',
      queryParameters: <String, String?>{
        'category': category,
        'search': search,
      },
    );

    return _readList(
      response,
      Product.fromJson,
      wrapperKeys: const <String>['products', 'data', 'items'],
    );
  }

  @override
  Future<Product?> fetchProductById(String id) async {
    try {
      final response = await _client.get('/products/${Uri.encodeComponent(id)}');
      return Product.fromJson(
        _readObject(
          response,
          wrapperKeys: const <String>['product', 'data', 'item'],
        ),
      );
    } on ApiException catch (error) {
      if (error.statusCode == HttpStatus.notFound) {
        return null;
      }
      rethrow;
    }
  }

  @override
  Future<List<Product>> fetchFeaturedProducts() async {
    try {
      final response = await _client.get('/products/featured');
      return _readList(
        response,
        Product.fromJson,
        wrapperKeys: const <String>['products', 'data', 'items'],
      );
    } on ApiException catch (error) {
      if (error.statusCode != HttpStatus.notFound) {
        rethrow;
      }

      final products = await fetchProducts();
      return products.where((product) => product.badge != null).take(6).toList();
    }
  }

  @override
  Future<List<Category>> fetchCategories() async {
    final response = await _client.get('/categories');
    return _readList(
      response,
      Category.fromJson,
      wrapperKeys: const <String>['categories', 'data', 'items'],
    );
  }

  @override
  Future<AppUser> loginUser(String email, String password) async {
    final response = await _client.post(
      '/auth/login',
      body: <String, dynamic>{'email': email, 'password': password},
    );

    return AppUser.fromJson(
      _readObject(response, wrapperKeys: const <String>['user', 'data']),
    );
  }

  @override
  Future<AppUser> registerUser(
    String name,
    String email,
    String password,
  ) async {
    final response = await _client.post(
      '/auth/register',
      body: <String, dynamic>{
        'name': name,
        'email': email,
        'password': password,
      },
    );

    return AppUser.fromJson(
      _readObject(response, wrapperKeys: const <String>['user', 'data']),
    );
  }

  List<T> _readList<T>(
    dynamic response,
    JsonFactory<T> fromJson, {
    required List<String> wrapperKeys,
  }) {
    final rawList = switch (response) {
      final List<dynamic> value => value,
      final Map<String, dynamic> value => _listFromWrappedResponse(
          value,
          wrapperKeys,
        ),
      _ => throw const ApiException(
          message: 'The server returned an unexpected list response.',
        ),
    };

    return rawList
        .map((entry) => fromJson(_ensureObject(entry)))
        .toList(growable: false);
  }

  Map<String, dynamic> _readObject(
    dynamic response, {
    required List<String> wrapperKeys,
  }) {
    if (response is! Map<String, dynamic>) {
      throw const ApiException(
        message: 'The server returned an unexpected object response.',
      );
    }

    for (final key in wrapperKeys) {
      final value = response[key];
      if (value is Map<String, dynamic>) {
        return value;
      }
    }

    return response;
  }

  List<dynamic> _listFromWrappedResponse(
    Map<String, dynamic> response,
    List<String> wrapperKeys,
  ) {
    for (final key in wrapperKeys) {
      final value = response[key];
      if (value is List<dynamic>) {
        return value;
      }
    }

    throw const ApiException(
      message: 'The server returned an unexpected list response.',
    );
  }

  Map<String, dynamic> _ensureObject(dynamic entry) {
    if (entry is Map<String, dynamic>) {
      return entry;
    }

    throw const ApiException(
      message: 'The server returned an unexpected item response.',
    );
  }
}
