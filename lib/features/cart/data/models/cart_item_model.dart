import 'package:infoservice_cmq/features/products/data/models/product_model.dart';

class CartItemModel {
  final ProductModel product;
  int quantity;

  CartItemModel({required this.product, this.quantity = 1});

  double get subtotal => product.price * quantity;
}
