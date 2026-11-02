import 'package:shopease_mobile/models/subcategory.dart';

class SubcategoryState {
  const SubcategoryState({
    this.subcategories = const [],
    this.isLoading = false,
    this.error,
    this.selectedSubcategoryId,
  });

  final List<Subcategory> subcategories;
  final bool isLoading;
  final String? error;
  final String? selectedSubcategoryId;

  SubcategoryState copyWith({
    List<Subcategory>? subcategories,
    bool? isLoading,
    String? error,
    bool clearError = false,
    String? selectedSubcategoryId,
    bool clearSelected = false,
  }) {
    return SubcategoryState(
      subcategories: subcategories ?? this.subcategories,
      isLoading: isLoading ?? this.isLoading,
      error: clearError ? null : (error ?? this.error),
      selectedSubcategoryId: clearSelected
          ? null
          : (selectedSubcategoryId ?? this.selectedSubcategoryId),
    );
  }
}