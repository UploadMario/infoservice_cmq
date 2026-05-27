import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../data/cart_service.dart';

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
              final data = doc.data()! as Map<String, dynamic>;
              return _HistoryCard(docId: doc.id, data: data);
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

  const _HistoryCard({required this.docId, required this.data});

  @override
  Widget build(BuildContext context) {
    final productos = (data['productos'] as List<dynamic>?) ?? [];
    final total = (data['total'] as num?)?.toDouble() ?? 0;
    final timestamp = data['fecha'] as Timestamp?;
    final fecha = timestamp?.toDate() ?? DateTime.now();
    final estado = data['estado'] ?? 'completado';

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
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
                color: Colors.green,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(estado,
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
            final pMap = p as Map<String, dynamic>;
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
                    'S/. ${(pMap['subtotal'] as num).toStringAsFixed(2)}',
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
        ],
      ),
    );
  }
}
