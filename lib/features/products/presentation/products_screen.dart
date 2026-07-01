import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:infoservice_cmq/features/products/data/product_service.dart';
import 'package:infoservice_cmq/features/products/data/models/product_model.dart';
import 'package:infoservice_cmq/features/products/data/recommendation_service.dart';
import 'package:infoservice_cmq/features/cart/data/cart_service.dart';
import 'package:infoservice_cmq/features/cart/presentation/cart_badge_icon.dart';
import 'package:infoservice_cmq/features/cart/presentation/cart_screen.dart';
import 'package:infoservice_cmq/features/favorites/data/favorites_service.dart';
import 'package:infoservice_cmq/widgets/custom_app_bar.dart';
import 'package:url_launcher/url_launcher.dart';

class ProductsScreen extends StatefulWidget {
  const ProductsScreen({super.key});

  @override
  State<ProductsScreen> createState() => _ProductsScreenState();
}

class _ProductsScreenState extends State<ProductsScreen> {
  final ProductService _productService = ProductService();
  final RecommendationService _recommendationService = RecommendationService();
  final FavoritesService _favorites = FavoritesService.instance;
  List<ProductModel> _products = [];
  List<ProductModel> _filteredProducts = [];
  String _selectedCategory = 'Todas';
  String _selectedBrand = 'Todas';
  double _minPrice = 0;
  double _maxPrice = 10000;
  bool _showFavoritesOnly = false;
  bool _isLoading = true;
  final TextEditingController _searchController = TextEditingController();
  StreamSubscription? _subscription;

  @override
  void initState() {
    super.initState();
    _favorites.init();
    _favorites.addListener(_onFavoritesChanged);
    _subscription = _productService.getProducts().listen(
      (products) {
        if (!mounted) return;
        setState(() {
          _isLoading = false;
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
    _favorites.removeListener(_onFavoritesChanged);
    _searchController.dispose();
    super.dispose();
  }

  void _onFavoritesChanged() {
    if (mounted) setState(() {});
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
        final matchesFavorites =
            !_showFavoritesOnly || _favorites.isFavorite(product.id);
        return matchesCategory &&
            matchesBrand &&
            matchesPrice &&
            matchesSearch &&
            matchesFavorites;
      }).toList();
    });
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

  void _showProductDetail(ProductModel product) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return DraggableScrollableSheet(
          initialChildSize: 0.7,
          minChildSize: 0.4,
          maxChildSize: 0.9,
          expand: false,
          builder: (ctx, scrollController) {
            return SingleChildScrollView(
              controller: scrollController,
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Container(
                        width: 40, height: 4,
                        decoration: BoxDecoration(
                          color: Colors.grey[300],
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Stack(
                        children: [
                          AspectRatio(
                            aspectRatio: 16 / 9,
                            child: product.imageUrl.isNotEmpty
                                ? _detailImage(product.imageUrl)
                                : _storePlaceholder(),
                          ),
                          if (product.stock <= 0)
                            Positioned.fill(
                              child: Container(
                                color: Colors.black54,
                                child: const Center(
                                  child: Text('AGOTADO',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 24,
                                      fontWeight: FontWeight.bold,
                                    )),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(product.name,
                      style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Text('S/ ${product.price.toStringAsFixed(2)}',
                          style: const TextStyle(
                            fontSize: 24, fontWeight: FontWeight.bold, color: Colors.green,
                          ),
                        ),
                        const Spacer(),
                        Text('Stock: ${product.stock}',
                          style: TextStyle(fontSize: 14, color: product.stock > 0 ? Colors.grey : Colors.red),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 6,
                      children: [
                        if (product.categoryName.isNotEmpty)
                          _detailChip(product.categoryName, Colors.blue),
                        if (product.brandName.isNotEmpty)
                          _detailChip(product.brandName, Colors.orange),
                      ],
                    ),
                    const SizedBox(height: 20),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        icon: const Icon(Icons.add_shopping_cart),
                        label: const Text('Agregar al carrito'),
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        onPressed: product.stock > 0
                            ? () {
                                _addToCart(product);
                                Navigator.pop(ctx);
                              }
                            : null,
                      ),
                    ),
                    const SizedBox(height: 24),
                    FutureBuilder<List<ProductModel>>(
                      future: _recommendationService.getRelatedProducts(product.id),
                      builder: (ctx, snapshot) {
                        if (!snapshot.hasData || snapshot.data!.isEmpty) {
                          return const SizedBox.shrink();
                        }
                        final related = snapshot.data!;
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Quienes compraron esto también llevaron',
                              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                            ),
                            const SizedBox(height: 12),
                            SizedBox(
                              height: 160,
                              child: ListView.separated(
                                scrollDirection: Axis.horizontal,
                                itemCount: related.length,
                                separatorBuilder: (_, __) => const SizedBox(width: 12),
                                itemBuilder: (_, i) {
                                  final r = related[i];
                                  return GestureDetector(
                                    onTap: () {
                                      _addToCart(r);
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(content: Text('"${r.name}" agregado al carrito')),
                                      );
                                    },
                                    child: Container(
                                      width: 120,
                                      decoration: BoxDecoration(
                                        color: Colors.grey.shade50,
                                        borderRadius: BorderRadius.circular(10),
                                        border: Border.all(color: Colors.grey.shade200),
                                      ),
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          ClipRRect(
                                            borderRadius: const BorderRadius.vertical(top: Radius.circular(10)),
                                            child: SizedBox(
                                              height: 80,
                                              width: double.infinity,
                                              child: r.imageUrl.isNotEmpty
                                                  ? _detailImage(r.imageUrl)
                                                  : _storePlaceholder(),
                                            ),
                                          ),
                                          Padding(
                                            padding: const EdgeInsets.all(6),
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                Text(r.name, maxLines: 2, overflow: TextOverflow.ellipsis,
                                                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w500),
                                                ),
                                                const SizedBox(height: 2),
                                                Text('S/ ${r.price.toStringAsFixed(2)}',
                                                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.green),
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
                        );
                      },
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _detailImage(String url) {
    if (url.startsWith('data:')) {
      try {
        final parts = url.split(',');
        if (parts.length >= 2) {
          return Image.memory(base64Decode(parts[1]), fit: BoxFit.cover, width: double.infinity, errorBuilder: (_, e, s) => _storePlaceholder());
        }
      } catch (_) {}
    }
    return Image.network(url, fit: BoxFit.cover, width: double.infinity, errorBuilder: (_, e, s) => _storePlaceholder());
  }

  Widget _storePlaceholder() {
    return const Center(child: Icon(Icons.image_outlined, color: Colors.grey, size: 32));
  }

  Widget _detailChip(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Text(label, style: TextStyle(fontSize: 12, color: color, fontWeight: FontWeight.w500)),
    );
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
      appBar: CustomAppBar(
        actions: [
          CartBadgeIcon(onTap: _openCart),
          IconButton(
            icon: Icon(
              _showFavoritesOnly
                  ? Icons.favorite
                  : Icons.favorite_outline_rounded,
              color: _showFavoritesOnly ? Colors.red : null,
            ),
            onPressed: () {
              setState(() => _showFavoritesOnly = !_showFavoritesOnly);
              _applyFilters();
            },
            tooltip: _showFavoritesOnly
                ? 'Mostrar todos'
                : 'Solo favoritos',
          ),
          IconButton(
            icon: const Icon(Icons.filter_list),
            onPressed: _showFilterDialog,
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          final uri = Uri.parse('https://wa.me/51964834558');
          try {
            await launchUrl(uri, mode: LaunchMode.externalApplication);
          } catch (e) {
            await launchUrl(uri, mode: LaunchMode.platformDefault);
          }
        },
        backgroundColor: const Color(0xFF25D366),
        child: const Icon(Icons.chat, color: Colors.white),
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
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _filteredProducts.isEmpty
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
                        isFavorite: _favorites.isFavorite(product.id),
                        onTap: () => _showProductDetail(product),
                        onToggleFavorite: () =>
                            _favorites.toggle(product.id),
                        onAddToCart: () => _addToCart(product),
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
    final maxProductPrice = _products.isEmpty
        ? 2000.0
        : _products
            .map((p) => p.price)
            .reduce((a, b) => a > b ? a : b)
            .ceilToDouble();
    final effectiveMax = maxProductPrice < 10 ? 10.0 : maxProductPrice;

    if (_minPrice > effectiveMax) _minPrice = 0;
    if (_maxPrice > effectiveMax) _maxPrice = effectiveMax;
    if (_minPrice > _maxPrice) _minPrice = 0;

    TextEditingController minController =
        TextEditingController(text: _minPrice.toStringAsFixed(0));
    TextEditingController maxController =
        TextEditingController(text: _maxPrice.toStringAsFixed(0));

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('Filtrar productos'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Categoría',
                        style: TextStyle(fontSize: 12, color: Colors.grey)),
                    const SizedBox(height: 4),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey[400]!),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          value: _selectedCategory,
                          isExpanded: true,
                          isDense: true,
                          items: ['Todas', ...categoryNames]
                              .map((category) {
                            return DropdownMenuItem<String>(
                              value: category,
                              child: Text(category,
                                  overflow: TextOverflow.ellipsis),
                            );
                          }).toList(),
                          onChanged: (value) {
                            setState(() => _selectedCategory = value!);
                            _applyFilters();
                            Navigator.pop(context);
                          },
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    const Text('Marca',
                        style: TextStyle(fontSize: 12, color: Colors.grey)),
                    const SizedBox(height: 4),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey[400]!),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          value: _selectedBrand,
                          isExpanded: true,
                          isDense: true,
                          items: ['Todas', ...brandNames].map((brand) {
                            return DropdownMenuItem<String>(
                              value: brand,
                              child: Text(brand,
                                  overflow: TextOverflow.ellipsis),
                            );
                          }).toList(),
                          onChanged: (value) {
                            setState(() => _selectedBrand = value!);
                            _applyFilters();
                            Navigator.pop(context);
                          },
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Text('Rango de precio',
                        style: TextStyle(fontWeight: FontWeight.w500)),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        SizedBox(
                          width: 80,
                          child: TextField(
                            controller: minController,
                            decoration: const InputDecoration(
                              prefixText: 'S/ ',
                              isDense: true,
                              contentPadding: EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 8),
                              border: OutlineInputBorder(),
                            ),
                            keyboardType: TextInputType.number,
                            onChanged: (v) {
                              final val = double.tryParse(v);
                              if (val != null && val >= 0) {
                                setDialogState(() => _minPrice = val);
                              }
                            },
                          ),
                        ),
                        Expanded(
                          child: RangeSlider(
                            values: RangeValues(_minPrice, _maxPrice),
                            min: 0,
                            max: effectiveMax,
                            labels: RangeLabels(
                              'S/ ${_minPrice.toStringAsFixed(0)}',
                              'S/ ${_maxPrice.toStringAsFixed(0)}',
                            ),
                            onChanged: (values) {
                              setDialogState(() {
                                _minPrice = values.start;
                                _maxPrice = values.end;
                              });
                              minController.text =
                                  values.start.toStringAsFixed(0);
                              maxController.text =
                                  values.end.toStringAsFixed(0);
                            },
                          ),
                        ),
                        SizedBox(
                          width: 80,
                          child: TextField(
                            controller: maxController,
                            decoration: const InputDecoration(
                              prefixText: 'S/ ',
                              isDense: true,
                              contentPadding: EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 8),
                              border: OutlineInputBorder(),
                            ),
                            keyboardType: TextInputType.number,
                            onChanged: (v) {
                              final val = double.tryParse(v);
                              if (val != null && val >= 0) {
                                setDialogState(() => _maxPrice = val);
                              }
                            },
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: () {
                          _applyFilters();
                          Navigator.pop(context);
                        },
                        child: const Text('Aplicar filtros'),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}

class _ProductCard extends StatelessWidget {
  final ProductModel product;
  final bool isFavorite;
  final VoidCallback onTap;
  final VoidCallback onToggleFavorite;
  final VoidCallback onAddToCart;

  const _ProductCard({
    required this.product,
    required this.isFavorite,
    required this.onTap,
    required this.onToggleFavorite,
    required this.onAddToCart,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      elevation: 2,
      child: InkWell(
        onTap: onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
          AspectRatio(
            aspectRatio: 16 / 9,
            child: Stack(
              children: [
                Container(
                  color: Colors.grey[200],
                  child: product.imageUrl.isNotEmpty
                      ? _productImage(product.imageUrl)
                      : _imagePlaceholder(),
                ),
                Positioned(
                  top: 4,
                  right: 4,
                  child: GestureDetector(
                    onTap: onToggleFavorite,
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.85),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        isFavorite ? Icons.favorite : Icons.favorite_border,
                        size: 18,
                        color: isFavorite ? Colors.red : Colors.grey,
                      ),
                    ),
                  ),
                ),
              ],
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
          InkWell(
            onTap: product.stock > 0 ? onAddToCart : null,
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(
                color: product.stock > 0 ? Colors.blue : Colors.grey[300],
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.add_shopping_cart_outlined,
                    size: 18,
                    color: Colors.white,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    product.stock > 0 ? 'Agregar al carrito' : 'Sin stock',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
        ),
      ),
    );
  }

  Widget _productImage(String url) {
    if (url.startsWith('data:')) {
      try {
        final parts = url.split(',');
        if (parts.length >= 2) {
          return Image.memory(
            base64Decode(parts[1]),
            fit: BoxFit.cover,
            width: double.infinity,
            errorBuilder: (_, e, s) => _imagePlaceholder(),
          );
        }
      } catch (_) {}
    }
    return Image.network(
      url,
      fit: BoxFit.cover,
      width: double.infinity,
      errorBuilder: (_, e, s) => _imagePlaceholder(),
    );
  }

  Widget _imagePlaceholder() {
    return const Center(
      child: Icon(Icons.image_outlined, color: Colors.grey, size: 32),
    );
  }

  Widget _buildChip(String label, Color color) {
    return Container(
      constraints: const BoxConstraints(maxWidth: 120),
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          fontSize: 9,
          color: color,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }
}
