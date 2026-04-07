import 'package:tnt_lh/utils/formatters.dart';

class Order {
  final String id;
  final String orderNumber;
  final String status;
  final String brand;
  final double subtotal;
  final double deliveryCharge;
  final double tax;
  final double total;
  final String? createdAt;
  final List<OrderItem> items;
  final OrderAddress? deliveryAddress;
  final String paymentMethod;
  final String paymentStatus;
  final double? foodRating;
  final double? riderRating;
  final String? review;
  final String? specialInstructions;
  final String? estimatedDeliveryTime;
  final String? confirmedAt;
  final String? assignedAt;
  final String? outForDeliveryAt;
  final String? deliveredAt;
  final String? cancelledAt;
  final String? cancelReason;
  final List<OrderTimeline> timeline;

  Order({
    required this.id,
    required this.orderNumber,
    required this.status,
    required this.brand,
    required this.subtotal,
    required this.deliveryCharge,
    required this.tax,
    required this.total,
    this.createdAt,
    required this.items,
    this.deliveryAddress,
    required this.paymentMethod,
    required this.paymentStatus,
    this.foodRating,
    this.riderRating,
    this.review,
    this.specialInstructions,
    this.estimatedDeliveryTime,
    this.confirmedAt,
    this.assignedAt,
    this.outForDeliveryAt,
    this.deliveredAt,
    this.cancelledAt,
    this.cancelReason,
    required this.timeline,
  });

  factory Order.fromJson(Map<String, dynamic> json) {
    return Order(
      id: AppFormatters.parseId(json['_id'] ?? json['id']),
      orderNumber: json['orderNumber']?.toString() ?? '',
      status: json['status']?.toString() ?? 'pending',
      brand: json['brand']?.toString() ?? 'teasntrees',
      subtotal: (json['subtotal'] ?? 0).toDouble(),
      deliveryCharge: (json['deliveryCharge'] ?? 0).toDouble(),
      tax: (json['tax'] ?? 0).toDouble(),
      total: (json['total'] ?? 0).toDouble(),
      createdAt: json['createdAt']?.toString(),
      items:
          (json['items'] as List?)
              ?.map((item) => OrderItem.fromJson(item))
              .toList() ??
          [],
      deliveryAddress: json['deliveryAddress'] != null
          ? OrderAddress.fromJson(json['deliveryAddress'])
          : null,
      paymentMethod: json['paymentMethod']?.toString() ?? 'COD',
      paymentStatus: json['paymentStatus']?.toString() ?? 'pending',
      foodRating: json['foodRating'] != null
          ? (json['foodRating']).toDouble()
          : null,
      riderRating: json['riderRating'] != null
          ? (json['riderRating']).toDouble()
          : null,
      review: json['review']?.toString(),
      specialInstructions: json['specialInstructions']?.toString(),
      estimatedDeliveryTime: json['estimatedDeliveryTime']?.toString(),
      confirmedAt: json['confirmedAt']?.toString(),
      assignedAt: json['assignedAt']?.toString(),
      outForDeliveryAt: json['outForDeliveryAt']?.toString(),
      deliveredAt: json['deliveredAt']?.toString(),
      cancelledAt: json['cancelledAt']?.toString(),
      cancelReason: json['cancelReason']?.toString(),
      timeline:
          (json['timeline'] as List?)
              ?.map((t) => OrderTimeline.fromJson(t))
              .toList() ??
          [],
    );
  }
}

class OrderItem {
  final String? product;
  final String name;
  final int quantity;
  final double price;
  final String? customization;

  OrderItem({
    this.product,
    required this.name,
    required this.quantity,
    required this.price,
    this.customization,
  });

  factory OrderItem.fromJson(Map<String, dynamic> json) {
    String? productId;
    if (json['product'] is Map) {
      productId = AppFormatters.parseId(
        json['product']['_id'] ?? json['product']['id'],
      );
    } else {
      productId = AppFormatters.parseId(json['product']);
    }

    return OrderItem(
      product: productId,
      name: json['name']?.toString() ?? '',
      quantity: (json['quantity'] ?? 0).toInt(),
      price: (json['price'] ?? 0).toDouble(),
      customization: json['customization']?.toString(),
    );
  }
}

class OrderAddress {
  final String address;
  final List<double>? coordinates;

  OrderAddress({required this.address, this.coordinates});

  factory OrderAddress.fromJson(Map<String, dynamic> json) {
    return OrderAddress(
      address: json['address'] ?? '',
      coordinates:
          json['location'] != null && json['location']['coordinates'] != null
          ? List<double>.from(
              json['location']['coordinates'].map((e) => e.toDouble()),
            )
          : null,
    );
  }
}

class OrderTimeline {
  final String status;
  final String timestamp;
  final String? description;

  OrderTimeline({
    required this.status,
    required this.timestamp,
    this.description,
  });

  factory OrderTimeline.fromJson(Map<String, dynamic> json) {
    return OrderTimeline(
      status: json['status']?.toString() ?? '',
      timestamp: json['timestamp']?.toString() ?? '',
      description: json['description']?.toString(),
    );
  }
}
