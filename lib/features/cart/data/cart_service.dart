import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

import 'models/cart_item_model.dart';
import '../../products/data/models/product_model.dart';

class CartService extends ChangeNotifier {
  CartService._();

  static final CartService instance = CartService._();

  static const double _businessLat = -11.7775086;
  static const double _businessLng = -75.499446;

  final List<CartItemModel> _items = [];
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  List<CartItemModel> get items => List.unmodifiable(_items);
  int get itemCount => _items.fold(0, (total, item) => total + item.quantity);
  double get totalAmount => _items.fold(0.0, (total, item) => total + item.subtotal);
  bool get isEmpty => _items.isEmpty;

  double _haversineDistance(double lat1, double lng1, double lat2, double lng2) {
    const R = 6371000;
    final dLat = (lat2 - lat1) * pi / 180;
    final dLng = (lng2 - lng1) * pi / 180;
    final a = sin(dLat / 2) * sin(dLat / 2) +
        cos(lat1 * pi / 180) * cos(lat2 * pi / 180) * sin(dLng / 2) * sin(dLng / 2);
    return R * 2 * atan2(sqrt(a), sqrt(1 - a));
  }

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

  Future<Map<String, dynamic>> purchase(double userLat, double userLng, {String direccion = ''}) async {
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
    final distancia = _haversineDistance(
      _businessLat, _businessLng, userLat, userLng,
    );
    final duracion = (distancia / 10).round();

    final compraData = <String, dynamic>{
      'uid': user.uid,
      'usuarioNombre': userData?['nombre'] ?? user.displayName ?? '',
      'usuarioCorreo': userData?['correo'] ?? user.email ?? '',
      'total': total,
      'fecha': FieldValue.serverTimestamp(),
      'estado': 'preparando',
      'productos': productosData,
      'ubicacionNegocio': GeoPoint(_businessLat, _businessLng),
      'ubicacionUsuario': GeoPoint(userLat, userLng),
      'direccion': direccion,
      'fechaPedido': FieldValue.serverTimestamp(),
      'fechaInicioEnvio': null,
      'fechaCompletado': null,
      'distancia': distancia.round(),
      'duracion': duracion,
    };

    final docRef =
        await _firestore.collection('historial_compras').add(compraData);

    final batch = _firestore.batch();
    for (final item in _items) {
      final ref = _firestore.collection('productos').doc(item.product.id);
      batch.update(ref, {'stock': FieldValue.increment(-item.quantity)});
    }
    await batch.commit();

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

  Future<void> cancelOrder(String orderId) async {
    final orderDoc = await _firestore.collection('historial_compras').doc(orderId).get();
    final data = orderDoc.data();
    final productos = (data?['productos'] as List<dynamic>?) ?? [];

    final batch = _firestore.batch();
    batch.update(orderDoc.reference, {'estado': 'cancelado'});
    for (final p in productos) {
      final pMap = p as Map<String, dynamic>;
      final id = pMap['productoId'] as String?;
      final cant = (pMap['cantidad'] as num?)?.toInt() ?? 0;
      if (id != null && cant > 0) {
        batch.update(_firestore.collection('productos').doc(id), {
          'stock': FieldValue.increment(cant),
        });
      }
    }
    await batch.commit();
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
