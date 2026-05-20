import 'package:cloud_firestore/cloud_firestore.dart';

class ProductModel {
  final String id;
  final String name;
  final String brandId;
  final String categoryId;
  final String brandName; // Nuevo campo
  final String categoryName; // Nuevo campo
  final double price;
  final int stock;
  final String imageUrl;
  final bool isActive;
  final DateTime createdAt;
  final DateTime updatedAt;

  ProductModel({
    required this.id,
    required this.name,
    required this.brandId,
    required this.categoryId,
    required this.brandName, // Nuevo
    required this.categoryName, // Nuevo
    required this.price,
    required this.stock,
    required this.imageUrl,
    required this.isActive,
    required this.createdAt,
    required this.updatedAt,
  });

  factory ProductModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return ProductModel(
      id: doc.id,
      name: data['nombre'] ?? '',
      brandId: data['marca'] ?? '',
      categoryId: data['categoria'] ?? '',
      brandName: '', // Se llenará después
      categoryName: '', // Se llenará después
      price: (data['precio'] ?? 0).toDouble(),
      stock: data['stock'] ?? 0,
      imageUrl: data['imagen_url'] ?? '',
      isActive: data['estado'] == 'activo',
      createdAt: (data['creado_en'] as Timestamp).toDate(),
      updatedAt: (data['actualizado_en'] as Timestamp).toDate(),
    );
  }
}
