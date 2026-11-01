import 'package:shopease_mobile/models/product_review.dart';
import 'package:shopease_mobile/repositories/review_repository.dart';

class ReviewController {
  ReviewController({required ReviewRepository reviewRepository})
      : _reviewRepository = reviewRepository;

  final ReviewRepository _reviewRepository;

  Future<List<ProductReview>> fetchReviews(String productId) {
    return _reviewRepository.fetchReviews(productId);
  }

  Future<ProductReview> submitReview({
    required String productId,
    required int rating,
    required String text,
  }) {
    return _reviewRepository.submitReview(productId: productId, rating: rating, text: text);
  }

  Future<ProductReview> updateReview({
    required String productId,
    required String reviewId,
    required int rating,
    required String text,
  }) {
    return _reviewRepository.updateReview(
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
    return _reviewRepository.deleteReview(productId: productId, reviewId: reviewId);
  }
}