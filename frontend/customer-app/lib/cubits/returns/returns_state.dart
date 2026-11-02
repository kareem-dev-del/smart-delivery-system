import 'package:shopease_mobile/models/return_request.dart';

class ReturnsState {
  const ReturnsState({
    this.returns = const [],
    this.isLoading = false,
    this.isSubmitting = false,
    this.error,
  });

  final List<ReturnRequest> returns;
  final bool isLoading;

  // بيتحدد وقت تقديم return request جديد (من الـ"Start a Return" bottom
  // sheet)، منفصل عن isLoading عشان الـUI يقدر يعرض loading على زرار
  // الإرسال بس من غير ما يغيّر شكل الليستة اللي فوق
  final bool isSubmitting;

  final String? error;

  List<ReturnRequest> get activeReturns =>
      returns.where((r) => r.status == ReturnStatus.inReview).toList();

  List<ReturnRequest> get pastReturns =>
      returns.where((r) => r.status != ReturnStatus.inReview).toList();

  bool get isEmpty => !isLoading && error == null && returns.isEmpty;

  ReturnsState copyWith({
    List<ReturnRequest>? returns,
    bool? isLoading,
    bool? isSubmitting,
    String? error,
    bool clearError = false,
  }) {
    return ReturnsState(
      returns: returns ?? this.returns,
      isLoading: isLoading ?? this.isLoading,
      isSubmitting: isSubmitting ?? this.isSubmitting,
      error: clearError ? null : (error ?? this.error),
    );
  }
}
