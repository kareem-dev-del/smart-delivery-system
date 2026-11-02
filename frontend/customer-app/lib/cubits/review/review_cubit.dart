import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shopease_mobile/controllers/review_controller.dart';

import 'review_state.dart';

export 'review_state.dart';

class ReviewCubit extends Cubit<ReviewState> {
  ReviewCubit({required this.reviewController}) : super(const ReviewState());

  final ReviewController reviewController;

  Future<void> loadReviews(String productId) async {
    emit(state.copyWith(isLoading: true, clearError: true));
    try {
      final reviews = await reviewController.fetchReviews(productId);
      emit(state.copyWith(reviews: reviews, isLoading: false));
    } catch (e) {
      emit(state.copyWith(isLoading: false, error: e.toString().replaceFirst('Exception: ', '')));
    }
  }

  Future<bool> submitReview({
    required String productId,
    required int rating,
    required String text,
  }) async {
    emit(state.copyWith(isSubmitting: true, clearError: true));
    try {
      final review = await reviewController.submitReview(
        productId: productId,
        rating: rating,
        text: text,
      );
      emit(state.copyWith(
        reviews: [review, ...state.reviews],
        isSubmitting: false,
      ));
      return true;
    } catch (e) {
      emit(state.copyWith(
        isSubmitting: false,
        error: e.toString().replaceFirst('Exception: ', ''),
      ));
      return false;
    }
  }

  Future<bool> updateReview({
    required String productId,
    required String reviewId,
    required int rating,
    required String text,
  }) async {
    emit(state.copyWith(isSubmitting: true, clearError: true));
    try {
      final updated = await reviewController.updateReview(
        productId: productId,
        reviewId: reviewId,
        rating: rating,
        text: text,
      );
      emit(state.copyWith(
        reviews: [
          for (final r in state.reviews)
            if (r.id == reviewId) updated else r,
        ],
        isSubmitting: false,
      ));
      return true;
    } catch (e) {
      emit(state.copyWith(
        isSubmitting: false,
        error: e.toString().replaceFirst('Exception: ', ''),
      ));
      return false;
    }
  }

  Future<bool> deleteReview({
    required String productId,
    required String reviewId,
  }) async {
    emit(state.copyWith(isSubmitting: true, clearError: true));
    try {
      await reviewController.deleteReview(
        productId: productId,
        reviewId: reviewId,
      );
      emit(state.copyWith(
        reviews: state.reviews.where((r) => r.id != reviewId).toList(),
        isSubmitting: false,
      ));
      return true;
    } catch (e) {
      emit(state.copyWith(
        isSubmitting: false,
        error: e.toString().replaceFirst('Exception: ', ''),
      ));
      return false;
    }
  }
}