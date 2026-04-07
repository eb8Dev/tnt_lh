import 'package:flutter/foundation.dart' hide Category;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tnt_lh/models/product_model.dart';
import 'package:tnt_lh/services/auth_service.dart';

class ProductParams {
  final String? categoryId;
  final String? search;
  final String brand;

  ProductParams({this.categoryId, this.search, required this.brand});

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ProductParams &&
          runtimeType == other.runtimeType &&
          categoryId == other.categoryId &&
          search == other.search &&
          brand == other.brand;

  @override
  int get hashCode => categoryId.hashCode ^ search.hashCode ^ brand.hashCode;
}

final categoriesProvider = FutureProvider.family<List<Category>, String>((
  ref,
  brand,
) async {
  debugPrint("Fetching categories for brand: $brand");
  final raw = await AuthService.getCategories(brand: brand);
  final allCategories = raw.map((e) => Category.fromJson(e)).toList();

  final filtered = allCategories.where((c) {
    return c.brand.toLowerCase().trim() == brand.toLowerCase().trim();
  }).toList();

  debugPrint("Found ${filtered.length} categories for $brand");
  return filtered;
});

final productsProvider = FutureProvider.family<List<Product>, ProductParams>((
  ref,
  params,
) async {
  debugPrint(
    "Fetching products for brand: ${params.brand}, category: ${params.categoryId}",
  );
  final raw = await AuthService.getProducts(
    categoryId: params.categoryId,
    search: params.search,
    brand: params.brand,
  );

  final products = raw.map((e) => Product.fromJson(e)).toList();

  // Resilient filtering
  final filtered = products.where((p) {
    return p.brand.toLowerCase().trim() == params.brand.toLowerCase().trim();
  }).toList();

  debugPrint("Found ${filtered.length} products for ${params.brand}");
  return filtered;
});
