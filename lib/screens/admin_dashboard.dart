import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class AdminDashboard extends StatefulWidget {
  const AdminDashboard({super.key});

  @override
  State<AdminDashboard> createState() => _AdminDashboardState();
}

class _AdminDashboardState extends State<AdminDashboard> {
  final _auth = FirebaseAuth.instance;
  final _firestore = FirebaseFirestore.instance;

  final _nameController = TextEditingController();
  final _priceController = TextEditingController();
  final _stockController = TextEditingController();
  final _imageUrlController = TextEditingController();
  final _searchController = TextEditingController();

  String? _editingId;
  String? _selectedBrandId;
  String? _selectedCategoryId;
  bool _frameReady = false;

  List<Map<String, dynamic>> _brands = [];
  List<Map<String, dynamic>> _categories = [];
  bool _brandsLoaded = false;

  String? _filterBrandId;
  String? _filterCategoryId;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) setState(() => _frameReady = true);
    });
  }

  @override
  void dispose() {
    _nameController.dispose();
    _priceController.dispose();
    _stockController.dispose();
    _imageUrlController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadBrandsAndCategories() async {
    if (_brandsLoaded) return;
    if (_auth.currentUser == null) return;
    try {
      final results = await Future.wait([
        _firestore.collection('marcas').get(),
        _firestore.collection('categorias_nivel3').get(),
      ]);
      _brands = (results[0] as QuerySnapshot).docs.map((d) {
        return {'id': d.id, 'nombre': (d.data() as Map)['nombre'] ?? ''};
      }).toList();
      _categories = (results[1] as QuerySnapshot).docs.map((d) {
        return {'id': d.id, 'nombre': (d.data() as Map)['nombre'] ?? ''};
      }).toList();
      _brandsLoaded = true;
      if (mounted) setState(() {});
    } catch (e) {
      debugPrint('Error cargando marcas/categorias: $e');
    }
  }

  String _resolveName(List<Map<String, dynamic>> list, String? id) {
    if (id == null || id.isEmpty) return '—';
    final found = list.firstWhere((e) => e['id'] == id,
        orElse: () => {'nombre': '—'});
    return found['nombre'] as String;
  }

  Future<void> _guardarProducto() async {
    final nombre = _nameController.text.trim();
    final precio = double.tryParse(_priceController.text) ?? 0;
    final stock = int.tryParse(_stockController.text) ?? 0;
    if (nombre.isEmpty) return;

    final ref = _firestore.collection('productos');
    final data = {
      'nombre': nombre,
      'precio': precio,
      'stock': stock,
      'marca': _selectedBrandId ?? '',
      'categoria': _selectedCategoryId ?? '',
      'imagen_url': _imageUrlController.text.trim(),
      'actualizado_en': FieldValue.serverTimestamp(),
    };
    try {
      if (_editingId == null) {
        data['estado'] = 'activo';
        data['creado_en'] = FieldValue.serverTimestamp();
        await ref.add(data);
      } else {
        await ref.doc(_editingId).update(data);
      }
    } catch (e) {
      debugPrint('Error guardando producto: $e');
    }
  }

  Future<bool?> _showProductForm({Map<String, dynamic>? product, String? id}) async {
    if (product != null) {
      _nameController.text = product['nombre'] ?? '';
      _priceController.text = (product['precio'] ?? '').toString();
      _stockController.text = (product['stock'] ?? '').toString();
      _imageUrlController.text = product['imagen_url'] ?? '';
      final marca = product['marca'] as String?;
      _selectedBrandId = (marca == null || marca.isEmpty) ? null : marca;
      final cat = product['categoria'] as String?;
      _selectedCategoryId = (cat == null || cat.isEmpty) ? null : cat;
      _editingId = id;
    } else {
      _nameController.clear();
      _priceController.clear();
      _stockController.clear();
      _imageUrlController.clear();
      _selectedBrandId = null;
      _selectedCategoryId = null;
      _editingId = null;
    }

    final formKey = GlobalKey<FormState>();
    String? localBrandId = _selectedBrandId;
    String? localCategoryId = _selectedCategoryId;
    bool loading = false;

    return showDialog<bool>(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setDialogState) {
            return AlertDialog(
              title: Text(_editingId == null ? 'Nuevo Producto' : 'Editar Producto'),
              content: SizedBox(
                width: 480,
                child: Form(
                  key: formKey,
                  child: ListView(
                    shrinkWrap: true,
                    children: [
                      TextFormField(
                        controller: _nameController,
                        decoration: const InputDecoration(
                          labelText: 'Nombre del producto',
                          prefixIcon: Icon(Icons.inventory_2_outlined),
                        ),
                        textCapitalization: TextCapitalization.words,
                        validator: (v) =>
                            v == null || v.trim().isEmpty ? 'Ingresa el nombre' : null,
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _imageUrlController,
                        decoration: const InputDecoration(
                          labelText: 'URL de imagen',
                          prefixIcon: Icon(Icons.image_outlined),
                        ),
                        keyboardType: TextInputType.url,
                        onChanged: (_) => setDialogState(() {}),
                      ),
                      if (_imageUrlController.text.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: Image.network(
                            _imageUrlController.text,
                            height: 100,
                            width: double.infinity,
                            fit: BoxFit.cover,
                            errorBuilder: (_, e, s) => Container(
                              height: 100,
                              color: Colors.grey[200],
                              child: const Center(
                                child: Icon(Icons.broken_image, color: Colors.grey),
                              ),
                            ),
                          ),
                        ),
                      ],
                      const SizedBox(height: 16),
                      DropdownButtonFormField<String>(
                        initialValue: localBrandId,
                        decoration: const InputDecoration(
                          labelText: 'Marca',
                          prefixIcon: Icon(Icons.branding_watermark_outlined),
                        ),
                        items: [
                          const DropdownMenuItem(
                            value: null,
                            child: Text('Seleccionar marca'),
                          ),
                          ..._brands.map((b) => DropdownMenuItem(
                                value: b['id'] as String,
                                child: Text(b['nombre'] as String),
                              )),
                        ],
                        onChanged: (v) => setDialogState(() => localBrandId = v),
                        validator: (v) => v == null ? 'Selecciona una marca' : null,
                      ),
                      const SizedBox(height: 16),
                      DropdownButtonFormField<String>(
                        initialValue: localCategoryId,
                        decoration: const InputDecoration(
                          labelText: 'Categoría',
                          prefixIcon: Icon(Icons.category_outlined),
                        ),
                        items: [
                          const DropdownMenuItem(
                            value: null,
                            child: Text('Seleccionar categoría'),
                          ),
                          ..._categories.map((c) => DropdownMenuItem(
                                value: c['id'] as String,
                                child: Text(c['nombre'] as String),
                              )),
                        ],
                        onChanged: (v) => setDialogState(() => localCategoryId = v),
                        validator: (v) => v == null ? 'Selecciona una categoría' : null,
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: TextFormField(
                              controller: _priceController,
                              decoration: const InputDecoration(
                                labelText: 'Precio (S/.)',
                                prefixIcon: Icon(Icons.monetization_on_outlined),
                              ),
                              keyboardType:
                                  const TextInputType.numberWithOptions(decimal: true),
                              validator: (v) {
                                if (v == null || v.trim().isEmpty) return 'Requerido';
                                final p = double.tryParse(v.trim());
                                if (p == null || p < 0) return 'Inválido';
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
                                if (v == null || v.trim().isEmpty) return 'Requerido';
                                final s = int.tryParse(v.trim());
                                if (s == null || s < 0) return 'Inválido';
                                return null;
                              },
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('Cancelar'),
                ),
                ElevatedButton(
                  onPressed: loading
                      ? null
                      : () async {
                          if (!formKey.currentState!.validate()) return;
                          setDialogState(() => loading = true);
                          _selectedBrandId = localBrandId;
                          _selectedCategoryId = localCategoryId;
                          await _guardarProducto();
                          _nameController.clear();
                          _priceController.clear();
                          _stockController.clear();
                          _imageUrlController.clear();
                          _selectedBrandId = null;
                          _selectedCategoryId = null;
                          _editingId = null;
                          if (ctx.mounted) Navigator.pop(ctx, true);
                        },
                  child: loading
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Guardar'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _eliminarProducto(String id) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Eliminar producto'),
        content: const Text('¿Estás seguro de eliminar este producto?'),
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
    if (confirm == true) {
      try {
        await _firestore.collection('productos').doc(id).delete();
      } catch (e) {
        debugPrint('Error eliminando producto: $e');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_frameReady) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }
    return StreamBuilder<User?>(
      stream: _auth.authStateChanges(),
      builder: (context, snapshot) {
        if (snapshot.hasError) return const _AdminLoginPage();
        if (snapshot.hasData) return _buildDashboard();
        return const _AdminLoginPage();
      },
    );
  }

  Widget _buildDashboard() {
    if (!_brandsLoaded) {
      _loadBrandsAndCategories();
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }
    return Scaffold(
      appBar: AppBar(
        title: const Text('Gestión de Productos'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Cerrar sesión',
            onPressed: () => _auth.signOut(),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Productos', style: Theme.of(context).textTheme.headlineSmall),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  flex: 2,
                  child: TextField(
                    controller: _searchController,
                    decoration: const InputDecoration(
                      hintText: 'Buscar por nombre...',
                      prefixIcon: Icon(Icons.search),
                      isDense: true,
                      filled: true,
                    ),
                    onChanged: (_) => setState(() {}),
                  ),
                ),
                const SizedBox(width: 12),
                Container(
                  width: 180,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey[400]!),
                    borderRadius: BorderRadius.circular(4),
                    color: Colors.white,
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: _filterBrandId,
                      isDense: true,
                      isExpanded: true,
                      hint: const Text('Marca'),
                      items: [
                        const DropdownMenuItem(value: null, child: Text('Todas')),
                        ..._brands.map((b) => DropdownMenuItem(
                              value: b['id'] as String,
                              child: Text(b['nombre'] as String),
                            )),
                      ],
                      onChanged: (v) => setState(() => _filterBrandId = v),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Container(
                  width: 180,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey[400]!),
                    borderRadius: BorderRadius.circular(4),
                    color: Colors.white,
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: _filterCategoryId,
                      isDense: true,
                      isExpanded: true,
                      hint: const Text('Categoría'),
                      items: [
                        const DropdownMenuItem(value: null, child: Text('Todas')),
                        ..._categories.map((c) => DropdownMenuItem(
                              value: c['id'] as String,
                              child: Text(c['nombre'] as String),
                            )),
                      ],
                      onChanged: (v) => setState(() => _filterCategoryId = v),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(minimumSize: const Size(140, 44)),
                  icon: const Icon(Icons.add),
                  label: const Text('Agregar Producto'),
                  onPressed: () => _showProductForm(),
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (_searchController.text.isNotEmpty ||
                _filterBrandId != null ||
                _filterCategoryId != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Wrap(
                  spacing: 6,
                  children: [
                    if (_searchController.text.isNotEmpty)
                      Chip(
                        label: Text('Buscar: "${_searchController.text}"'),
                        onDeleted: () {
                          _searchController.clear();
                          setState(() {});
                        },
                      ),
                    if (_filterBrandId != null)
                      Chip(
                        label: Text('Marca: ${_resolveName(_brands, _filterBrandId)}'),
                        onDeleted: () => setState(() => _filterBrandId = null),
                      ),
                    if (_filterCategoryId != null)
                      Chip(
                        label: Text('Cat: ${_resolveName(_categories, _filterCategoryId)}'),
                        onDeleted: () => setState(() => _filterCategoryId = null),
                      ),
                  ],
                ),
              ),
            Expanded(
              child: _buildProductTable(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProductTable() {
    return StreamBuilder<QuerySnapshot>(
      stream: _firestore.collection('productos').snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(
            child: Text('Error: ${snapshot.error}', style: const TextStyle(color: Colors.red)),
          );
        }
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        var docs = snapshot.data!.docs;

        final query = _searchController.text.toLowerCase().trim();
        if (query.isNotEmpty) {
          docs = docs.where((d) {
            final data = d.data() as Map;
            final name = (data['nombre'] ?? '').toString().toLowerCase();
            return name.contains(query);
          }).toList();
        }
        if (_filterBrandId != null) {
          docs = docs.where((d) {
            final data = d.data() as Map;
            return (data['marca'] ?? '') == _filterBrandId;
          }).toList();
        }
        if (_filterCategoryId != null) {
          docs = docs.where((d) {
            final data = d.data() as Map;
            return (data['categoria'] ?? '') == _filterCategoryId;
          }).toList();
        }

        if (docs.isEmpty) {
          return const Center(child: Text('No hay productos'));
        }

        return SingleChildScrollView(
          child: DataTable(
            headingRowHeight: 48,
            dataRowMinHeight: 48,
            dataRowMaxHeight: 64,
            columns: const [
              DataColumn(label: Text('Imagen')),
              DataColumn(label: Text('Nombre')),
              DataColumn(label: Text('Marca')),
              DataColumn(label: Text('Categoría')),
              DataColumn(label: Text('Precio'), numeric: true),
              DataColumn(label: Text('Stock'), numeric: true),
              DataColumn(label: Text('Acciones')),
            ],
            rows: docs.map((doc) {
              final data = doc.data() as Map<String, dynamic>;
              final imageUrl = data['imagen_url'] as String? ?? '';
              return DataRow(cells: [
                DataCell(
                  imageUrl.isNotEmpty
                      ? Image.network(
                          imageUrl,
                          width: 40,
                          height: 40,
                          fit: BoxFit.cover,
                          errorBuilder: (_, e, s) => Container(
                            width: 40,
                            height: 40,
                            color: Colors.grey[200],
                            child: const Icon(Icons.image, size: 20, color: Colors.grey),
                          ),
                        )
                      : Container(
                          width: 40,
                          height: 40,
                          color: Colors.grey[200],
                          child: const Icon(Icons.image, size: 20, color: Colors.grey),
                        ),
                ),
                DataCell(Text(data['nombre'] ?? '', overflow: TextOverflow.ellipsis)),
                DataCell(Text(_resolveName(_brands, data['marca'] as String?))),
                DataCell(Text(_resolveName(_categories, data['categoria'] as String?))),
                DataCell(Text('S/ ${(data['precio'] ?? 0).toStringAsFixed(2)}')),
                DataCell(Text('${data['stock'] ?? 0}')),
                DataCell(Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.edit, color: Colors.blue, size: 20),
                      tooltip: 'Editar',
                      onPressed: () => _showProductForm(product: data, id: doc.id),
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete, color: Colors.red, size: 20),
                      tooltip: 'Eliminar',
                      onPressed: () => _eliminarProducto(doc.id),
                    ),
                  ],
                )),
              ]);
            }).toList(),
          ),
        );
      },
    );
  }
}

class _AdminLoginPage extends StatefulWidget {
  const _AdminLoginPage();

  @override
  State<_AdminLoginPage> createState() => _AdminLoginPageState();
}

class _AdminLoginPageState extends State<_AdminLoginPage> {
  final _auth = FirebaseAuth.instance;

  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _loading = false;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _signIn() async {
    setState(() => _loading = true);
    try {
      await _auth.signInWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text,
      );
    } catch (e) {
      if (!mounted) return;
      String msg;
      if (e is FirebaseAuthException) {
        msg = e.code == 'invalid-credential'
            ? 'Credenciales incorrectas'
            : 'Error: ${e.message}';
      } else {
        msg = 'Error de conexión. Verifica tu red.';
        debugPrint('SignIn error: $e');
      }
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF165DFF),
      body: Center(
        child: Container(
          width: 380,
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  color: const Color(0xFF165DFF),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Icon(Icons.admin_panel_settings,
                    color: Colors.white, size: 48),
              ),
              const SizedBox(height: 16),
              const Text('Panel de Administración',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
              const SizedBox(height: 24),
              TextField(
                controller: _emailController,
                decoration: const InputDecoration(
                  labelText: 'Correo electrónico',
                  prefixIcon: Icon(Icons.email_outlined),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _passwordController,
                obscureText: true,
                decoration: const InputDecoration(
                  labelText: 'Contraseña',
                  prefixIcon: Icon(Icons.lock_outline_rounded),
                ),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _loading ? null : _signIn,
                  child: _loading
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Ingresar'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
