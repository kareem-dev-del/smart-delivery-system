import 'package:shopease_mobile/models/subcategory.dart';
import 'package:shopease_mobile/services/subcategory_service.dart';

class SubcategoryRepository {
  SubcategoryRepository({required SubcategoryService subcategoryService})
      : _subcategoryService = subcategoryService;

  final SubcategoryService _subcategoryService;

  Future<List<Subcategory>> fetchSubcategories(String categoryId) {
    return _subcategoryService.fetchSubcategories(categoryId);
  }
}