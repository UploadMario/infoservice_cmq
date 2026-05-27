import 'package:flutter/material.dart';
import '../../auth/data/auth_service.dart';
import '../../cart/presentation/purchase_history_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final authService = AuthService();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Infoservice'),
        actions: [
          IconButton(
            tooltip: 'Cerrar sesión',
            onPressed: authService.signOut,
            icon: const Icon(Icons.logout_rounded),
          ),
        ],
      ),
      body: FutureBuilder(
        future: authService.getCurrentUserData(),
        builder: (context, snapshot) {
          final data = snapshot.data?.data();
          final nombre =
              data?['nombre'] ??
              authService.currentUser?.displayName ??
              'Usuario';
          final rol = data?['rol'] ?? 'Sin rol';

          return ListView(
            padding: const EdgeInsets.all(20),
            children: [
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF165DFF), Color(0xFF0F172A)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(24),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        Icons.storefront_rounded,
                        color: Colors.white,
                        size: 28,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Bienvenido, $nombre',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 22,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        'Rol: $rol',
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Base conectada con Firebase Authentication y Cloud Firestore.',
                      style: TextStyle(color: Colors.white60, fontSize: 13),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),
              _ModuleCard(
                icon: Icons.point_of_sale_rounded,
                title: 'Ventas',
                subtitle: 'Historial de compras',
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const PurchaseHistoryScreen(),
                  ),
                ),
              ),
              _ModuleCard(
                icon: Icons.inventory_2_rounded,
                title: 'Productos',
                subtitle: 'Gestionar catálogo',
                onTap: () => Navigator.pushNamed(context, '/products'),
              ),
              _ModuleCard(
                icon: Icons.people_alt_rounded,
                title: 'Clientes',
                subtitle: 'Próximo módulo',
                onTap: () {}, // Dejar vacío si aún no está implementado
              ),
            ],
          );
        },
      ),
    );
  }
}

class _ModuleCard extends StatelessWidget {
  const _ModuleCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      color: Colors.white,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: ListTile(
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon,
              color: Theme.of(context).colorScheme.primary, size: 24),
        ),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w800)),
        subtitle: Text(subtitle),
        trailing: const Icon(Icons.chevron_right_rounded),
        onTap: onTap,
      ),
    );
  }
}
