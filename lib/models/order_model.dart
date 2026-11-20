import 'package:tnt_lh/utils/formatters.dart';

Map? _rider(Map json) {
  final d = json['delivery'];
  if (d is Map && d['rider'] is Map) return d['rider'] as Map;
  if (json['riderId'] is Map) return json['riderId'] as Map;
  return null;
}

class Order {
  final String id;
  final String orderNumber;
  final String status;
  final String brand;
  final double subtotal;
  final double deliveryCharge;
  final double tax;
  final double total;

  /// Coupon savings; the bill showed none, so a coupon order's lines didn't
  /// add up to its total.
  final double discount;
  final String? couponCode;
  final String? createdAt;
  final String? updatedAt;
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

  /// What the rider is doing (heading_to_pickup, arrived_at_pickup, picked_up,
  /// in_transit, arrived...), when a rider has the order. Finer than [status],
  /// which stays "assigned" while the rider waits at the store and "on the way"
  /// after they reach the door.
  final String? deliveryStatus;

  /// The rider on this order, and the PIN the customer gives them at the door
  /// (sent only once the rider is on the way to the customer).
  final String? riderName;
  final String? riderPhone;

  /// The rider's ID badge: their rider ID, vehicle, rating and delivery count.
  final RiderBadge? riderBadge;
  final String? deliveryOtp;

  /// A rider has the order and it isn't finished: the live, map-first view.
  bool get isRiderPhase {
    const steps = {
      'rider_assigned',
      'at_store',
      'on_the_way',
      'assigned',
      'accepted',
      'heading_to_pickup',
      'arrived_at_pickup',
      'picked_up',
      'out-for-delivery',
      'in_transit',
      'arrived',
    };
    return steps.contains(displayStatus.toLowerCase());
  }

  static const _riderSteps = {
    'accepted',
    'heading_to_pickup',
    'arrived_at_pickup',
    'picked_up',
    'in_transit',
    'arrived',
  };

  /// The journey stage from the server (placed, preparing, ready,
  /// rider_assigned, at_store, picked_up, on_the_way, arrived, delivered,
  /// cancelled) and its version: a newer version is a newer state.
  final String? stage;
  final int stageVersion;

  /// The status to show the customer.
  String get displayStatus {
    if (stage != null && stage!.isNotEmpty) return stage!;
    final s = status.toLowerCase();
    final d = deliveryStatus?.toLowerCase();
    if (d != null &&
        _riderSteps.contains(d) &&
        s != 'delivered' &&
        s != 'cancelled') {
      return d;
    }
    return status;
  }

  Order({
    required this.id,
    required this.orderNumber,
    required this.status,
    required this.brand,
    required this.subtotal,
    required this.deliveryCharge,
    required this.tax,
    required this.total,
    this.discount = 0,
    this.couponCode,
    this.createdAt,
    this.updatedAt,
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
    this.deliveryStatus,
    this.stage,
    this.stageVersion = 0,
    this.riderName,
    this.riderPhone,
    this.riderBadge,
    this.deliveryOtp,
  });

  /// When this order last moved (its last status change), falling back to when
  /// it was placed. Null only if the server sent neither.
  DateTime? get lastActivity =>
      DateTime.tryParse(updatedAt ?? '') ?? DateTime.tryParse(createdAt ?? '');

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
      discount: (json['discount'] ?? 0).toDouble(),
      couponCode: json['couponCode']?.toString(),
      createdAt: json['createdAt']?.toString(),
      updatedAt: json['updatedAt']?.toString(),
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
      deliveryStatus: json['delivery'] is Map
          ? (json['delivery'] as Map)['status']?.toString()
          : null,
      stage: json['stage']?.toString(),
      stageVersion: (json['stageVersion'] as num?)?.toInt() ?? 0,
      riderName: _rider(json)?['name']?.toString(),
      riderPhone: _rider(json)?['mobile']?.toString(),
      riderBadge: RiderBadge.fromRider(_rider(json)),
      deliveryOtp:
          (json['journey'] is Map
              ? (json['journey'] as Map)['deliveryOtp']?.toString()
              : null) ??
          (json['delivery'] is Map
              ? (json['delivery'] as Map)['deliveryOtp']?.toString()
              : null),
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

/// What the customer's rider card shows about their rider.
class RiderBadge {
  final String name;
  final String? phone;
  final String? code; // e.g. TNT-0042
  final String? vehicle; // e.g. "Splendor Bike"
  final String? vehicleNumber;
  final double? rating; // null until they have ratings
  final int deliveries;

  const RiderBadge({
    required this.name,
    this.phone,
    this.code,
    this.vehicle,
    this.vehicleNumber,
    this.rating,
    this.deliveries = 0,
  });

  String get initials {
    final parts = name
        .trim()
        .split(RegExp(r'\s+'))
        .where((p) => p.isNotEmpty)
        .toList();
    if (parts.isEmpty) return 'R';
    return parts.take(2).map((p) => p[0].toUpperCase()).join();
  }

  static RiderBadge? fromRider(Map? r) {
    final name = r?['name']?.toString();
    if (r == null || name == null || name.isEmpty) return null;
    final count = (r['ratingsCount'] as num?)?.toInt() ?? 0;
    final vehicle = [
      r['vehicleModel'],
      r['vehicleType'],
    ].where((v) => v != null && '$v'.isNotEmpty).join(' ');
    return RiderBadge(
      name: name,
      phone: r['mobile']?.toString(),
      code: r['readableId']?.toString(),
      vehicle: vehicle.isEmpty ? null : vehicle,
      vehicleNumber: r['vehicleNumber']?.toString(),
      rating: count > 0 ? (r['averageRating'] as num?)?.toDouble() : null,
      deliveries: (r['totalDeliveries'] as num?)?.toInt() ?? 0,
    );
  }
}
