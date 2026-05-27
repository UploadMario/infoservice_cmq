import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

import 'models/cart_item_model.dart';
import '../../products/data/models/product_model.dart';

class CartService extends ChangeNotifier {
  CartService._();

  static final CartService instance = CartService._();

  final List<CartItemModel> _items = [];
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  List<CartItemModel> get items => List.unmodifiable(_items);
  int get itemCount => _items.fold(0, (total, item) => total + item.quantity);
  double get totalAmount => _items.fold(0.0, (total, item) => total + item.subtotal);
  bool get isEmpty => _items.isEmpty;

  String? addItem(ProductModel product) {
    if (product.stock <= 0) return 'Producto sin stock';

    final index = _items.indexWhere((item) => item.product.id == product.id);
    if (index >= 0) {
      if (_items[index].quantity >= product.stock) {
        return 'Stock máximo alcanzado';
      }
      _items[index].quantity++;
    } else {
      _items.add(CartItemModel(product: product));
    }
    notifyListeners();
    return null;
  }

  void removeItem(String productId) {
    _items.removeWhere((item) => item.product.id == productId);
    notifyListeners();
  }

  void updateQuantity(String productId, int quantity) {
    final index = _items.indexWhere((item) => item.product.id == productId);
    if (index < 0) return;
    if (quantity <= 0) {
      _items.removeAt(index);
    } else {
      _items[index].quantity = quantity.clamp(1, _items[index].product.stock);
    }
    notifyListeners();
  }

  void clear() {
    _items.clear();
    notifyListeners();
  }

  Future<Map<String, dynamic>> purchase() async {
    final user = _auth.currentUser;
    if (user == null) throw Exception('No hay sesión activa');

    final userDoc = await _firestore.collection('usuarios').doc(user.uid).get();
    final userData = userDoc.data();

    final productosData = _items.map((item) {
      return {
        'productoId': item.product.id,
        'nombre': item.product.name,
        'cantidad': item.quantity,
        'precioUnitario': item.product.price,
        'subtotal': item.subtotal,
      };
    }).toList();

    final total = totalAmount;

    final compraData = <String, dynamic>{
      'uid': user.uid,
      'usuarioNombre': userData?['nombre'] ?? user.displayName ?? '',
      'usuarioCorreo': userData?['correo'] ?? user.email ?? '',
      'total': total,
      'fecha': FieldValue.serverTimestamp(),
      'estado': 'completado',
      'productos': productosData,
    };

    final docRef =
        await _firestore.collection('historial_compras').add(compraData);

    final result = <String, dynamic>{
      'id': docRef.id,
      'productos': productosData,
      'total': total,
      'fecha': DateTime.now(),
      'usuarioNombre': userData?['nombre'] ?? user.displayName ?? '',
    };

    clear();
    return result;
  }

  Stream<QuerySnapshot> getPurchaseHistory() {
    final user = _auth.currentUser;
    if (user == null) return const Stream.empty();
    return _firestore
        .collection('historial_compras')
        .where('uid', isEqualTo: user.uid)
        .orderBy('fecha', descending: true)
        .snapshots();
  }
}
