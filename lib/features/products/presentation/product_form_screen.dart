import 'package:flutter/material.dart';
import 'package:infoservice_cmq/features/products/data/product_service.dart';
import 'package:infoservice_cmq/features/products/data/models/product_model.dart';

class ProductFormScreen extends StatefulWidget {
  final ProductModel? product;

  const ProductFormScreen({super.key, this.product});

  @override
  State<ProductFormScreen> createState() => _ProductFormScreenState();
}

class _ProductFormScreenState extends State<ProductFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _productService = ProductService();

  final _nameController = TextEditingController();
  final _priceController = TextEditingController();
  final _stockController = TextEditingController();
  final _imageUrlController = TextEditingController();

  String? _selectedBrandId;
  String? _selectedCategoryId;
  bool _isLoadingData = true;
  bool _isSaving = false;

  List<Map<String, dynamic>> _brands = [];
  List<Map<String, dynamic>> _categories = [];

  bool get _isEditing => widget.product != null;

  @override
  void initState() {
    super.initState();
    if (_isEditing) {
      final p = widget.product!;
      _nameController.text = p.name;
      _priceController.text = p.price.toStringAsFixed(2);
      _stockController.text = p.stock.toString();
      _imageUrlController.text = p.imageUrl;
      _selectedBrandId = p.brandId;
      _selectedCategoryId = p.categoryId;
    }
    _loadData();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _priceController.dispose();
    _stockController.dispose();
    _imageUrlController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    try {
      final brands = await _productService.getBrandsList();
      final categories = await _productService.getCategoriesList();
      if (!mounted) return;
      setState(() {
        _brands = brands;
        _categories = categories;
        _isLoadingData = false;
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error al cargar datos: $e')),
      );
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedBrandId == null) {
      _showError('Selecciona una marca');
      return;
    }
    if (_selectedCategoryId == null) {
      _showError('Selecciona una categoría');
      return;
    }

    setState(() => _isSaving = true);
    try {
      if (_isEditing) {
        await _productService.updateProduct(
          id: widget.product!.id,
          name: _nameController.text.trim(),
          brandId: _selectedBrandId!,
          categoryId: _selectedCategoryId!,
          price: double.parse(_priceController.text.trim()),
          stock: int.parse(_stockController.text.trim()),
          imageUrl: _imageUrlController.text.trim(),
        );
      } else {
        await _productService.addProduct(
          name: _nameController.text.trim(),
          brandId: _selectedBrandId!,
          categoryId: _selectedCategoryId!,
          price: double.parse(_priceController.text.trim()),
          stock: int.parse(_stockController.text.trim()),
          imageUrl: _imageUrlController.text.trim(),
        );
      }
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      _showError('Error al guardar: $e');
      if (mounted) setState(() => _isSaving = false);
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditing ? 'Editar producto' : 'Nuevo producto'),
        actions: [
          TextButton(
            onPressed: (_isLoadingData || _isSaving) ? null : _save,
            child: _isSaving
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Guardar'),
          ),
        ],
      ),
      body: _isLoadingData
          ? const Center(child: CircularProgressIndicator())
          : Form(
              key: _formKey,
              child: ListView(
                padding: const EdgeInsets.all(20),
                children: [
                  TextFormField(
                    controller: _imageUrlController,
                    decoration: InputDecoration(
                      labelText: 'URL de imagen',
                      prefixIcon: const Icon(Icons.image_outlined),
                      suffixIcon:
                          _imageUrlController.text.isNotEmpty
                              ? IconButton(
                                  icon: const Icon(Icons.preview),
                                  onPressed: _showImagePreview,
                                )
                              : null,
                    ),
                    keyboardType: TextInputType.url,
                    style: const TextStyle(fontSize: 14),
                    onChanged: (_) => setState(() {}),
                  ),
                  if (_imageUrlController.text.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: Image.network(
                          _imageUrlController.text,
                          height: 120,
                          width: double.infinity,
                          fit: BoxFit.cover,
                          errorBuilder: (_, e, s) => Container(
                            height: 120,
                            color: Colors.grey[200],
                            child: const Center(
                              child: Icon(Icons.broken_image,
                                  color: Colors.grey),
                            ),
                          ),
                        ),
                      ),
                    ),
                  const SizedBox(height: 20),
                  TextFormField(
                    controller: _nameController,
                    decoration: const InputDecoration(
                      labelText: 'Nombre del producto',
                      prefixIcon: Icon(Icons.inventory_2_outlined),
                    ),
                    textCapitalization: TextCapitalization.words,
                    validator: (v) =>
                        v == null || v.trim().isEmpty
                            ? 'Ingresa el nombre'
                            : null,
                  ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<String>(
                    initialValue: _selectedBrandId,
                    decoration: const InputDecoration(
                      labelText: 'Marca',
                      prefixIcon: Icon(Icons.branding_watermark_outlined),
                    ),
                    items: _brands.map((brand) {
                      final name =
                          brand['nombre'] as String? ?? 'Sin nombre';
                      return DropdownMenuItem<String>(
                        value: brand['id'] as String,
                        child: Text(name),
                      );
                    }).toList(),
                    onChanged: (v) => setState(() => _selectedBrandId = v),
                    validator: (v) =>
                        v == null ? 'Selecciona una marca' : null,
                  ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<String>(
                    initialValue: _selectedCategoryId,
                    decoration: const InputDecoration(
                      labelText: 'Categoría',
                      prefixIcon: Icon(Icons.category_outlined),
                    ),
                    items: _categories.map((cat) {
                      final name =
                          cat['nombre'] as String? ?? 'Sin nombre';
                      return DropdownMenuItem<String>(
                        value: cat['id'] as String,
                        child: Text(name),
                      );
                    }).toList(),
                    onChanged: (v) => setState(() => _selectedCategoryId = v),
                    validator: (v) =>
                        v == null ? 'Selecciona una categoría' : null,
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: _priceController,
                          decoration: const InputDecoration(
                            labelText: 'Precio',
                            prefixIcon: Icon(Icons.monetization_on_outlined),
                            prefixText: 'S/. ',
                          ),
                          keyboardType: const TextInputType.numberWithOptions(
                              decimal: true),
                          validator: (v) {
                            if (v == null || v.trim().isEmpty) {
                              return 'Requerido';
                            }
                            final price = double.tryParse(v.trim());
                            if (price == null || price < 0) return 'Inválido';
                            return null;
                          },
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextFormField(
                          controller: _stockController,
                          decoration: const InputDecoration(
                            labelText: 'Stock',
                            prefixIcon: Icon(Icons.inventory_outlined),
                          ),
                          keyboardType: TextInputType.number,
                          validator: (v) {
                            if (v == null || v.trim().isEmpty) {
                              return 'Requerido';
                            }
                            final stock = int.tryParse(v.trim());
                            if (stock == null || stock < 0) return 'Inválido';
                            return null;
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 32),
                ],
              ),
            ),
    );
  }

  void _showImagePreview() {
    showDialog(
      context: context,
      builder: (_) => Dialog(
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: Image.network(
            _imageUrlController.text,
            fit: BoxFit.contain,
            errorBuilder: (_, e, s) => const Padding(
              padding: EdgeInsets.all(40),
              child: Icon(Icons.broken_image, size: 64, color: Colors.grey),
            ),
          ),
        ),
      ),
    );
  }
}
