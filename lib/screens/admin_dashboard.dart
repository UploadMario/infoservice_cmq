import 'dart:async';
import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:file_picker/file_picker.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:image/image.dart' as img;
import 'package:url_launcher/url_launcher.dart';

class AdminDashboard extends StatefulWidget {
  const AdminDashboard({super.key});

  @override
  State<AdminDashboard> createState() => _AdminDashboardState();
}

class _PieChartData {
  final String label;
  final double value;
  final Color color;
  _PieChartData(this.label, this.value, this.color);
}

class _AdminDashboardState extends State<AdminDashboard> {
  final _auth = FirebaseAuth.instance;
  final _firestore = FirebaseFirestore.instance;

  final _nameController = TextEditingController();
  final _priceController = TextEditingController();
  final _stockController = TextEditingController();
  final _imageUrlController = TextEditingController();

  String? _editingId;
  String? _selectedBrandId;
  String? _selectedCategoryId;
  bool _frameReady = false;

  List<Map<String, dynamic>> _brands = [];
  List<Map<String, dynamic>> _categories = [];
  bool _brandsLoaded = false;
  String _currentSection = 'products';

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

  Future<bool?> _showProductForm({
    Map<String, dynamic>? product,
    String? id,
  }) async {
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
        bool isUploading = false;
        double uploadProgress = 0;
        return StatefulBuilder(
          builder: (ctx, setDialogState) {
            return AlertDialog(
              title: Text(
                _editingId == null ? 'Nuevo Producto' : 'Editar Producto',
              ),
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
                        validator: (v) => v == null || v.trim().isEmpty
                            ? 'Ingresa el nombre'
                            : null,
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: TextFormField(
                              controller: _imageUrlController,
                              decoration: const InputDecoration(
                                labelText: 'URL de imagen',
                                prefixIcon: Icon(Icons.image_outlined),
                                isDense: true,
                              ),
                              keyboardType: TextInputType.url,
                              onChanged: (_) => setDialogState(() {}),
                            ),
                          ),
                          const SizedBox(width: 8),
                          TextButton(
                            onPressed: isUploading
                                ? null
                                : () async {
                                    final result =
                                        await FilePicker.platform.pickFiles(
                                      type: FileType.image,
                                    );
                                    if (result == null ||
                                        result.files.isEmpty) return;
                                    final file = result.files.first;
                                    if (file.bytes == null) return;
                                    setDialogState(
                                        () => isUploading = true);
                                    try {
                                      final original =
                                          img.decodeImage(file.bytes!);
                                      if (original != null) {
                                        final resized = img.copyResize(
                                            original,
                                            width: 800);
                                        final jpeg = img.encodeJpg(
                                            resized,
                                            quality: 70);
                                        final b64 = base64Encode(jpeg);
                                        _imageUrlController.text =
                                            'data:image/jpeg;base64,$b64';
                                      }
                                      setDialogState(() {
                                        isUploading = false;
                                        uploadProgress = 0;
                                      });
                                    } catch (e) {
                                      setDialogState(() {
                                        isUploading = false;
                                        uploadProgress = 0;
                                      });
                                      if (ctx.mounted) {
                                        ScaffoldMessenger.of(ctx)
                                            .showSnackBar(SnackBar(
                                          content: Text(
                                              'Error al procesar imagen: $e'),
                                        ));
                                      }
                                    }
                                  },
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  isUploading
                                      ? Icons.hourglass_top
                                      : Icons.upload_file,
                                  size: 18,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                    isUploading ? 'Subiendo...' : 'Subir'),
                              ],
                            ),
                          ),
                        ],
                      ),
                      if (isUploading) ...[
                        const SizedBox(height: 8),
                        LinearProgressIndicator(value: uploadProgress),
                      ],
                      if (_imageUrlController.text.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: _buildImageWidget(
                            _imageUrlController.text,
                            height: 100,
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
                          ..._brands.map(
                            (b) => DropdownMenuItem(
                              value: b['id'] as String,
                              child: Text(b['nombre'] as String),
                            ),
                          ),
                        ],
                        onChanged: (v) =>
                            setDialogState(() => localBrandId = v),
                        validator: (v) =>
                            v == null ? 'Selecciona una marca' : null,
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
                          ..._categories.map(
                            (c) => DropdownMenuItem(
                              value: c['id'] as String,
                              child: Text(c['nombre'] as String),
                            ),
                          ),
                        ],
                        onChanged: (v) =>
                            setDialogState(() => localCategoryId = v),
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
                                labelText: 'Precio (S/.)',
                                prefixIcon: Icon(
                                  Icons.monetization_on_outlined,
                                ),
                              ),
                              keyboardType:
                                  const TextInputType.numberWithOptions(
                                    decimal: true,
                                  ),
                              validator: (v) {
                                if (v == null || v.trim().isEmpty)
                                  return 'Requerido';
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
                                if (v == null || v.trim().isEmpty)
                                  return 'Requerido';
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
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
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
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    return Scaffold(
      appBar: AppBar(
        title: Text(
          _currentSection == 'products'
              ? 'Gestión de Productos'
              : 'Ventas y Ganancias',
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Cerrar sesión',
            onPressed: () => _auth.signOut(),
          ),
        ],
      ),
      drawer: Drawer(
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            DrawerHeader(
              decoration: const BoxDecoration(),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  SizedBox(
                    width: 64,
                    height: 64,
                    child: Image.asset('assets/icono.png', fit: BoxFit.contain),
                  ),
                  const SizedBox(height: 8),
                  const Text('Admin Panel', style: TextStyle(fontSize: 18)),
                ],
              ),
            ),
            ListTile(
              leading: const Icon(Icons.inventory_2),
              title: const Text('Productos'),
              selected: _currentSection == 'products',
              onTap: () {
                setState(() => _currentSection = 'products');
                Navigator.pop(context);
              },
            ),
            ListTile(
              leading: const Icon(Icons.bar_chart),
              title: const Text('Ventas'),
              selected: _currentSection == 'ventas',
              onTap: () {
                setState(() => _currentSection = 'ventas');
                Navigator.pop(context);
              },
            ),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.logout),
              title: const Text('Cerrar sesión'),
              onTap: () => _auth.signOut(),
            ),
          ],
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: _currentSection == 'products'
            ? _buildProductsSection()
            : _buildVentasSection(),
      ),
    );
  }

  Widget _buildProductsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Productos', style: Theme.of(context).textTheme.headlineSmall),
        const SizedBox(height: 16),
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(minimumSize: const Size(140, 44)),
              icon: const Icon(Icons.add),
              label: const Text('Agregar Producto'),
              onPressed: () => _showProductForm(),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Expanded(
          child: _ProductTable(
            stream: _firestore.collection('productos').snapshots(),
            brands: _brands,
            categories: _categories,
            onEdit: _showProductForm,
            onDelete: _eliminarProducto,
          ),
        ),
      ],
    );
  }

  Widget _buildVentasSection() {
    return StreamBuilder<QuerySnapshot>(
      stream: _firestore
          .collection('historial_compras')
          .orderBy('fecha', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(
            child: Text(
              'Error: ${snapshot.error}',
              style: const TextStyle(color: Colors.red),
            ),
          );
        }
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final docs = snapshot.data!.docs;
        final now = DateTime.now();
        final todayStart = DateTime(now.year, now.month, now.day);

        int completadas = 0;
        int pendientes = 0;
        int canceladas = 0;
        int ordenesHoy = 0;
        double ganancias = 0;
        double ingresosHoy = 0;
        double sumaTotales = 0;
        final Map<String, double> revenueByDay = {};
        final Map<String, int> productCount = {};
        final Map<String, double> productRevenue = {};

        for (final doc in docs) {
          final data = doc.data() as Map<String, dynamic>;
          final estado = data['estado'] as String? ?? '';
          final total = (data['total'] as num?)?.toDouble() ?? 0;
          final timestamp = data['fecha'] as Timestamp?;
          final fecha = timestamp?.toDate() ?? now;

          sumaTotales += total;

          if (fecha.isAfter(todayStart)) {
            ordenesHoy++;
            if (estado == 'completado') {
              ingresosHoy += total;
            }
          }

          switch (estado) {
            case 'completado':
              completadas++;
              ganancias += total;
              break;
            case 'preparando':
            case 'en_camino':
              pendientes++;
              break;
            case 'cancelado':
              canceladas++;
              break;
          }

          final dayKey = '${fecha.day}/${fecha.month}';
          revenueByDay.update(dayKey, (v) => v + total, ifAbsent: () => total);

          final productos = data['productos'] as List<dynamic>? ?? [];
          for (final p in productos) {
            final nombre = (p is Map ? p['nombre'] ?? p['name'] : null) as String? ?? 'Producto';
            final precio = (p is Map ? (p['precio'] ?? p['price'] ?? 0) : 0) as num;
            productCount.update(nombre, (v) => v + 1, ifAbsent: () => 1);
            productRevenue.update(nombre, (v) => v + precio.toDouble(), ifAbsent: () => precio.toDouble());
          }
        }

        final totalOrdenes = docs.length;
        final promedio = totalOrdenes > 0 ? sumaTotales / totalOrdenes : 0.0;

        final sortedProducts = productCount.entries.toList()
          ..sort((a, b) => b.value.compareTo(a.value));
        final top5 = sortedProducts.take(5).toList();
        final bottom5 = sortedProducts.reversed.take(5).toList();

        return SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Resumen de Ventas',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 16),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  _buildSummaryCard('Total Órdenes', '$totalOrdenes', Colors.indigo, Icons.receipt_long),
                  _buildSummaryCard('Completadas', completadas.toString(), Colors.green, Icons.check_circle),
                  _buildSummaryCard('Promedio/Orden', 'S/ ${promedio.toStringAsFixed(2)}', Colors.teal, Icons.trending_up),
                  _buildSummaryCard('Órdenes Hoy', '$ordenesHoy', Colors.orange, Icons.today),
                  _buildSummaryCard('Ingresos Hoy', 'S/ ${ingresosHoy.toStringAsFixed(2)}', Colors.blue, Icons.payments),
                  _buildSummaryCard('Ganancias total', 'S/ ${ganancias.toStringAsFixed(2)}', Colors.green, Icons.account_balance_wallet),
                  _buildSummaryCard('Pendientes', pendientes.toString(), Colors.orange, Icons.pending),
                  _buildSummaryCard('Canceladas', canceladas.toString(), Colors.grey, Icons.cancel),
                ],
              ),
              const SizedBox(height: 24),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    width: 320,
                    child: _buildChartPie(completadas, pendientes, canceladas),
                  ),
                  const SizedBox(width: 24),
                  Expanded(
                    child: SizedBox(
                      height: 220,
                      child: _buildChartBar(revenueByDay),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: _buildProductRankTable('Top 5 más vendidos', top5, productRevenue),
                  ),
                  const SizedBox(width: 24),
                  Expanded(
                    child: _buildProductRankTable('Top 5 menos vendidos', bottom5, productRevenue),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              Text(
                'Órdenes Recientes',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 12),
              docs.isEmpty
                  ? const Padding(
                      padding: EdgeInsets.symmetric(vertical: 32),
                      child: Center(child: Text('No hay ventas registradas')),
                    )
                  : SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Table(
                        defaultColumnWidth: const FlexColumnWidth(),
                        columnWidths: const {
                          0: FlexColumnWidth(1.2),
                          1: FlexColumnWidth(2),
                          2: FlexColumnWidth(1.3),
                          3: FlexColumnWidth(1.5),
                          4: FlexColumnWidth(1),
                          5: FlexColumnWidth(1),
                        },
                        border: TableBorder.all(color: Colors.grey.shade300, width: 0.5),
                        children: [
                          TableRow(
                            decoration: BoxDecoration(color: Colors.grey.shade100),
                            children: [
                              _tableHeader('Fecha'),
                              _tableHeader('Usuario'),
                              _tableHeader('Total'),
                              _tableHeader('Estado'),
                              _tableHeader('Prod.'),
                              _tableHeader(''),
                            ],
                          ),
                          ...docs.map((doc) {
                            final data = doc.data() as Map<String, dynamic>;
                            final timestamp = data['fecha'] as Timestamp?;
                            final fecha = timestamp?.toDate() ?? DateTime.now();
                            final total = (data['total'] as num?)?.toDouble() ?? 0;
                            final estado = data['estado'] as String? ?? '';
                            final productos = (data['productos'] as List<dynamic>?) ?? [];
                            final usuario = data['usuarioNombre'] as String? ?? data['uid'] as String? ?? '—';

                            return TableRow(
                              children: [
                                _tableCell('${fecha.day}/${fecha.month}/${fecha.year}'),
                                _tableCell(usuario, overflow: TextOverflow.ellipsis),
                                _tableCell('S/ ${total.toStringAsFixed(2)}'),
                                _tableCell('', child: _buildStatusBadge(estado)),
                                _tableCell('${productos.length}'),
                                _tableCell('', child: IconButton(
                                  icon: const Icon(Icons.visibility, size: 20),
                                  tooltip: 'Ver detalle',
                                  onPressed: () => _showOrderDetail(data),
                                )),
                              ],
                            );
                          }),
                        ],
                      ),
                    ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildSummaryCard(
    String label,
    String value,
    Color color,
    IconData icon,
  ) {
    return Container(
      width: 160,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 28),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                ),
                Text(
                  label,
                  style: TextStyle(fontSize: 11, color: Colors.grey[600]),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildChartPie(int completadas, int pendientes, int canceladas) {
    final data = [
      _PieChartData('Completadas', completadas.toDouble(), Colors.green),
      _PieChartData('Pendientes', pendientes.toDouble(), Colors.orange),
      _PieChartData('Canceladas', canceladas.toDouble(), Colors.grey),
    ];
    final total = completadas + pendientes + canceladas;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Distribución de estados',
                style: TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 12),
            SizedBox(
              height: 140,
              child: PieChart(
                PieChartData(
                  sections: data.where((d) => d.value > 0).map((d) {
                    final pct = total > 0 ? d.value / total * 100 : 0.0;
                    return PieChartSectionData(
                      value: d.value,
                      color: d.color,
                      title: '${pct.toStringAsFixed(0)}%',
                      titleStyle: const TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: Colors.white),
                      radius: 50,
                    );
                  }).toList(),
                  sectionsSpace: 2,
                  centerSpaceRadius: 30,
                ),
              ),
            ),
            const SizedBox(height: 8),
            ...data.map((d) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 1),
                  child: _legendDot(d.label, d.value.toInt(), d.color),
                )),
          ],
        ),
      ),
    );
  }

  Widget _legendDot(String label, int count, Color color) {
    return Row(
      children: [
        Container(
            width: 10, height: 10, decoration: BoxDecoration(shape: BoxShape.circle, color: color)),
        const SizedBox(width: 6),
        Text('$label: $count', style: const TextStyle(fontSize: 12)),
      ],
    );
  }

  Widget _buildChartBar(Map<String, double> revenueByDay) {
    final entries = revenueByDay.entries.take(7).toList().reversed.toList();
    if (entries.isEmpty) {
      return const Center(child: Text('Sin datos de ingresos'));
    }
    final maxY = entries.fold<double>(0, (m, e) => e.value > m ? e.value : m);
    final ceiling = maxY > 0 ? (maxY * 1.2).ceilToDouble() : 100.0;

    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Ingresos últimos 7 días',
                style: TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            Expanded(
              child: BarChart(
                BarChartData(
                  alignment: BarChartAlignment.spaceAround,
                  maxY: ceiling,
                  barTouchData: BarTouchData(
                    touchTooltipData: BarTouchTooltipData(
                      getTooltipItem: (group, groupIndex, rod, rodIndex) {
                        return BarTooltipItem(
                          'S/ ${rod.toY.toStringAsFixed(0)}',
                          const TextStyle(color: Colors.white, fontSize: 11),
                        );
                      },
                    ),
                  ),
                  titlesData: FlTitlesData(
                    show: true,
                    topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 40,
                        getTitlesWidget: (value, meta) {
                          if (value == 0) return const SizedBox();
                          return Text(
                            'S/${value.toInt()}',
                            style: const TextStyle(fontSize: 9, color: Colors.grey),
                          );
                        },
                      ),
                    ),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        getTitlesWidget: (value, meta) {
                          final idx = value.toInt();
                          if (idx < 0 || idx >= entries.length) return const SizedBox();
                          return Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Text(entries[idx].key, style: const TextStyle(fontSize: 9, color: Colors.grey)),
                          );
                        },
                      ),
                    ),
                  ),
                  borderData: FlBorderData(show: false),
                  barGroups: entries.asMap().entries.map((e) {
                    return BarChartGroupData(
                      x: e.key,
                      barRods: [
                        BarChartRodData(
                          toY: e.value.value,
                          color: Colors.teal,
                          width: 18,
                          borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
                        ),
                      ],
                    );
                  }).toList(),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProductRankTable(String title, List<MapEntry<String, int>> products, Map<String, double> revenue) {
    if (products.isEmpty) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
        ),
      );
    }
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            Table(
              columnWidths: const {
                0: FlexColumnWidth(3),
                1: FlexColumnWidth(1),
                2: FlexColumnWidth(1.5),
              },
              children: [
                TableRow(
                  decoration: BoxDecoration(color: Colors.grey.shade100),
                  children: [
                    _tableHeader('Producto'),
                    _tableHeader('Cant.'),
                    _tableHeader('Total'),
                  ],
                ),
                ...products.map((e) => TableRow(
                  children: [
                    _tableCell(e.key, overflow: TextOverflow.ellipsis),
                    _tableCell('${e.value}'),
                    _tableCell('S/ ${(revenue[e.key] ?? 0).toStringAsFixed(2)}'),
                  ],
                )),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _tableHeader(String label) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
      child: Text(label, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
    );
  }

  Widget _tableCell(String text, {TextOverflow overflow = TextOverflow.clip, Widget? child}) {
    if (child != null) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
        child: child,
      );
    }
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
      child: Text(text, overflow: overflow, style: const TextStyle(fontSize: 13)),
    );
  }

  Widget _buildStatusBadge(String estado) {
    Color color;
    String label;
    switch (estado) {
      case 'preparando':
        color = Colors.orange;
        label = 'Preparando';
        break;
      case 'en_camino':
        color = Colors.blue;
        label = 'En camino';
        break;
      case 'completado':
        color = Colors.green;
        label = 'Completado';
        break;
      case 'cancelado':
        color = Colors.grey;
        label = 'Cancelado';
        break;
      default:
        color = Colors.grey;
        label = estado;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          color: color,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  void _showOrderDetail(Map<String, dynamic> data) {
    final timestamp = data['fecha'] as Timestamp?;
    final fecha = timestamp?.toDate() ?? DateTime.now();
    final estado = data['estado'] as String? ?? '';
    final total = (data['total'] as num?)?.toDouble() ?? 0;
    final productos = (data['productos'] as List<dynamic>?) ?? [];
    final direccion = data['direccion'] as String? ?? 'No especificada';
    final usuario =
        data['usuarioNombre'] as String? ?? data['uid'] as String? ?? '—';
    final correo = data['usuarioCorreo'] as String? ?? '';
    final telefono = data['telefono'] as String? ?? '';
    final lat = (data['latitud'] as num?)?.toDouble();
    final lng = (data['longitud'] as num?)?.toDouble();
    final notas = data['notas'] as String? ?? '';
    final lineaTiempo = data['lineaTiempo'] as List<dynamic>? ?? [];

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(
          children: [
            _buildStatusBadge(estado),
            const Spacer(),
            Text(
              '${fecha.day}/${fecha.month}/${fecha.year}',
              style: const TextStyle(fontSize: 14),
            ),
          ],
        ),
        content: SizedBox(
          width: 520,
          child: ListView(
            shrinkWrap: true,
            children: [
              _sectionHeader('Cliente'),
              _detailRow('Nombre', usuario),
              if (correo.isNotEmpty) _detailRow('Correo', correo),
              if (telefono.isNotEmpty) _detailRow('Teléfono', telefono),
              const SizedBox(height: 12),
              _sectionHeader('Envío'),
              _detailRow('Dirección', direccion),
              if (notas.isNotEmpty) _detailRow('Notas', notas),
              if (lat != null && lng != null) ...[
                _detailRow('Coordenadas', '${lat.toStringAsFixed(5)}, ${lng.toStringAsFixed(5)}'),
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: ElevatedButton.icon(
                    icon: const Icon(Icons.map, size: 16),
                    label: const Text('Abrir Maps', style: TextStyle(fontSize: 12)),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    ),
                    onPressed: () => _openMap(lat, lng),
                  ),
                ),
              ],
              const SizedBox(height: 12),
              if (lineaTiempo.isNotEmpty) ...[
                _sectionHeader('Línea de tiempo'),
                ...lineaTiempo.map((lt) {
                  final ltMap = lt as Map<String, dynamic>;
                  final ltEstado = ltMap['estado'] as String? ?? '';
                  final ltFecha = (ltMap['fecha'] as Timestamp?)?.toDate();
                  return _timelineRow(ltEstado, ltFecha);
                }),
                const SizedBox(height: 12),
              ],
              _sectionHeader('Productos'),
              const Divider(),
              ...productos.map((p) {
                final pMap = p as Map<String, dynamic>;
                final nombre = pMap['nombre'] as String? ?? '—';
                final cantidad = pMap['cantidad'] as int? ?? 0;
                final precio =
                    (pMap['precioUnitario'] as num?)?.toDouble() ?? 0;
                final subtotal = (pMap['subtotal'] as num?)?.toDouble() ?? 0;
                return Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(nombre, style: const TextStyle(fontSize: 13)),
                      ),
                      Text('x$cantidad', style: const TextStyle(fontSize: 12)),
                      const SizedBox(width: 8),
                      Text('S/ ${precio.toStringAsFixed(2)}', style: const TextStyle(fontSize: 12)),
                      const SizedBox(width: 8),
                      Text(
                        'S/ ${subtotal.toStringAsFixed(2)}',
                        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                );
              }),
              const Divider(),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Total', style: TextStyle(fontWeight: FontWeight.bold)),
                  Text(
                    'S/ ${total.toStringAsFixed(2)}',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                ],
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cerrar'),
          ),
        ],
      ),
    );
  }

  void _openMap(double lat, double lng) {
    final uri = Uri.parse('https://www.google.com/maps/search/?api=1&query=$lat,$lng');
    launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  Widget _sectionHeader(String title) {
    return Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14));
  }

  Widget _timelineRow(String estado, DateTime? fecha) {
    Color color;
    switch (estado) {
      case 'completado':
        color = Colors.green;
        break;
      case 'preparando':
        color = Colors.orange;
        break;
      case 'en_camino':
        color = Colors.blue;
        break;
      case 'cancelado':
        color = Colors.red;
        break;
      default:
        color = Colors.grey;
    }
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        children: [
          Container(width: 10, height: 10, decoration: BoxDecoration(shape: BoxShape.circle, color: color)),
          const SizedBox(width: 8),
          Text(estado, style: TextStyle(fontSize: 13, color: color, fontWeight: FontWeight.w500)),
          const Spacer(),
          if (fecha != null)
            Text(
              '${fecha.day}/${fecha.month}/${fecha.year} ${fecha.hour.toString().padLeft(2, '0')}:${fecha.minute.toString().padLeft(2, '0')}',
              style: TextStyle(fontSize: 11, color: Colors.grey[600]),
            ),
        ],
      ),
    );
  }

  Widget _detailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(label, style: TextStyle(fontSize: 13, color: Colors.grey[600])),
          ),
          Expanded(child: Text(value, style: const TextStyle(fontSize: 13))),
        ],
      ),
    );
  }

  Widget _buildImageWidget(String url, {double? height, double? width}) {
    final isDataUri = url.startsWith('data:');
    final w = width ?? double.infinity;
    final h = height ?? 100;
    if (isDataUri) {
      try {
        final parts = url.split(',');
        if (parts.length < 2) return _imagePlaceholder();
        final bytes = base64Decode(parts[1]);
        return ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: Image.memory(
            bytes,
            height: h,
            width: w,
            fit: BoxFit.cover,
            errorBuilder: (_, e, s) => _imagePlaceholder(),
          ),
        );
      } catch (_) {
        return _imagePlaceholder();
      }
    }
    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: Image.network(
        url,
        height: h,
        width: w,
        fit: BoxFit.cover,
        errorBuilder: (_, e, s) => _imagePlaceholder(),
      ),
    );
  }

  Widget _imagePlaceholder() {
    return Container(
      height: 100,
      color: Colors.grey[200],
      child: const Center(
        child: Icon(Icons.broken_image, color: Colors.grey),
      ),
    );
  }
}

class _ProductTable extends StatefulWidget {
  final Stream<QuerySnapshot> stream;
  final List<Map<String, dynamic>> brands;
  final List<Map<String, dynamic>> categories;
  final Future<bool?> Function({Map<String, dynamic>? product, String? id})
  onEdit;
  final Future<void> Function(String id) onDelete;

  const _ProductTable({
    required this.stream,
    required this.brands,
    required this.categories,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  State<_ProductTable> createState() => _ProductTableState();
}

class _ProductTableState extends State<_ProductTable> {
  final _searchController = TextEditingController();
  Timer? _searchDebounce;
  String? _filterBrandId;
  String? _filterCategoryId;

  @override
  void dispose() {
    _searchController.dispose();
    _searchDebounce?.cancel();
    super.dispose();
  }

  String _resolveName(List<Map<String, dynamic>> list, String? id) {
    if (id == null || id.isEmpty) return '—';
    final found = list.firstWhere(
      (e) => e['id'] == id,
      orElse: () => {'nombre': '—'},
    );
    return found['nombre'] as String;
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
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
                onChanged: (_) {
                  _searchDebounce?.cancel();
                  _searchDebounce = Timer(
                    const Duration(milliseconds: 300),
                    () {
                      if (mounted) setState(() {});
                    },
                  );
                },
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
                    ...widget.brands.map(
                      (b) => DropdownMenuItem(
                        value: b['id'] as String,
                        child: Text(b['nombre'] as String),
                      ),
                    ),
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
                    ...widget.categories.map(
                      (c) => DropdownMenuItem(
                        value: c['id'] as String,
                        child: Text(c['nombre'] as String),
                      ),
                    ),
                  ],
                  onChanged: (v) => setState(() => _filterCategoryId = v),
                ),
              ),
            ),
          ],
        ),
        if (_searchController.text.isNotEmpty ||
            _filterBrandId != null ||
            _filterCategoryId != null)
          Padding(
            padding: const EdgeInsets.only(top: 8, bottom: 8),
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
                    label: Text(
                      'Marca: ${_resolveName(widget.brands, _filterBrandId)}',
                    ),
                    onDeleted: () => setState(() => _filterBrandId = null),
                  ),
                if (_filterCategoryId != null)
                  Chip(
                    label: Text(
                      'Cat: ${_resolveName(widget.categories, _filterCategoryId)}',
                    ),
                    onDeleted: () => setState(() => _filterCategoryId = null),
                  ),
              ],
            ),
          ),
        const SizedBox(height: 8),
        Expanded(
          child: StreamBuilder<QuerySnapshot>(
            stream: widget.stream,
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return Center(
                  child: Text(
                    'Error: ${snapshot.error}',
                    style: const TextStyle(color: Colors.red),
                  ),
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
                child: Table(
                  defaultColumnWidth: const FlexColumnWidth(),
                  columnWidths: const {
                    0: FlexColumnWidth(0.8),
                    1: FlexColumnWidth(2.0),
                    2: FlexColumnWidth(1.5),
                    3: FlexColumnWidth(1.5),
                    4: FlexColumnWidth(1.2),
                    5: FlexColumnWidth(0.8),
                    6: FlexColumnWidth(1.2),
                  },
                  border: TableBorder.all(color: Colors.grey.shade300, width: 0.5),
                  children: [
                    TableRow(
                      decoration: BoxDecoration(color: Colors.grey.shade100),
                      children: [
                        _th('Imagen'),
                        _th('Nombre'),
                        _th('Marca'),
                        _th('Categoría'),
                        _th('Precio'),
                        _th('Stock'),
                        _th('Acciones'),
                      ],
                    ),
                    ...docs.map((doc) {
                      final data = doc.data() as Map<String, dynamic>;
                      final imageUrl = data['imagen_url'] as String? ?? '';
                      return TableRow(
                        children: [
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                            child: imageUrl.isNotEmpty
                                ? _tableImage(imageUrl, 40, 40)
                                : _tablePlaceholder(40, 40),
                          ),
                          _tc(data['nombre'] ?? ''),
                          _tc(_resolveName(widget.brands, data['marca'] as String?)),
                          _tc(_resolveName(widget.categories, data['categoria'] as String?)),
                          _tc('S/ ${(data['precio'] ?? 0).toStringAsFixed(2)}'),
                          _tc('${data['stock'] ?? 0}'),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 2),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  icon: const Icon(Icons.edit, color: Colors.blue, size: 20),
                                  tooltip: 'Editar',
                                  onPressed: () => widget.onEdit(product: data, id: doc.id),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.delete, color: Colors.red, size: 20),
                                  tooltip: 'Eliminar',
                                  onPressed: () => widget.onDelete(doc.id),
                                ),
                              ],
                            ),
                          ),
                        ],
                      );
                    }),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  static Widget _th(String label) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
      child: Text(label, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
    );
  }

  static Widget _tc(String text, {TextOverflow overflow = TextOverflow.ellipsis}) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
      child: Text(text, overflow: overflow, style: const TextStyle(fontSize: 13)),
    );
  }

  Widget _tableImage(String url, double w, double h) {
    if (url.startsWith('data:')) {
      try {
        final parts = url.split(',');
        if (parts.length >= 2) {
          return Image.memory(
            base64Decode(parts[1]),
            width: w,
            height: h,
            fit: BoxFit.cover,
            errorBuilder: (_, e, s) => _tablePlaceholder(w, h),
          );
        }
      } catch (_) {}
    }
    return Image.network(
      url,
      width: w,
      height: h,
      fit: BoxFit.cover,
      cacheWidth: 80,
      errorBuilder: (_, e, s) => _tablePlaceholder(w, h),
    );
  }

  Widget _tablePlaceholder(double w, double h) {
    return Container(
      width: w,
      height: h,
      color: Colors.grey[200],
      child: const Icon(Icons.image, size: 20, color: Colors.grey),
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
              SizedBox(
                width: 80,
                height: 80,
                child: Image.asset('assets/icono.png', fit: BoxFit.contain),
              ),
              const SizedBox(height: 16),
              const Text(
                'Panel de Administración',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
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
