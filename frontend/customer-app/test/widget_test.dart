import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shopease_mobile/models/app_user.dart';
import 'package:shopease_mobile/models/product.dart';

void main() {
  testWidgets('basic widget smoke test', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: Text('ShopEase'))),
    );

    expect(find.text('ShopEase'), findsOneWidget);
  });

  test('maps SmartDrop product fields for catalog and category filtering', () {
    final product = Product.fromJson({
      'id': 17,
      'name': 'Demo Backpack',
      'category': 4,
      'category_name': 'Accessories',
      'price': '125.50',
      'stock': 3,
      'description': 'Travel backpack',
    });

    expect(product.id, '17');
    expect(product.category, 'Accessories');
    expect(product.categoryId, '4');
    expect(product.price, 125.50);
    expect(product.inStock, isTrue);
    expect(product.stockCount, 3);
    expect(product.matchesCategory('4'), isTrue);
  });

  test('maps SmartDrop account profile names', () {
    final user = AppUser.fromJson({
      'id': 29,
      'username': 'demo-customer',
      'first_name': 'Demo',
      'last_name': 'Customer',
      'email': 'customer@example.com',
      'phone': '+201012345678',
    });

    expect(user.id, '29');
    expect(user.name, 'Demo Customer');
    expect(user.phone, '+201012345678');
  });
}
