import 'package:shopease_mobile/models/subcategory.dart';
import 'package:shopease_mobile/repositories/subcategory_repository.dart';

class SubcategoryController {
  SubcategoryController({required SubcategoryRepository subcategoryRepository})
      : _subcategoryRepository = subcategoryRepository;

  final SubcategoryRepository _subcategoryRepository;

  Future<List<Subcategory>> fetchSubcategories(String categoryId) {
    return _subcategoryRepository.fetchSubcategories(categoryId);
  }
}