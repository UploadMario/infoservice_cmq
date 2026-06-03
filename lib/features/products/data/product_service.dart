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

              final creadoEn = productData['creado_en'];
              final actualizadoEn = productData['actualizado_en'];

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
                createdAt: creadoEn is Timestamp
                    ? creadoEn.toDate()
                    : DateTime.now(),
                updatedAt: actualizadoEn is Timestamp
                    ? actualizadoEn.toDate()
                    : DateTime.now(),
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
              final creadoEn = productData['creado_en'];
              final actualizadoEn = productData['actualizado_en'];

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
                categoryName: '',
                price: (productData['precio'] ?? 0).toDouble(),
                stock: productData['stock'] ?? 0,
                imageUrl: productData['imagen_url'] ?? '',
                isActive: productData['estado'] == 'activo',
                createdAt: creadoEn is Timestamp
                    ? creadoEn.toDate()
                    : DateTime.now(),
                updatedAt: actualizadoEn is Timestamp
                    ? actualizadoEn.toDate()
                    : DateTime.now(),
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
              final creadoEn = productData['creado_en'];
              final actualizadoEn = productData['actualizado_en'];

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
                brandName: '',
                categoryName: categoryName,
                price: (productData['precio'] ?? 0).toDouble(),
                stock: productData['stock'] ?? 0,
                imageUrl: productData['imagen_url'] ?? '',
                isActive: productData['estado'] == 'activo',
                createdAt: creadoEn is Timestamp
                    ? creadoEn.toDate()
                    : DateTime.now(),
                updatedAt: actualizadoEn is Timestamp
                    ? actualizadoEn.toDate()
                    : DateTime.now(),
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
              final creadoEn = productData['creado_en'];
              final actualizadoEn = productData['actualizado_en'];

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
                createdAt: creadoEn is Timestamp
                    ? creadoEn.toDate()
                    : DateTime.now(),
                updatedAt: actualizadoEn is Timestamp
                    ? actualizadoEn.toDate()
                    : DateTime.now(),
              );
            }),
          );
          return products;
        });
  }

  // --- CRUD Operations ---

  Future<void> addProduct({
    required String name,
    required String brandId,
    required String categoryId,
    required double price,
    required int stock,
    required String imageUrl,
  }) async {
    await _firestore.collection('productos').add({
      'nombre': name,
      'marca': brandId,
      'categoria': categoryId,
      'precio': price,
      'stock': stock,
      'imagen_url': imageUrl,
      'estado': 'activo',
      'creado_en': FieldValue.serverTimestamp(),
      'actualizado_en': FieldValue.serverTimestamp(),
    });
  }

  Future<void> updateProduct({
    required String id,
    required String name,
    required String brandId,
    required String categoryId,
    required double price,
    required int stock,
    required String imageUrl,
  }) async {
    await _firestore.collection('productos').doc(id).update({
      'nombre': name,
      'marca': brandId,
      'categoria': categoryId,
      'precio': price,
      'stock': stock,
      'imagen_url': imageUrl,
      'actualizado_en': FieldValue.serverTimestamp(),
    });
  }

  Future<void> deleteProduct(String id) async {
    await _firestore.collection('productos').doc(id).delete();
  }

  // --- Reference Data for Forms ---

  Future<List<Map<String, dynamic>>> getBrandsList() async {
    final snapshot = await _firestore.collection('marcas').get();
    return snapshot.docs.map((doc) => {'id': doc.id, ...doc.data()}).toList();
  }

  Future<List<Map<String, dynamic>>> getCategoriesList() async {
    final snapshot = await _firestore.collection('categorias_nivel3').get();
    return snapshot.docs.map((doc) => {'id': doc.id, ...doc.data()}).toList();
  }
}
