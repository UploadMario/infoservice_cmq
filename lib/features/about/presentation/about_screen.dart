import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:infoservice_cmq/features/auth/data/auth_service.dart';

class AboutScreen extends StatefulWidget {
  const AboutScreen({super.key});

  @override
  State<AboutScreen> createState() => _AboutScreenState();
}

class _AboutScreenState extends State<AboutScreen> {
  static const double _businessLat = -11.7775086;
  static const double _businessLng = -75.499446;
  static const LatLng _businessLocation = LatLng(_businessLat, _businessLng);

  final MapController _mapController = MapController();
  final AuthService _authService = AuthService();
  StreamSubscription<Position>? _positionSub;
  Timer? _routeTimer;

  LatLng? _userPosition;
  List<LatLng> _routePoints = [];
  double _distance = 0;
  double _duration = 0;
  bool _loadingRoute = false;
  bool _locationReady = false;
  String? _locationError;
  String? _routeError;
  DateTime _lastRouteFetch = DateTime.now().subtract(const Duration(seconds: 30));

  double _haversineDistance(LatLng a, LatLng b) {
    const R = 6371000;
    final dLat = (b.latitude - a.latitude) * pi / 180;
    final dLon = (b.longitude - a.longitude) * pi / 180;
    final sinDLat = sin(dLat / 2);
    final sinDLon = sin(dLon / 2);
    final a2 = sinDLat * sinDLat +
        cos(a.latitude * pi / 180) * cos(b.latitude * pi / 180) * sinDLon * sinDLon;
    final c = 2 * atan2(sqrt(a2), sqrt(1 - a2));
    return R * c;
  }

  @override
  void initState() {
    super.initState();
    _initLocation();
  }

  @override
  void dispose() {
    _positionSub?.cancel();
    _routeTimer?.cancel();
    _mapController.dispose();
    super.dispose();
  }

  Future<void> _initLocation() async {
    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        setState(() => _locationError = 'Servicio de ubicación desactivado');
        return;
      }

      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          setState(() => _locationError = 'Permiso de ubicación denegado');
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        setState(() =>
            _locationError = 'Permiso denegado permanentemente. Actívalo en Ajustes.');
        return;
      }

      final pos = await Geolocator.getCurrentPosition()
          .timeout(const Duration(seconds: 15));
      _onPositionChanged(pos);

      _positionSub = Geolocator.getPositionStream(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          distanceFilter: 50,
        ),
      ).listen(_onPositionChanged, onError: (_) {});

      setState(() => _locationReady = true);
    } catch (e) {
      setState(() => _locationError = 'Error al obtener ubicación: $e');
    }
  }

  void _onPositionChanged(Position pos) {
    _userPosition = LatLng(pos.latitude, pos.longitude);
    _debouncedFetchRoute();
    setState(() {});
  }

  void _debouncedFetchRoute() {
    final now = DateTime.now();
    if (now.difference(_lastRouteFetch).inSeconds < 10) return;
    _lastRouteFetch = now;
    _fetchRoute();
  }

  Future<void> _fetchRoute() async {
    if (_userPosition == null || _loadingRoute) return;
    _loadingRoute = true;
    _routeError = null;

    _routeTimer?.cancel();
    _routeTimer = Timer(const Duration(seconds: 25), () {
      if (!mounted) return;
      setState(() {
        _loadingRoute = false;
        _routeError = 'Tiempo de espera agotado. Usando distancia estimada.';
        _calculateFallback();
      });
    });

    try {
      final url = Uri.parse(
        'https://router.project-osrm.org/route/v1/driving/'
        '$_businessLng,$_businessLat;'
        '${_userPosition!.longitude},${_userPosition!.latitude}'
        '?overview=full&geometries=geojson',
      );

      final client = HttpClient()
        ..connectionTimeout = const Duration(seconds: 10);
      try {
        final request = await client.getUrl(url);
        final response = await request.close().timeout(const Duration(seconds: 10));
        final body = await response.transform(utf8.decoder).join();

        if (response.statusCode == 200) {
          final data = jsonDecode(body) as Map<String, dynamic>;
          if (data['code'] == 'Ok') {
            final route = (data['routes'] as List).first as Map<String, dynamic>;
            final geometry = route['geometry'] as Map<String, dynamic>;
            final coords = geometry['coordinates'] as List;

            _routePoints = coords.map((c) {
              final list = c as List;
              return LatLng(
                (list[1] as num).toDouble(),
                (list[0] as num).toDouble(),
              );
            }).toList();

            _distance = (route['distance'] as num).toDouble();
            _duration = (route['duration'] as num).toDouble();
          }
        }
      } finally {
        client.close(force: true);
      }
    } catch (e) {
      if (!mounted) return;
      _routeError = 'Error al calcular ruta. Usando distancia estimada.';
      _calculateFallback();
    } finally {
      _routeTimer?.cancel();
      if (mounted) {
        setState(() => _loadingRoute = false);
      }
    }
  }

  void _calculateFallback() {
    if (_userPosition == null) return;
    _distance = _haversineDistance(_businessLocation, _userPosition!);
    _duration = _distance / 1.4;
    _routePoints = [];
  }

  void _openInGoogleMaps() async {
    final uri = Uri.parse(
      'https://www.google.com/maps/dir/?api=1&destination=$_businessLat,$_businessLng',
    );
    try {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {
      await launchUrl(uri, mode: LaunchMode.platformDefault);
    }
  }

  void _openWhatsApp() async {
    final uri = Uri.parse('https://wa.me/51964834558');
    try {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {
      await launchUrl(uri, mode: LaunchMode.platformDefault);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final distanceKm = _distance / 1000;
    final minutes = (_duration / 60).round();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Nosotros'),
        actions: [
          IconButton(
            tooltip: 'Cerrar sesión',
            onPressed: _authService.signOut,
            icon: const Icon(Icons.logout_rounded),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildInfoSection(theme),
            const SizedBox(height: 20),
            _buildMissionSection(theme),
            const SizedBox(height: 20),
            _buildHoursSection(theme),
            if (_locationReady && _userPosition != null) ...[
              const SizedBox(height: 16),
              _buildDistanceCard(distanceKm, minutes),
            ],
            if (_locationError != null) ...[
              const SizedBox(height: 16),
              _buildErrorCard(_locationError!),
            ],
            if (_routeError != null) ...[
              const SizedBox(height: 8),
              _buildErrorCard(_routeError!),
            ],
            const SizedBox(height: 16),
            _buildMap(theme),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _openInGoogleMaps,
                icon: const Icon(Icons.map_outlined),
                label: const Text('Abrir en Google Maps'),
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _openWhatsApp,
                icon: const Icon(Icons.chat_rounded),
                label: const Text('Contactar por WhatsApp'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF25D366),
                  foregroundColor: Colors.white,
                ),
              ),
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoSection(ThemeData theme) {
    return Card(
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(Icons.storefront_rounded,
                      color: theme.colorScheme.primary, size: 28),
                ),
                const SizedBox(width: 16),
                Text('Infoservice',
                    style: theme.textTheme.titleLarge
                        ?.copyWith(fontWeight: FontWeight.w900)),
              ],
            ),
            const SizedBox(height: 16),
            const Text(
              'Somos una empresa dedicada a la venta y distribución de equipos '
              'de cómputo, accesorios y soluciones tecnológicas en la provincia '
              'de Jauja. Contamos con más de 10 años de experiencia brindando '
              'productos de calidad y asesoría personalizada a nuestros clientes.',
              style: TextStyle(height: 1.5),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMissionSection(ThemeData theme) {
    return Row(
      children: [
        Expanded(
          child: Card(
            margin: EdgeInsets.zero,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.flag_outlined, color: theme.colorScheme.primary),
                  const SizedBox(height: 8),
                  const Text('Misión',
                      style: TextStyle(fontWeight: FontWeight.w800)),
                  const SizedBox(height: 4),
                  const Text(
                    'Brindar soluciones tecnológicas accesibles y de calidad '
                    'a la comunidad jaujina, superando las expectativas de '
                    'nuestros clientes.',
                    style: TextStyle(fontSize: 12, height: 1.4),
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Card(
            margin: EdgeInsets.zero,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.remove_red_eye_outlined,
                      color: theme.colorScheme.primary),
                  const SizedBox(height: 8),
                  const Text('Visión',
                      style: TextStyle(fontWeight: FontWeight.w800)),
                  const SizedBox(height: 4),
                  const Text(
                    'Ser la empresa líder en tecnología en la región Junín, '
                    'reconocida por nuestra calidad de servicio e innovación '
                    'constante.',
                    style: TextStyle(fontSize: 12, height: 1.4),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildHoursSection(ThemeData theme) {
    return Card(
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.access_time_rounded,
                    color: theme.colorScheme.primary),
                const SizedBox(width: 8),
                const Text('Horarios',
                    style:
                        TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
              ],
            ),
            const SizedBox(height: 12),
            _buildDayRow('Lunes — Viernes', '9:00 — 13:00  |  15:00 — 19:00'),
            const Divider(height: 16),
            _buildDayRow('Sábado', '9:00 — 13:00'),
            const Divider(height: 16),
            _buildDayRow('Domingo', 'Cerrado'),
          ],
        ),
      ),
    );
  }

  Widget _buildDayRow(String day, String hours) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(day, style: const TextStyle(fontWeight: FontWeight.w500)),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            hours,
            textAlign: TextAlign.end,
            style: const TextStyle(color: Colors.grey),
          ),
        ),
      ],
    );
  }

  Widget _buildDistanceCard(double km, int min) {
    if (_loadingRoute) {
      return Card(
        margin: EdgeInsets.zero,
        color: Colors.blue.withValues(alpha: 0.1),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: const Padding(
          padding: EdgeInsets.all(16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
              SizedBox(width: 12),
              Text('Calculando ruta...'),
            ],
          ),
        ),
      );
    }

    return Card(
      margin: EdgeInsets.zero,
      color: Colors.blue.withValues(alpha: 0.1),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _buildStat(Icons.route_outlined, '${km.toStringAsFixed(1)} km',
                'Distancia'),
            Container(height: 30, width: 1, color: Colors.grey[300]),
            _buildStat(
                Icons.timer_outlined, '$min min', 'Tiempo estimado'),
          ],
        ),
      ),
    );
  }

  Widget _buildStat(IconData icon, String value, String label) {
    return Column(
      children: [
        Icon(icon, color: Colors.blue),
        const SizedBox(height: 4),
        Text(value,
            style:
                const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        Text(label,
            style: const TextStyle(fontSize: 12, color: Colors.grey)),
      ],
    );
  }

  Widget _buildErrorCard(String message) {
    return Card(
      margin: EdgeInsets.zero,
      color: Colors.orange[50],
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            const Icon(Icons.warning_amber_rounded, color: Colors.orange),
            const SizedBox(width: 12),
            Expanded(
              child: Text(message,
                  style: const TextStyle(color: Colors.orange)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMap(ThemeData theme) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: SizedBox(
        height: 350,
        child: FlutterMap(
          mapController: _mapController,
          options: MapOptions(
            initialCenter: _businessLocation,
            initialZoom: 15,
          ),
          children: [
            TileLayer(
              urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
              userAgentPackageName: 'com.infoservice.cmq',
              tileProvider: NetworkTileProvider(),
            ),
            MarkerLayer(
              markers: [
                Marker(
                  point: _businessLocation,
                  width: 40,
                  height: 40,
                  child: const Icon(Icons.store_rounded,
                      color: Colors.red, size: 36),
                ),
                if (_userPosition != null)
                  Marker(
                    point: _userPosition!,
                    width: 30,
                    height: 30,
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.blue,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 2),
                      ),
                      child: const Icon(Icons.person,
                          color: Colors.white, size: 18),
                    ),
                  ),
              ],
            ),
            if (_routePoints.isNotEmpty)
              PolylineLayer(
                polylines: [
                  Polyline(
                    points: _routePoints,
                    color: Colors.blue,
                    strokeWidth: 4,
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}
