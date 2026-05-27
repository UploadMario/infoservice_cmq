import 'dart:async';
import 'package:flutter/material.dart';
import 'package:infoservice_cmq/features/products/data/product_service.dart';
import 'package:infoservice_cmq/features/products/data/models/product_model.dart';
import 'package:infoservice_cmq/features/cart/data/cart_service.dart';
import 'package:infoservice_cmq/features/cart/presentation/cart_badge_icon.dart';
import 'package:infoservice_cmq/features/cart/presentation/cart_screen.dart';
import 'product_form_screen.dart';

class ProductsScreen extends StatefulWidget {
  const ProductsScreen({super.key});

  @override
  State<ProductsScreen> createState() => _ProductsScreenState();
}

class _ProductsScreenState extends State<ProductsScreen> {
  final ProductService _productService = ProductService();
  List<ProductModel> _products = [];
  List<ProductModel> _filteredProducts = [];
  String _selectedCategory = 'Todas';
  String _selectedBrand = 'Todas';
  double _minPrice = 0;
  double _maxPrice = 10000;
  final TextEditingController _searchController = TextEditingController();
  StreamSubscription? _subscription;

  @override
  void initState() {
    super.initState();
    _subscription = _productService.getProducts().listen(
      (products) {
        if (!mounted) return;
        setState(() {
          _products = products;
          _filteredProducts = products;
          _applyFilters();
        });
      },
      onError: (error) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al cargar productos: $error')),
        );
      },
    );
  }

  @override
  void dispose() {
    _subscription?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  void _applyFilters() {
    setState(() {
      _filteredProducts = _products.where((product) {
        final matchesCategory =
            _selectedCategory == 'Todas' ||
            product.categoryName == _selectedCategory;
        final matchesBrand =
            _selectedBrand == 'Todas' || product.brandName == _selectedBrand;
        final matchesPrice =
            product.price >= _minPrice && product.price <= _maxPrice;
        final matchesSearch = product.name.toLowerCase().contains(
          _searchController.text.toLowerCase(),
        );
        return matchesCategory && matchesBrand && matchesPrice && matchesSearch;
      }).toList();
    });
  }

  Future<void> _deleteProduct(ProductModel product) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Eliminar producto'),
        content: Text('¿Desactivar "${product.name}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Eliminar', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (confirm != true) return;
    try {
      await _productService.deactivateProduct(product.id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('"${product.name}" desactivado')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }

  void _openForm([ProductModel? product]) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ProductFormScreen(product: product),
        fullscreenDialog: true,
      ),
    );
  }

  void _addToCart(ProductModel product) {
    final error = CartService.instance.addItem(product);
    if (error != null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(error)),
        );
      }
      return;
    }
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('"${product.name}" agregado al carrito')),
      );
    }
  }

  void _openCart() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const CartScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Productos'),
        actions: [
          CartBadgeIcon(onTap: _openCart),
          IconButton(
            icon: const Icon(Icons.filter_list),
            onPressed: _showFilterDialog,
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _openForm(),
        child: const Icon(Icons.add),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                labelText: 'Buscar productos',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              onChanged: (value) => _applyFilters(),
            ),
          ),
          Expanded(
            child: _filteredProducts.isEmpty
                ? const Center(child: Text('No hay productos disponibles.'))
                : GridView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 80),
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      crossAxisSpacing: 12,
                      mainAxisSpacing: 12,
                      childAspectRatio: 0.6,
                    ),
                    itemCount: _filteredProducts.length,
                    itemBuilder: (context, index) {
                      final product = _filteredProducts[index];
                      return _ProductCard(
                        product: product,
                        onAddToCart: () => _addToCart(product),
                        onEdit: () => _openForm(product),
                        onDelete: () => _deleteProduct(product),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  void _showFilterDialog() {
    final categoryNames =
        _products.map((p) => p.categoryName).toSet().toList();
    final brandNames = _products.map((p) => p.brandName).toSet().toList();

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Filtrar productos'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<String>(
                  value: _selectedCategory,
                  items: ['Todas', ...categoryNames].map((category) {
                    return DropdownMenuItem<String>(
                      value: category,
                      child: Text(category),
                    );
                  }).toList(),
                  onChanged: (value) {
                    setState(() => _selectedCategory = value!);
                    _applyFilters();
                    Navigator.pop(context);
                  },
                  decoration: const InputDecoration(labelText: 'Categoría'),
                ),
                DropdownButtonFormField<String>(
                  value: _selectedBrand,
                  items: ['Todas', ...brandNames].map((brand) {
                    return DropdownMenuItem<String>(
                      value: brand,
                      child: Text(brand),
                    );
                  }).toList(),
                  onChanged: (value) {
                    setState(() => _selectedBrand = value!);
                    _applyFilters();
                    Navigator.pop(context);
                  },
                  decoration: const InputDecoration(labelText: 'Marca'),
                ),
                RangeSlider(
                  values: RangeValues(_minPrice, _maxPrice),
                  min: 0,
                  max: 10000,
                  divisions: 100,
                  labels: RangeLabels(
                    'S/. ${_minPrice.toStringAsFixed(2)}',
                    'S/. ${_maxPrice.toStringAsFixed(2)}',
                  ),
                  onChanged: (values) {
                    setState(() {
                      _minPrice = values.start;
                      _maxPrice = values.end;
                    });
                  },
                  onChangeEnd: (values) {
                    _applyFilters();
                    Navigator.pop(context);
                  },
                ),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: () {
                    _applyFilters();
                    Navigator.pop(context);
                  },
                  child: const Text('Aplicar filtros'),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _ProductCard extends StatelessWidget {
  final ProductModel product;
  final VoidCallback onAddToCart;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _ProductCard({
    required this.product,
    required this.onAddToCart,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      elevation: 2,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AspectRatio(
            aspectRatio: 16 / 9,
            child: Container(
              color: Colors.grey[200],
              child: product.imageUrl.isNotEmpty
                  ? Image.network(
                      product.imageUrl,
                      fit: BoxFit.cover,
                      errorBuilder: (_, e, s) => _imagePlaceholder(),
                    )
                  : _imagePlaceholder(),
            ),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(10, 8, 10, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    product.name,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'S/. ${product.price.toStringAsFixed(2)}',
                    style: const TextStyle(
                      color: Colors.green,
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Stock: ${product.stock}',
                    style: const TextStyle(color: Colors.grey, fontSize: 11),
                  ),
                  const Spacer(),
                  if (product.categoryName.isNotEmpty ||
                      product.brandName.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Wrap(
                        spacing: 4,
                        runSpacing: 2,
                        children: [
                          if (product.categoryName.isNotEmpty)
                            _buildChip(product.categoryName, Colors.blue),
                          if (product.brandName.isNotEmpty)
                            _buildChip(product.brandName, Colors.orange),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ),
          Divider(height: 1, color: Colors.grey[300]),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              IconButton(
                icon: const Icon(Icons.add_shopping_cart_outlined, size: 18),
                onPressed: product.stock > 0 ? onAddToCart : null,
                tooltip: product.stock > 0 ? 'Agregar al carrito' : 'Sin stock',
                color: product.stock > 0 ? Colors.blue : Colors.grey,
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    icon: const Icon(Icons.edit_outlined, size: 18),
                    onPressed: onEdit,
                    tooltip: 'Editar',
                  ),
                  IconButton(
                    icon: const Icon(Icons.delete_outline, size: 18,
                        color: Colors.red),
                    onPressed: onDelete,
                    tooltip: 'Eliminar',
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _imagePlaceholder() {
    return const Center(
      child: Icon(Icons.image_outlined, color: Colors.grey, size: 32),
    );
  }

  Widget _buildChip(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 9,
          color: color,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }
}
