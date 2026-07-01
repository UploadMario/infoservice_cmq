import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:infoservice_cmq/features/products/data/models/product_model.dart';

class ProductService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Future<List<ProductModel>> _buildProducts(QuerySnapshot snapshot) async {
    return Future.wait(
      snapshot.docs.map((doc) async {
        final productData = doc.data() as Map<String, dynamic>;
        final brandId = productData['marca'] ?? '';
        final categoryId = productData['categoria'] ?? '';

        String brandName = '';
        if (brandId.isNotEmpty) {
          final brandDoc = await _firestore
              .collection('marcas')
              .doc(brandId)
              .get();
          if (brandDoc.exists) brandName = brandDoc['nombre'] ?? '';
        }

        String categoryName = '';
        if (categoryId.isNotEmpty) {
          final categoryDoc = await _firestore
              .collection('categorias_nivel3')
              .doc(categoryId)
              .get();
          if (categoryDoc.exists) categoryName = categoryDoc['nombre'] ?? '';
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
  }

  Future<List<ProductModel>> getProducts() async {
    final snapshot = await _firestore
        .collection('productos')
        .where('estado', isEqualTo: 'activo')
        .get();
    return _buildProducts(snapshot);
  }

  Future<List<ProductModel>> getProductsByCategory(String categoryId) async {
    final snapshot = await _firestore
        .collection('productos')
        .where('categoria', isEqualTo: categoryId)
        .where('estado', isEqualTo: 'activo')
        .get();
    return _buildProducts(snapshot);
  }

  Future<List<ProductModel>> getProductsByBrand(String brandId) async {
    final snapshot = await _firestore
        .collection('productos')
        .where('marca', isEqualTo: brandId)
        .where('estado', isEqualTo: 'activo')
        .get();
    return _buildProducts(snapshot);
  }

  Future<List<ProductModel>> getProductsByPriceRange(
    double minPrice,
    double maxPrice,
  ) async {
    final snapshot = await _firestore
        .collection('productos')
        .where('precio', isGreaterThanOrEqualTo: minPrice)
        .where('precio', isLessThanOrEqualTo: maxPrice)
        .where('estado', isEqualTo: 'activo')
        .get();
    return _buildProducts(snapshot);
  }
}
