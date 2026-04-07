import 'package:tnt_lh/utils/formatters.dart';

class Category {
  final String id;
  final String name;
  final String? image;
  final String? description;
  final String brand; // 'teasntrees' or 'littleh'

  Category({
    required this.id,
    required this.name,
    this.image,
    this.description,
    required this.brand,
  });

  factory Category.fromJson(Map<String, dynamic> json) {
    // Robust brand parsing
    String brandStr = 'teasntrees';
    if (json['brand'] != null) {
      brandStr = json['brand'].toString().toLowerCase().trim();
    }

    return Category(
      id: AppFormatters.parseId(json['_id'] ?? json['id']),
      name: json['name'] ?? '',
      image: json['image'] ?? json['icon'],
      description: json['description'],
      brand: brandStr,
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
  });

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
      customizationPricePerKg: (json['customizationPricePerKg'] ?? 0).toDouble(),
      egglessAvailable: json['egglessAvailable'] ?? true,
      egglessExtraCharge: (json['egglessExtraCharge'] ?? 100).toDouble(),
    );
  }
}
