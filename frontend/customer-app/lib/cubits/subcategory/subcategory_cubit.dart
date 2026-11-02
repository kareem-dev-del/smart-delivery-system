import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shopease_mobile/controllers/subcategory_controller.dart';

import 'subcategory_state.dart';

export 'subcategory_state.dart';

class SubcategoryCubit extends Cubit<SubcategoryState> {
  SubcategoryCubit({required this.subcategoryController})
      : super(const SubcategoryState());

  final SubcategoryController subcategoryController;

  Future<void> loadSubcategories(String categoryId) async {
    emit(state.copyWith(isLoading: true, clearError: true));
    try {
      final subcategories = await subcategoryController.fetchSubcategories(categoryId);
      emit(state.copyWith(subcategories: subcategories, isLoading: false));
    } catch (e) {
      emit(state.copyWith(
        isLoading: false,
        error: e.toString().replaceFirst('Exception: ', ''),
      ));
    }
  }

  void selectSubcategory(String? subcategoryId) {
    if (subcategoryId == null) {
      emit(state.copyWith(clearSelected: true));
    } else {
      emit(state.copyWith(selectedSubcategoryId: subcategoryId));
    }
  }
}