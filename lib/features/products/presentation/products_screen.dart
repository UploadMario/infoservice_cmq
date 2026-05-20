import 'package:flutter/material.dart';
import 'package:infoservice_cmq/features/products/data/product_service.dart';
import 'package:infoservice_cmq/features/products/data/models/product_model.dart';

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

  @override
  void initState() {
    super.initState();
    _loadProducts();
  }

  Future<void> _loadProducts() async {
    _productService.getProducts().listen((products) {
      setState(() {
        _products = products;
        _filteredProducts = products;
        _applyFilters();
      });
    });
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Productos'),
        actions: [
          IconButton(
            icon: const Icon(Icons.filter_list),
            onPressed: _showFilterDialog,
          ),
        ],
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
                    padding: const EdgeInsets.all(16),
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      crossAxisSpacing: 16,
                      mainAxisSpacing: 16,
                      childAspectRatio:
                          0.7, // Ajusta la proporción para evitar desbordamiento vertical
                    ),
                    itemCount: _filteredProducts.length,
                    itemBuilder: (context, index) {
                      final product = _filteredProducts[index];
                      return _ProductCard(product: product);
                    },
                  ),
          ),
        ],
      ),
    );
  }

  void _showFilterDialog() {
    // Obtener nombres únicos de categorías y marcas
    final categoryNames = _products.map((p) => p.categoryName).toSet().toList();
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

  const _ProductCard({required this.product});

  @override
  Widget build(BuildContext context) {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      elevation: 2,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Imagen (espacio reservado)
          Container(
            height: 120,
            decoration: BoxDecoration(
              color: Colors.grey[200],
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(16),
              ),
              border: Border.all(color: Colors.grey[400]!),
            ),
            child: const Center(
              child: Icon(
                Icons.image_not_supported,
                color: Colors.grey,
                size: 40,
              ),
            ),
          ),
          // Contenido con padding y ScrollView para evitar overflow
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Nombre del producto (máximo 2 líneas)
                  Text(
                    product.name,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14, // Reducido para evitar desbordamiento
                    ),
                    maxLines: 2, // Límites a 2 líneas
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  // Precio
                  Text(
                    'S/. ${product.price.toStringAsFixed(2)}',
                    style: const TextStyle(
                      color: Colors.green,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  // Stock
                  Text(
                    'Stock: ${product.stock}',
                    style: const TextStyle(color: Colors.grey),
                  ),
                  const SizedBox(height: 8),
                  // Categoría (con Icon y texto en una línea)
                  Row(
                    children: [
                      const Icon(Icons.category, size: 16, color: Colors.blue),
                      const SizedBox(width: 4),
                      Expanded(
                        // <-- Expandido para evitar overflow
                        child: Text(
                          product.categoryName,
                          style: const TextStyle(fontSize: 12),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  // Marca (con Icon y texto en una línea)
                  Row(
                    children: [
                      const Icon(
                        Icons.branding_watermark,
                        size: 16,
                        color: Colors.orange,
                      ),
                      const SizedBox(width: 4),
                      Expanded(
                        // <-- Expandido para evitar overflow
                        child: Text(
                          product.brandName,
                          style: const TextStyle(fontSize: 12),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
