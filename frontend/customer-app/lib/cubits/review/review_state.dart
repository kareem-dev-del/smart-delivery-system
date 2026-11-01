import 'package:shopease_mobile/models/product_review.dart';

class ReviewState {
  const ReviewState({
    this.reviews = const [],
    this.isLoading = false,
    this.isSubmitting = false,
    this.error,
  });

  final List<ProductReview> reviews;
  final bool isLoading;
  final bool isSubmitting;
  final String? error;

  ReviewState copyWith({
    List<ProductReview>? reviews,
    bool? isLoading,
    bool? isSubmitting,
    String? error,
    bool clearError = false,
  }) {
    return ReviewState(
      reviews: reviews ?? this.reviews,
      isLoading: isLoading ?? this.isLoading,
      isSubmitting: isSubmitting ?? this.isSubmitting,
      error: clearError ? null : (error ?? this.error),
    );
  }
}