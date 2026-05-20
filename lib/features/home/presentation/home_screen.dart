import 'package:flutter/material.dart';

import '../../auth/data/auth_service.dart';

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
          final nombre = data?['nombre'] ?? authService.currentUser?.displayName ?? 'Usuario';
          final rol = data?['rol'] ?? 'Sin rol';

          return ListView(
            padding: const EdgeInsets.all(20),
            children: [
              Container(
                padding: const EdgeInsets.all(22),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(24),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Bienvenido, $nombre',
                      style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w900),
                    ),
                    const SizedBox(height: 8),
                    Text('Rol: $rol'),
                    const SizedBox(height: 18),
                    const Text('Base conectada con Firebase Authentication y Cloud Firestore.'),
                  ],
                ),
              ),
              const SizedBox(height: 18),
              const _ModuleCard(icon: Icons.point_of_sale_rounded, title: 'Ventas', subtitle: 'Próximo módulo'),
              const _ModuleCard(icon: Icons.inventory_2_rounded, title: 'Productos', subtitle: 'Próximo módulo'),
              const _ModuleCard(icon: Icons.people_alt_rounded, title: 'Clientes', subtitle: 'Próximo módulo'),
            ],
          );
        },
      ),
    );
  }
}

class _ModuleCard extends StatelessWidget {
  const _ModuleCard({required this.icon, required this.title, required this.subtitle});

  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      color: Colors.white,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: ListTile(
        leading: Icon(icon, color: Theme.of(context).colorScheme.primary),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w800)),
        subtitle: Text(subtitle),
        trailing: const Icon(Icons.chevron_right_rounded),
      ),
    );
  }
}
