import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:infoservice_cmq/features/products/data/models/product_model.dart';

class ProductService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Obtener todos los productos (con nombres de categoría y marca)
  Stream<List<ProductModel>> getProducts() {
    return _firestore
        .collection('productos')
        .where('estado', isEqualTo: 'activo')
        .snapshots()
        .asyncMap((snapshot) async {
          final products = await Future.wait(
            snapshot.docs.map((doc) async {
              final productData = doc.data();
              final brandId = productData['marca'] ?? '';
              final categoryId = productData['categoria'] ?? '';

              // Obtener nombre de la marca
              String brandName = '';
              if (brandId.isNotEmpty) {
                final brandDoc = await _firestore
                    .collection('marcas')
                    .doc(brandId)
                    .get();
                if (brandDoc.exists) {
                  brandName = brandDoc['nombre'] ?? '';
                }
              }

              // Obtener nombre de la categoría
              String categoryName = '';
              if (categoryId.isNotEmpty) {
                final categoryDoc = await _firestore
                    .collection('categorias_nivel3')
                    .doc(categoryId)
                    .get();
                if (categoryDoc.exists) {
                  categoryName = categoryDoc['nombre'] ?? '';
                }
              }

              return ProductModel(
                id: doc.id,
                name: productData['nombre'] ?? '',
                brandId: brandId,
                categoryId: categoryId,
                brandName: brandName,
                categoryName: categoryName,
                price: (productData['precio'] ?? 0).toDouble(),
                stock: productData['stock'] ?? 0,
                imageUrl: productData['imagen_url'] ?? '',
                isActive: productData['estado'] == 'activo',
                createdAt: (productData['creado_en'] as Timestamp).toDate(),
                updatedAt: (productData['actualizado_en'] as Timestamp)
                    .toDate(),
              );
            }),
          );
          return products;
        });
  }

  // Obtener productos por categoría (nivel 3)
  Stream<List<ProductModel>> getProductsByCategory(String categoryId) {
    return _firestore
        .collection('productos')
        .where('categoria', isEqualTo: categoryId)
        .where('estado', isEqualTo: 'activo')
        .snapshots()
        .asyncMap((snapshot) async {
          final products = await Future.wait(
            snapshot.docs.map((doc) async {
              final productData = doc.data();
              final brandId = productData['marca'] ?? '';

              // Obtener nombre de la marca
              String brandName = '';
              if (brandId.isNotEmpty) {
                final brandDoc = await _firestore
                    .collection('marcas')
                    .doc(brandId)
                    .get();
                if (brandDoc.exists) {
                  brandName = brandDoc['nombre'] ?? '';
                }
              }

              return ProductModel(
                id: doc.id,
                name: productData['nombre'] ?? '',
                brandId: brandId,
                categoryId: categoryId,
                brandName: brandName,
                categoryName: '', // Opcional: obtener nombre de categoría
                price: (productData['precio'] ?? 0).toDouble(),
                stock: productData['stock'] ?? 0,
                imageUrl: productData['imagen_url'] ?? '',
                isActive: productData['estado'] == 'activo',
                createdAt: (productData['creado_en'] as Timestamp).toDate(),
                updatedAt: (productData['actualizado_en'] as Timestamp)
                    .toDate(),
              );
            }),
          );
          return products;
        });
  }

  // Obtener productos por marca
  Stream<List<ProductModel>> getProductsByBrand(String brandId) {
    return _firestore
        .collection('productos')
        .where('marca', isEqualTo: brandId)
        .where('estado', isEqualTo: 'activo')
        .snapshots()
        .asyncMap((snapshot) async {
          final products = await Future.wait(
            snapshot.docs.map((doc) async {
              final productData = doc.data();
              final categoryId = productData['categoria'] ?? '';

              // Obtener nombre de la categoría
              String categoryName = '';
              if (categoryId.isNotEmpty) {
                final categoryDoc = await _firestore
                    .collection('categorias_nivel3')
                    .doc(categoryId)
                    .get();
                if (categoryDoc.exists) {
                  categoryName = categoryDoc['nombre'] ?? '';
                }
              }

              return ProductModel(
                id: doc.id,
                name: productData['nombre'] ?? '',
                brandId: brandId,
                categoryId: categoryId,
                brandName: '', // Opcional: obtener nombre de marca
                categoryName: categoryName,
                price: (productData['precio'] ?? 0).toDouble(),
                stock: productData['stock'] ?? 0,
                imageUrl: productData['imagen_url'] ?? '',
                isActive: productData['estado'] == 'activo',
                createdAt: (productData['creado_en'] as Timestamp).toDate(),
                updatedAt: (productData['actualizado_en'] as Timestamp)
                    .toDate(),
              );
            }),
          );
          return products;
        });
  }

  // Filtrar productos por precio (rango)
  Stream<List<ProductModel>> getProductsByPriceRange(
    double minPrice,
    double maxPrice,
  ) {
    return _firestore
        .collection('productos')
        .where('precio', isGreaterThanOrEqualTo: minPrice)
        .where('precio', isLessThanOrEqualTo: maxPrice)
        .where('estado', isEqualTo: 'activo')
        .snapshots()
        .asyncMap((snapshot) async {
          final products = await Future.wait(
            snapshot.docs.map((doc) async {
              final productData = doc.data();
              final brandId = productData['marca'] ?? '';
              final categoryId = productData['categoria'] ?? '';

              // Obtener nombres de marca y categoría
              String brandName = '';
              String categoryName = '';
              if (brandId.isNotEmpty) {
                final brandDoc = await _firestore
                    .collection('marcas')
                    .doc(brandId)
                    .get();
                if (brandDoc.exists) {
                  brandName = brandDoc['nombre'] ?? '';
                }
              }
              if (categoryId.isNotEmpty) {
                final categoryDoc = await _firestore
                    .collection('categorias_nivel3')
                    .doc(categoryId)
                    .get();
                if (categoryDoc.exists) {
                  categoryName = categoryDoc['nombre'] ?? '';
                }
              }

              return ProductModel(
                id: doc.id,
                name: productData['nombre'] ?? '',
                brandId: brandId,
                categoryId: categoryId,
                brandName: brandName,
                categoryName: categoryName,
                price: (productData['precio'] ?? 0).toDouble(),
                stock: productData['stock'] ?? 0,
                imageUrl: productData['imagen_url'] ?? '',
                isActive: productData['estado'] == 'activo',
                createdAt: (productData['creado_en'] as Timestamp).toDate(),
                updatedAt: (productData['actualizado_en'] as Timestamp)
                    .toDate(),
              );
            }),
          );
          return products;
        });
  }
}
