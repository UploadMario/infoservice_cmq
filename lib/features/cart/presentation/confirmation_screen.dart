import 'package:flutter/material.dart';

class ConfirmationScreen extends StatelessWidget {
  final Map<String, dynamic> purchaseData;

  const ConfirmationScreen({super.key, required this.purchaseData});

  @override
  Widget build(BuildContext context) {
    final productos = purchaseData['productos'] as List<dynamic>;
    final total = purchaseData['total'] as double;
    final fecha = purchaseData['fecha'] as DateTime;

    return Scaffold(
      appBar: AppBar(title: const Text('Compra exitosa')),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.check_circle, color: Colors.green, size: 80),
              const SizedBox(height: 16),
              const Text(
                '¡Compra realizada con éxito!',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text(
                '${fecha.day}/${fecha.month}/${fecha.year} '
                '${fecha.hour}:${fecha.minute.toString().padLeft(2, '0')}',
                style: const TextStyle(color: Colors.grey),
              ),
              const SizedBox(height: 24),
              const Divider(),
              const Text('Productos',
                  style: TextStyle(
                      fontSize: 16, fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              ...productos.map((p) {
                final pMap = p as Map<String, dynamic>;
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          '${pMap['nombre']} x${pMap['cantidad']}',
                          style: const TextStyle(fontSize: 14),
                        ),
                      ),
                      Text(
                        'S/. ${(pMap['subtotal'] as num).toStringAsFixed(2)}',
                        style:
                            const TextStyle(fontWeight: FontWeight.w500),
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
                          fontSize: 18, fontWeight: FontWeight.bold)),
                  Text(
                    'S/. ${total.toStringAsFixed(2)}',
                    style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.green),
                  ),
                ],
              ),
              const SizedBox(height: 32),
              ElevatedButton(
                onPressed: () => Navigator.pop(context),
                style: ElevatedButton.styleFrom(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 32, vertical: 14),
                ),
                child: const Text('Volver a productos'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
