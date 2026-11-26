import 'package:tnt_lh/utils/formatters.dart';

class Category {
  final String id;
  final String name;
  final String? image;
  final String? description;
  final String brand; // 'teasntrees' or 'littleh'

  /// Number of available products in this category. Null when the backend
  /// hasn't supplied it (older builds/endpoints) — the menu sheet then just
  /// hides the count rather than showing a wrong zero.
  final int? productCount;

  Category({
    required this.id,
    required this.name,
    this.image,
    this.description,
    required this.brand,
    this.productCount,
  });

  factory Category.fromJson(Map<String, dynamic> json) {
    // Robust brand parsing
    String brandStr = 'teasntrees';
    if (json['brand'] != null) {
      brandStr = json['brand'].toString().toLowerCase().trim();
    }

    final rawCount = json['productCount'] ?? json['count'];

    return Category(
      id: AppFormatters.parseId(json['_id'] ?? json['id']),
      name: json['name'] ?? '',
      // Only a real picture. The old 'icon' field holds an emoji, which was
      // being loaded as an image URL and showed a broken placeholder.
      image: _url(json['image']),
      description: json['description'],
      brand: brandStr,
      productCount: rawCount is num ? rawCount.toInt() : null,
    );
  }
}

class Product {
  final String id;
  final String name;
  final String? description;
  final String? image;
  final String? categoryId;
  final String? categoryName;
  final String brand; // 'teasntrees' or 'littleh'
  final double price;
  final bool isAvailable;
  final bool inStock;
  final List<String> tags;
  final List<String> ingredients;
  final List<String> allergens;
  final double averageRating;
  final List<SizeOption> sizeOptions;
  final CakePricing? cakePricing;

  /// 'veg', 'egg' or 'nonveg', set per item in the admin panel. Drives the
  /// menu filter and whether an item can be made eggless.
  final String foodType;

  Product({
    required this.id,
    required this.name,
    this.description,
    this.image,
    this.categoryId,
    this.categoryName,
    required this.brand,
    required this.price,
    this.isAvailable = true,
    this.inStock = true,
    this.tags = const [],
    this.ingredients = const [],
    this.allergens = const [],
    this.averageRating = 0.0,
    this.sizeOptions = const [],
    this.cakePricing,
    this.foodType = 'veg',
  });

  /// Only items that contain egg can be made eggless, and only where the
  /// store allows it.
  bool get canBeEggless =>
      foodType == 'egg' && (cakePricing?.egglessAvailable ?? false);

  double get displayPrice {
    if (cakePricing != null && cakePricing!.basePricePerKg > 0) {
      return cakePricing!.basePricePerKg;
    }
    if (sizeOptions.isNotEmpty) {
      return sizeOptions
          .map((e) => e.price)
          .reduce((curr, next) => curr < next ? curr : next);
    }
    return price;
  }

  factory Product.fromJson(Map<String, dynamic> json) {
    var catId = '';
    var catName = '';
    String productBrand = 'teasntrees';

    if (json['category'] is Map) {
      catId = AppFormatters.parseId(
        json['category']['_id'] ?? json['category']['id'],
      );
      catName = json['category']['name'] ?? '';
      // Try to infer brand from category if missing on product
      if (json['brand'] == null && json['category']['brand'] != null) {
        productBrand = json['category']['brand']
            .toString()
            .toLowerCase()
            .trim();
      }
    } else if (json['category'] is String) {
      catId = json['category'];
    }

    if (json['brand'] != null) {
      productBrand = json['brand'].toString().toLowerCase().trim();
    }

    return Product(
      id: AppFormatters.parseId(json['_id'] ?? json['id']),
      name: json['name'] ?? '',
      description: json['description'] ?? '',
      image: json['image'],
      categoryId: catId,
      categoryName: catName,
      brand: productBrand,
      price: (json['price'] ?? 0).toDouble(),
      isAvailable: json['isAvailable'] ?? true,
      inStock: json['inStock'] ?? true,
      tags: json['tags'] != null ? List<String>.from(json['tags']) : [],
      ingredients: json['ingredients'] != null
          ? List<String>.from(json['ingredients'])
          : [],
      allergens: json['allergens'] != null
          ? List<String>.from(json['allergens'])
          : [],
      averageRating: (json['averageRating'] ?? 0).toDouble(),
      sizeOptions: json['sizeOptions'] != null
          ? (json['sizeOptions'] as List)
                .map((e) => SizeOption.fromJson(e))
                .toList()
          : [],
      cakePricing: json['cakePricing'] != null
          ? CakePricing.fromJson(json['cakePricing'])
          : null,
      foodType: const {'veg', 'egg', 'nonveg'}.contains(json['foodType'])
          ? json['foodType'] as String
          : 'veg',
    );
  }
}

class SizeOption {
  final String size;
  final double price;

  SizeOption({required this.size, required this.price});

  factory SizeOption.fromJson(Map<String, dynamic> json) {
    return SizeOption(
      size: json['size'] ?? '',
      price: (json['price'] ?? 0).toDouble(),
    );
  }
}

class CakePricing {
  final double basePricePerKg;
  final bool customizationAvailable;
  final double customizationPricePerKg;
  final bool egglessAvailable;
  final double egglessExtraCharge;

  CakePricing({
    required this.basePricePerKg,
    this.customizationAvailable = false,
    this.customizationPricePerKg = 0,
    this.egglessAvailable = true,
    this.egglessExtraCharge = 100,
  });

  factory CakePricing.fromJson(Map<String, dynamic> json) {
    return CakePricing(
      basePricePerKg: (json['basePricePerKg'] ?? 0).toDouble(),
      customizationAvailable: json['customizationAvailable'] ?? false,
      customizationPricePerKg: (json['customizationPricePerKg'] ?? 0)
          .toDouble(),
      egglessAvailable: json['egglessAvailable'] ?? true,
      egglessExtraCharge: (json['egglessExtraCharge'] ?? 100).toDouble(),
    );
  }
}

String? _url(dynamic v) {
  final s = v?.toString().trim() ?? '';
  return s.startsWith('http') ? s : null;
}
