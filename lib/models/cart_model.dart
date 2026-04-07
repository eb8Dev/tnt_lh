import 'package:tnt_lh/models/product_model.dart';
import 'package:tnt_lh/utils/formatters.dart';

class Cart {
  final List<CartItem> items;
  final double subtotal;
  final int itemCount;

  Cart({required this.items, required this.subtotal, required this.itemCount});

  factory Cart.fromJson(Map<String, dynamic> json) {
    final rawItems = json['items'];
    return Cart(
      items: rawItems is List
          ? rawItems
              .whereType<Map<String, dynamic>>()
              .map((i) => CartItem.fromJson(i))
              .toList()
          : [],
      subtotal: (json['subtotal'] ?? 0).toDouble(),
      itemCount: json['itemCount'] ?? 0,
    );
  }
}

class CartItem {
  final String id;
  final Product product;
  final int quantity;
  final double price;
  final String? customization;
  final String brand;

  CartItem({
    required this.id,
    required this.product,
    required this.quantity,
    required this.price,
    this.customization,
    required this.brand,
  });

  factory CartItem.fromJson(Map<String, dynamic> json) {
    final Map<String, dynamic> productData;
    final rawProduct = json['product'];
    final itemName = json['name'] as String?;
    
    if (rawProduct is Map<String, dynamic>) {
      productData = rawProduct;
      // If product data is missing name but cart item has it, use that
      if ((productData['name'] == null || productData['name'].toString().isEmpty) && itemName != null) {
        productData['name'] = itemName;
      }
    } else {
      // Handle when product is an ID string or missing
      productData = {
        '_id': rawProduct is String ? rawProduct : '',
        'name': itemName ?? 'Unknown Product',
        'price': (json['price'] ?? 0).toDouble(),
        'brand': json['brand'] ?? 'teasntrees',
      };
    }

    return CartItem(
      id: AppFormatters.parseId(json['_id'] ?? json['id']),
      product: Product.fromJson(productData),
      quantity: json['quantity'] ?? 1,
      price: (json['price'] ?? 0).toDouble(),
      customization: json['customization'],
      brand: json['brand'] ?? 'teasntrees',
    );
  }
}
