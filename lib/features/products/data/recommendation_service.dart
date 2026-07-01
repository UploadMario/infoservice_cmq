import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:infoservice_cmq/features/products/data/models/product_model.dart';

class RecommendationService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Future<List<ProductModel>> getRelatedProducts(String productId, {int limit = 5}) async {
    final orders = await _firestore.collection('historial_compras').get();

    final Map<String, int> coCount = {};
    for (final order in orders.docs) {
      final data = order.data();
      final productos = (data['productos'] as List<dynamic>?) ?? [];
      final ids = productos
          .map((p) => (p as Map<String, dynamic>)['productoId'] as String?)
          .whereType<String>()
          .toSet();
      if (ids.contains(productId)) {
        for (final id in ids) {
          if (id != productId) {
            coCount[id] = (coCount[id] ?? 0) + 1;
          }
        }
      }
    }

    final sorted = coCount.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final topIds = sorted.take(limit).map((e) => e.key).toList();
    if (topIds.isEmpty) return [];

    final products = <ProductModel>[];
    for (final id in topIds) {
      final doc = await _firestore.collection('productos').doc(id).get();
      if (!doc.exists) continue;
      final data = doc.data()!;
      if (data['estado'] != 'activo') continue;

      String brandName = '';
      final brandId = data['marca'] ?? '';
      if (brandId.isNotEmpty) {
        final brandDoc = await _firestore.collection('marcas').doc(brandId).get();
        if (brandDoc.exists) brandName = brandDoc['nombre'] ?? '';
      }

      String categoryName = '';
      final categoryId = data['categoria'] ?? '';
      if (categoryId.isNotEmpty) {
        final catDoc = await _firestore.collection('categorias_nivel3').doc(categoryId).get();
        if (catDoc.exists) categoryName = catDoc['nombre'] ?? '';
      }

      products.add(ProductModel(
        id: doc.id,
        name: data['nombre'] ?? '',
        brandId: brandId,
        categoryId: categoryId,
        brandName: brandName,
        categoryName: categoryName,
        price: (data['precio'] ?? 0).toDouble(),
        stock: data['stock'] ?? 0,
        imageUrl: data['imagen_url'] ?? '',
        isActive: true,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      ));
    }
    return products;
  }
}
