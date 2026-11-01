import 'package:shopease_mobile/models/order.dart';
import 'package:shopease_mobile/repositories/orders_repository.dart';

// [تعديل] — النسخة القديمة كانت ChangeNotifier بتنادي
// dataService.fetchOrders()، وده method مش موجود أصلًا في AppDataService
// ولا في أي implementation بتاعته (لا ApiDataService ولا MockDataService) —
// يعني كانت هترمي compile error لأول واحد يستخدمها. استبدلناها بطبقة رفيعة
// بتفوّت لـOrdersRepository، بالظبط زي CartController، ومربوطة فعليًا
// بالسيرفر عن طريق OrdersService.
class OrdersController {
  OrdersController({required OrdersRepository ordersRepository})
      : _ordersRepository = ordersRepository;

  final OrdersRepository _ordersRepository;

  Future<List<Order>> fetchOrders() => _ordersRepository.fetchOrders();

  Future<Order?> fetchOrderById(String id) =>
      _ordersRepository.fetchOrderById(id);

  Future<Order> cancelOrder(String id) => _ordersRepository.cancelOrder(id);
}
