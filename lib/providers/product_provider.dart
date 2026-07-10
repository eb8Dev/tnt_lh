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
  // The request is already brand-scoped (/api/:brand/...), so the backend
  // returns only this brand's categories. Re-filtering client-side risked
  // showing an empty screen whenever a brand field didn't match exactly.
  final raw = await AuthService.getCategories(brand: brand);
  return raw.map((e) => Category.fromJson(e)).toList();
});

final productsProvider = FutureProvider.family<List<Product>, ProductParams>((
  ref,
  params,
) async {
  // Brand-scoped endpoint already filters by brand — see categoriesProvider.
  final raw = await AuthService.getProducts(
    categoryId: params.categoryId,
    search: params.search,
    brand: params.brand,
  );
  return raw.map((e) => Product.fromJson(e)).toList();
});
