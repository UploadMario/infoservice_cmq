import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../data/cart_service.dart';
import '../../delivery/presentation/delivery_tracking_screen.dart';

class PurchaseHistoryScreen extends StatelessWidget {
  const PurchaseHistoryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final cartService = CartService.instance;

    return Scaffold(
      appBar: AppBar(title: const Text('Historial de compras')),
      body: StreamBuilder<QuerySnapshot>(
        stream: cartService.getPurchaseHistory(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          final docs = snapshot.data?.docs ?? [];
          if (docs.isEmpty) {
            return const Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.receipt_long_outlined, size: 64,
                      color: Colors.grey),
                  SizedBox(height: 16),
                  Text('No hay compras registradas',
                      style:
                          TextStyle(fontSize: 16, color: Colors.grey)),
                ],
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: docs.length,
            itemBuilder: (context, index) {
              final doc = docs[index];
              final data = (doc.data() ?? {}) as Map<String, dynamic>;
              return _HistoryCard(
                key: ValueKey(doc.id),
                docId: doc.id,
                data: data,
                onTrack: data['estado'] == 'preparando' ||
                        data['estado'] == 'en_camino'
                    ? () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => DeliveryTrackingScreen(
                              orderId: doc.id,
                              data: data,
                            ),
                          ),
                        );
                      }
                    : null,
                onCancel: data['estado'] == 'preparando'
                    ? () async {
                        final confirm = await showDialog<bool>(
                          context: context,
                          builder: (ctx) => AlertDialog(
                            title: const Text('Cancelar pedido'),
                            content: const Text(
                              '¿Estás seguro de cancelar este pedido?',
                            ),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.pop(ctx, false),
                                child: const Text('No'),
                              ),
                              TextButton(
                                onPressed: () => Navigator.pop(ctx, true),
                                child: const Text('Sí, cancelar',
                                    style: TextStyle(color: Colors.red)),
                              ),
                            ],
                          ),
                        );
                        if (confirm == true) {
                          await CartService.instance.cancelOrder(doc.id);
                        }
                      }
                    : null,
              );
            },
          );
        },
      ),
    );
  }
}

class _HistoryCard extends StatelessWidget {
  final String docId;
  final Map<String, dynamic> data;
  final VoidCallback? onTrack;
  final VoidCallback? onCancel;

  const _HistoryCard({
    super.key,
    required this.docId,
    required this.data,
    this.onTrack,
    this.onCancel,
  });

  Color _statusColor(String estado) {
    switch (estado) {
      case 'preparando':
        return Colors.orange;
      case 'en_camino':
        return Colors.blue;
      case 'completado':
        return Colors.green;
      case 'cancelado':
        return Colors.grey;
      default:
        return Colors.grey;
    }
  }

  String _statusLabel(String estado) {
    switch (estado) {
      case 'preparando':
        return 'Preparando';
      case 'en_camino':
        return 'En camino';
      case 'completado':
        return 'Completado';
      case 'cancelado':
        return 'Cancelado';
      default:
        return estado;
    }
  }

  @override
  Widget build(BuildContext context) {
    final productos = (data['productos'] as List<dynamic>?) ?? [];
    final total = (data['total'] as num?)?.toDouble() ?? 0;
    final timestamp = data['fecha'] as Timestamp?;
    final fecha = timestamp?.toDate() ?? DateTime.now();
    final estado = data['estado'] as String? ?? 'completado';
    final color = _statusColor(estado);

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ExpansionTile(
        tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
        title: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              '${fecha.day}/${fecha.month}/${fecha.year}',
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                _statusLabel(estado),
                style: const TextStyle(
                    fontSize: 11, color: Colors.white)),
            ),
          ],
        ),
        subtitle: Text(
          '${productos.length} producto(s) — S/. ${total.toStringAsFixed(2)}',
          style: const TextStyle(fontSize: 13),
        ),
        children: [
          const Divider(),
          ...productos.map((p) {
            final pMap = p is Map<String, dynamic> ? p : <String, dynamic>{};
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 3),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      '${pMap['nombre']} × ${pMap['cantidad']}',
                      style: const TextStyle(fontSize: 13),
                    ),
                  ),
                  Text(
                    'S/. ${((pMap['subtotal'] as num?) ?? 0).toStringAsFixed(2)}',
                    style: const TextStyle(
                        fontWeight: FontWeight.w500, fontSize: 13),
                  ),
                ],
              ),
            );
          }),
          const Divider(),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Total',
                  style: TextStyle(
                      fontWeight: FontWeight.bold, fontSize: 14)),
              Text(
                'S/. ${total.toStringAsFixed(2)}',
                style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                    color: Colors.green),
              ),
            ],
          ),
          if (onTrack != null || onCancel != null)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  if (onCancel != null)
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: TextButton.icon(
                        onPressed: onCancel,
                        icon: const Icon(Icons.cancel_outlined, size: 18),
                        label: const Text('Cancelar'),
                        style: TextButton.styleFrom(
                          foregroundColor: Colors.red,
                          visualDensity: VisualDensity.compact,
                        ),
                      ),
                    ),
                  if (onTrack != null)
                    ElevatedButton.icon(
                      onPressed: onTrack,
                      icon: const Icon(Icons.map_outlined, size: 18),
                      label: const Text('Seguir'),
                      style: ElevatedButton.styleFrom(
                        visualDensity: VisualDensity.compact,
                      ),
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
