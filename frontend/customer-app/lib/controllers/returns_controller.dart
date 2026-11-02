import 'package:shopease_mobile/models/return_request.dart';
import 'package:shopease_mobile/repositories/returns_repository.dart';

// [تعديل] — النسخة القديمة كانت ChangeNotifier بتنادي
// dataService.fetchReturnRequests() و dataService.submitReturnRequest()،
// وهما methods مش موجودين أصلاً في AppDataService ولا أي implementation
// بتاعته (لا ApiDataService ولا MockDataService) — يعني كانت هترمي compile
// error لأول واحد يستخدمها. استبدلناها بطبقة رفيعة بتفوّت لـ
// ReturnsRepository، بالظبط زي OrdersController، ونقلنا إدارة الـstate
// (loading/submitting/error) لـReturnsCubit عشان الطبقة دي تبقى stateless.
class ReturnsController {
  ReturnsController({required ReturnsRepository returnsRepository})
      : _returnsRepository = returnsRepository;

  final ReturnsRepository _returnsRepository;

  Future<List<ReturnRequest>> fetchReturns() =>
      _returnsRepository.fetchReturns();

  Future<ReturnRequest> submitReturn({
    required String orderId,
    String? reason,
  }) =>
      _returnsRepository.submitReturn(orderId: orderId, reason: reason);
}
