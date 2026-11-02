import 'package:shopease_mobile/models/product_review.dart';
import 'package:shopease_mobile/services/review_service.dart';

class ReviewRepository {
  ReviewRepository({required ReviewService reviewService}) : _reviewService = reviewService;

  final ReviewService _reviewService;

  Future<List<ProductReview>> fetchReviews(String productId) {
    return _reviewService.fetchReviews(productId);
  }

  Future<ProductReview> submitReview({
    required String productId,
    required int rating,
    required String text,
  }) {
    return _reviewService.submitReview(productId: productId, rating: rating, text: text);
  }

  Future<ProductReview> updateReview({
    required String productId,
    required String reviewId,
    required int rating,
    required String text,
  }) {
    return _reviewService.updateReview(
      productId: productId,
      reviewId: reviewId,
      rating: rating,
      text: text,
    );
  }

  Future<void> deleteReview({
    required String productId,
    required String reviewId,
  }) {
    return _reviewService.deleteReview(productId: productId, reviewId: reviewId);
  }
}