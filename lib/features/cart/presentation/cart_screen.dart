import 'dart:async';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import '../../../widgets/custom_app_bar.dart';
import '../data/cart_service.dart';
import '../data/models/cart_item_model.dart';
import 'location_picker_screen.dart';
import '../../products/data/recommendation_service.dart';
import '../../products/data/models/product_model.dart';

class CartScreen extends StatefulWidget {
  const CartScreen({super.key});

  @override
  State<CartScreen> createState() => _CartScreenState();
}

class _CartScreenState extends State<CartScreen> {
  final CartService _cart = CartService.instance;
  final RecommendationService _recommendationService = RecommendationService();
  List<ProductModel> _related = [];
  bool _isPurchasing = false;
  bool _loadingRelated = false;
  Timer? _debounceTimer;

  @override
  void initState() {
    super.initState();
    _cart.addListener(_onCartChanged);
    _loadRelated();
  }

  @override
  void dispose() {
    _cart.removeListener(_onCartChanged);
    _debounceTimer?.cancel();
    super.dispose();
  }

  void _onCartChanged() {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(seconds: 2), _loadRelated);
  }

  Future<void> _loadRelated() async {
    if (_loadingRelated) return;
    if (_cart.items.isEmpty) {
      if (_related.isNotEmpty) setState(() => _related = []);
      return;
    }
    _loadingRelated = true;
    try {
      final firstId = _cart.items.first.product.id;
      final related = await _recommendationService.getRelatedProducts(firstId, limit: 5);
      if (!mounted) return;
      setState(() => _related = related);
    } catch (_) {
      if (!mounted) return;
      setState(() => _related = []);
    } finally {
      _loadingRelated = false;
    }
  }

  Future<void> _purchase() async {
    if (_cart.isEmpty) return;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Confirmar compra'),
        content: Text(
          '¿Realizar compra por S/. ${_cart.totalAmount.toStringAsFixed(2)}?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Comprar'),
          ),
        ],
      ),
    );
    if (confirm != true) return;

    setState(() => _isPurchasing = true);
    _cart.removeListener(_onCartChanged);
    try {
      double userLat = -11.7775086;
      double userLng = -75.499446;
      String direccion = '';

      final useCurrent = await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => AlertDialog(
          title: const Text('Ubicación de entrega'),
          content: const Text(
            '¿Tu ubicación actual es donde deseas recibir el pedido?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('No, elegir dirección'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Sí, usar mi ubicación'),
            ),
          ],
        ),
      );

      if (useCurrent == true) {
        final permission = await Geolocator.checkPermission();
        if (permission == LocationPermission.denied) {
          await Geolocator.requestPermission();
        }
        final serviceEnabled = await Geolocator.isLocationServiceEnabled();
        if (permission != LocationPermission.denied &&
            permission != LocationPermission.deniedForever &&
            serviceEnabled) {
          try {
            final pos = await Geolocator.getCurrentPosition()
                .timeout(const Duration(seconds: 10));
            userLat = pos.latitude;
            userLng = pos.longitude;
          } catch (_) {}
        }
      } else if (useCurrent == false) {
        final result = await Navigator.push<Map<String, dynamic>>(
          context,
          MaterialPageRoute(
            builder: (_) => LocationPickerScreen(
              initialLat: userLat,
              initialLng: userLng,
            ),
          ),
        );
        if (result == null) {
          _cart.addListener(_onCartChanged);
          if (!mounted) return;
          setState(() => _isPurchasing = false);
          return;
        }
        userLat = result['lat'] as double;
        userLng = result['lng'] as double;
        direccion = result['direccion'] as String? ?? '';
      } else {
        _cart.addListener(_onCartChanged);
        if (!mounted) return;
        setState(() => _isPurchasing = false);
        return;
      }

      await _cart.purchase(userLat, userLng, direccion: direccion);
      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => Scaffold(
            appBar: AppBar(title: const Text('Compra exitosa')),
            body: const Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.check_circle, color: Colors.green, size: 80),
                  SizedBox(height: 16),
                  Text(
                    '¡Compra realizada con éxito!',
                    style:
                        TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    } catch (e) {
      _cart.addListener(_onCartChanged);
      if (!mounted) return;
      setState(() => _isPurchasing = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error al realizar compra: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const CustomAppBar(),
      body: _cart.isEmpty
          ? const Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.shopping_cart_outlined, size: 64,
                      color: Colors.grey),
                  SizedBox(height: 16),
                  Text('El carrito está vacío',
                      style: TextStyle(fontSize: 16, color: Colors.grey)),
                ],
              ),
            )
          : Column(
              children: [
                Expanded(
                  child: ListView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                    itemCount: _cart.items.length + (_related.isNotEmpty ? 1 : 0),
                    itemBuilder: (context, index) {
                      if (index < _cart.items.length) {
                        final item = _cart.items[index];
                        return _CartItemCard(
                          item: item,
                          onIncrement: () {
                            _cart.updateQuantity(
                                item.product.id, item.quantity + 1);
                          },
                          onDecrement: () {
                            _cart.updateQuantity(
                                item.product.id, item.quantity - 1);
                          },
                          onRemove: () => _cart.removeItem(item.product.id),
                        );
                      }
                      return _buildRelatedSection();
                    },
                  ),
                ),
                _buildBottomBar(),
              ],
            ),
    );
  }

  Widget _buildRelatedSection() {
    return Padding(
      padding: const EdgeInsets.only(top: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16),
            child: Text('Quienes compraron esto también llevaron',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
            ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            height: 120,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: _related.length,
              itemBuilder: (_, i) {
                final p = _related[i];
                return GestureDetector(
                  onTap: () {
                    final error = _cart.addItem(p);
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text(error ?? '"${p.name}" agregado al carrito')),
                      );
                    }
                  },
                  child: Container(
                    width: 100,
                    margin: const EdgeInsets.only(right: 10),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade50,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.grey.shade200),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        ClipRRect(
                          borderRadius: const BorderRadius.vertical(top: Radius.circular(8)),
                          child: SizedBox(
                            height: 60, width: double.infinity,
                            child: p.imageUrl.isNotEmpty
                                ? Image.network(p.imageUrl, cacheWidth: 150, fit: BoxFit.cover, errorBuilder: (_, e, s) => const Icon(Icons.image_outlined, color: Colors.grey))
                                : const Icon(Icons.image_outlined, color: Colors.grey),
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.all(4),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(p.name, maxLines: 2, overflow: TextOverflow.ellipsis,
                                style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w500),
                              ),
                              const SizedBox(height: 1),
                              Text('S/ ${p.price.toStringAsFixed(2)}',
                                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.green),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomBar() {
    final total = _cart.totalAmount;
    return Container(
      padding: EdgeInsets.fromLTRB(
        16, 10, 16, 10 + MediaQuery.of(context).padding.bottom,
      ),
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 8,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              'Total: S/. ${total.toStringAsFixed(2)}',
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(width: 12),
          GestureDetector(
            onTap: _isPurchasing ? null : _purchase,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: _isPurchasing ? Colors.green[300] : Colors.green,
                borderRadius: BorderRadius.circular(8),
              ),
              child: _isPurchasing
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white),
                    )
                  : const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.shopping_cart_checkout, size: 18,
                            color: Colors.white),
                        SizedBox(width: 6),
                        Text('Realizar compra',
                            style: TextStyle(color: Colors.white)),
                      ],
                    ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CartItemCard extends StatelessWidget {
  final CartItemModel item;
  final VoidCallback onIncrement;
  final VoidCallback onDecrement;
  final VoidCallback onRemove;

  const _CartItemCard({
    required this.item,
    required this.onIncrement,
    required this.onDecrement,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Container(
                width: 64,
                height: 64,
                color: Colors.grey[200],
                child: item.product.imageUrl.isNotEmpty
                    ? Image.network(
                        item.product.imageUrl,
                        cacheWidth: 64,
                        fit: BoxFit.cover,
                        errorBuilder: (_, e, s) => const Icon(
                            Icons.image_outlined, color: Colors.grey),
                      )
                    : const Icon(Icons.image_outlined, color: Colors.grey),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.product.name,
                    style: const TextStyle(
                        fontWeight: FontWeight.bold, fontSize: 14),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'S/. ${item.product.price.toStringAsFixed(2)}',
                    style: const TextStyle(
                        color: Colors.green,
                        fontWeight: FontWeight.bold,
                        fontSize: 14),
                  ),
                ],
              ),
            ),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                GestureDetector(
                  onTap: onDecrement,
                  child: const Padding(
                    padding: EdgeInsets.all(8),
                    child: Icon(Icons.remove_circle_outline, size: 20),
                  ),
                ),
                Text('${item.quantity}',
                    style: const TextStyle(
                        fontWeight: FontWeight.bold, fontSize: 15)),
                GestureDetector(
                  onTap: onIncrement,
                  child: const Padding(
                    padding: EdgeInsets.all(8),
                    child: Icon(Icons.add_circle_outline, size: 20),
                  ),
                ),
              ],
            ),
            const SizedBox(width: 4),
            Text(
              'S/. ${item.subtotal.toStringAsFixed(2)}',
              style:
                  const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
            ),
            GestureDetector(
              onTap: onRemove,
              child: const Padding(
                padding: EdgeInsets.all(8),
                child: Icon(Icons.delete_outline, size: 20,
                    color: Colors.red),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
