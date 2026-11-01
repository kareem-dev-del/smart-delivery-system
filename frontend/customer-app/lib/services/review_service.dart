import 'package:shopease_mobile/core/network/api_client.dart';
import 'package:shopease_mobile/core/network/api_error.dart';
import 'package:shopease_mobile/models/product_review.dart';

class ReviewService {
  ReviewService({required ApiClient client}) : _client = client;

  final ApiClient _client;

  Future<List<ProductReview>> fetchReviews(String productId) async {
    final response = await _client.get<dynamic>(
      '/products/${Uri.encodeComponent(productId)}/reviews',
    );
    return _readList(response, wrapperKeys: const ['reviews', 'data', 'items']);
  }

  Future<ProductReview> submitReview({
    required String productId,
    required int rating,
    required String text,
  }) async {
    final response = await _client.post<Map<String, dynamic>>(
      '/products/${Uri.encodeComponent(productId)}/reviews',
      body: {'rating': rating, 'text': text},
    );
    final reviewJson = response['review'] ?? response['data'] ?? response;
    if (reviewJson is! Map<String, dynamic>) {
      throw const ApiException(message: 'The server returned an unexpected review response.');
    }
    return ProductReview.fromJson(reviewJson);
  }

  Future<ProductReview> updateReview({
    required String productId,
    required String reviewId,
    required int rating,
    required String text,
  }) async {
    final response = await _client.patch<Map<String, dynamic>>(
      '/products/${Uri.encodeComponent(productId)}/reviews/${Uri.encodeComponent(reviewId)}',
      body: {'rating': rating, 'text': text},
    );
    final reviewJson = response['review'] ?? response['data'] ?? response;
    if (reviewJson is! Map<String, dynamic>) {
      throw const ApiException(message: 'The server returned an unexpected review response.');
    }
    return ProductReview.fromJson(reviewJson);
  }

  Future<void> deleteReview({
    required String productId,
    required String reviewId,
  }) {
    return _client.delete<void>(
      '/products/${Uri.encodeComponent(productId)}/reviews/${Uri.encodeComponent(reviewId)}',
    );
  }

  List<ProductReview> _readList(dynamic response, {required List<String> wrapperKeys}) {
    final rawList = switch (response) {
      final List<dynamic> value => value,
      final Map<String, dynamic> value => _listFromWrappedResponse(value, wrapperKeys),
      _ => throw const ApiException(message: 'The server returned an unexpected list response.'),
    };
    return rawList.map((entry) => ProductReview.fromJson(_ensureObject(entry))).toList(growable: false);
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