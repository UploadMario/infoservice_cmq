import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:infoservice_cmq/widgets/custom_app_bar.dart';

class DeliveryTrackingScreen extends StatefulWidget {
  final String orderId;
  final Map<String, dynamic> data;

  const DeliveryTrackingScreen({
    super.key,
    required this.orderId,
    required this.data,
  });

  @override
  State<DeliveryTrackingScreen> createState() => _DeliveryTrackingScreenState();
}

class _DeliveryTrackingScreenState extends State<DeliveryTrackingScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final MapController _mapController = MapController();
  Timer? _timer;

  LatLng? _businessLocation;
  LatLng? _userLocation;
  LatLng? _deliveryLocation;
  List<LatLng> _routePoints = [];
  double _distance = 0;
  double _duration = 0;
  String _status = '';
  Timestamp? _fechaPedido;
  Timestamp? _fechaInicioEnvio;
  double _progress = 0;


  String _statusText = '';
  Color _statusColor = Colors.grey;

  @override
  void initState() {
    super.initState();
    _initData();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _mapController.dispose();
    super.dispose();
  }

  void _initData() {
    final negocio = widget.data['ubicacionNegocio'] as GeoPoint?;
    final usuario = widget.data['ubicacionUsuario'] as GeoPoint?;
    if (negocio != null) {
      _businessLocation = LatLng(negocio.latitude, negocio.longitude);
    }
    if (usuario != null) {
      _userLocation = LatLng(usuario.latitude, usuario.longitude);
    }

    _status = widget.data['estado'] as String? ?? 'preparando';
    _fechaPedido = widget.data['fechaPedido'] as Timestamp?;
    _fechaInicioEnvio = widget.data['fechaInicioEnvio'] as Timestamp?;
    _distance = (widget.data['distancia'] as num?)?.toDouble() ?? 0;
    _duration = (widget.data['duracion'] as num?)?.toDouble() ?? 0;

    if (_businessLocation != null && _userLocation != null) {
      _fetchRoute();
    }

    _updateStatusDisplay();

    _timer = Timer.periodic(const Duration(seconds: 5), (_) => _tick());
  }

  Future<void> _fetchRoute() async {
    if (_businessLocation == null || _userLocation == null) return;

    try {
      _deliveryLocation = _businessLocation;

      final url = Uri.parse(
        'https://router.project-osrm.org/route/v1/driving/'
        '${_businessLocation!.longitude},${_businessLocation!.latitude};'
        '${_userLocation!.longitude},${_userLocation!.latitude}'
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
            final osrmDuration = (route['duration'] as num?)?.toDouble() ?? 0;
            if (osrmDuration > 0) {
              _duration = osrmDuration;
            }
            final geometry = route['geometry'] as Map<String, dynamic>;
            final coords = geometry['coordinates'] as List;

            _routePoints = coords.map((c) {
              final list = c as List;
              return LatLng(
                (list[1] as num).toDouble(),
                (list[0] as num).toDouble(),
              );
            }).toList();
          }
        }
      } finally {
        client.close(force: true);
      }
    } catch (_) {}

    if (_duration <= 0 && _distance > 0) {
      _duration = _distance / 10;
    }

    if (mounted) setState(() {});
  }

  void _tick() {
    _updateStatusFromTime();
    _updateDeliveryPosition();
    _updateStatusDisplay();
    if (mounted) setState(() {});
  }

  void _updateStatusFromTime() {
    if (_status == 'cancelado') return;

    if (_status == 'preparando') {
      if (_fechaPedido == null) return;
      final elapsed = DateTime.now().difference(_fechaPedido!.toDate());
      if (elapsed.inMinutes >= 5) {
        _transitionTo('en_camino');
      }
      return;
    }

    if (_status == 'en_camino') {
      if (_fechaInicioEnvio == null || _duration <= 0) return;
      final elapsed = DateTime.now().difference(_fechaInicioEnvio!.toDate());
      if (elapsed.inSeconds >= _duration.round()) {
        _transitionTo('completado');
      }
      return;
    }
  }

  void _transitionTo(String newStatus) async {
    _status = newStatus;
    final updates = <String, dynamic>{'estado': newStatus};
    if (newStatus == 'en_camino') {
      updates['fechaInicioEnvio'] = FieldValue.serverTimestamp();
      _fechaInicioEnvio = Timestamp.now();
    } else if (newStatus == 'completado') {
      updates['fechaCompletado'] = FieldValue.serverTimestamp();
      _deliveryLocation = _userLocation;
    }
    await _firestore
        .collection('historial_compras')
        .doc(widget.orderId)
        .update(updates);
  }

  void _updateDeliveryPosition() {
    if (_status == 'completado') {
      _deliveryLocation = _userLocation;
      _progress = 1.0;
      return;
    }
    if (_status != 'en_camino') {
      _deliveryLocation = _businessLocation;
      _progress = 0;
      return;
    }
    if (_fechaInicioEnvio == null || _duration <= 0) return;

    final elapsed = DateTime.now().difference(_fechaInicioEnvio!.toDate());
    _progress = (elapsed.inSeconds / _duration).clamp(0.0, 1.0);

    if (_routePoints.length >= 2) {
      final totalLength = _calculatePolylineLength(_routePoints);
      final targetDist = totalLength * _progress;
      _deliveryLocation = _interpolateAlongPolyline(_routePoints, targetDist);
    } else if (_businessLocation != null && _userLocation != null) {
      final lat = _businessLocation!.latitude +
          (_userLocation!.latitude - _businessLocation!.latitude) * _progress;
      final lng = _businessLocation!.longitude +
          (_userLocation!.longitude - _businessLocation!.longitude) * _progress;
      _deliveryLocation = LatLng(lat, lng);
    }
  }

  double _calculatePolylineLength(List<LatLng> points) {
    double total = 0;
    for (int i = 0; i < points.length - 1; i++) {
      total += _distanceBetween(points[i], points[i + 1]);
    }
    return total;
  }

  double _distanceBetween(LatLng a, LatLng b) {
    const R = 6371000;
    final dLat = (b.latitude - a.latitude) * pi / 180;
    final dLng = (b.longitude - a.longitude) * pi / 180;
    final sinDLat = sin(dLat / 2);
    final sinDLng = sin(dLng / 2);
    final a2 = sinDLat * sinDLat +
        cos(a.latitude * pi / 180) *
            cos(b.latitude * pi / 180) *
            sinDLng * sinDLng;
    return R * 2 * atan2(sqrt(a2), sqrt(1 - a2));
  }

  LatLng _interpolateAlongPolyline(List<LatLng> points, double targetDist) {
    double accumulated = 0;
    for (int i = 0; i < points.length - 1; i++) {
      final segDist = _distanceBetween(points[i], points[i + 1]);
      if (accumulated + segDist >= targetDist) {
        final t = (targetDist - accumulated) / segDist;
        return LatLng(
          points[i].latitude + (points[i + 1].latitude - points[i].latitude) * t,
          points[i].longitude + (points[i + 1].longitude - points[i].longitude) * t,
        );
      }
      accumulated += segDist;
    }
    return points.last;
  }

  void _updateStatusDisplay() {
    switch (_status) {
      case 'preparando':
        _statusText = 'Preparando envío';
        _statusColor = Colors.orange;
      case 'en_camino':
        _statusText = 'En camino';
        _statusColor = Colors.blue;
      case 'completado':
        _statusText = 'Entregado';
        _statusColor = Colors.green;
      case 'cancelado':
        _statusText = 'Cancelado';
        _statusColor = Colors.grey;
      default:
        _statusText = _status;
        _statusColor = Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final etaMin = _duration > 0 && _status == 'en_camino'
        ? ((1 - _progress) * _duration / 60).round()
        : 0;

    return Scaffold(
      appBar: const CustomAppBar(),
      body: _businessLocation == null || _userLocation == null
          ? const Center(child: Text('Datos de ubicación no disponibles'))
          : Column(
              children: [
                _buildStatusHeader(theme, etaMin),
                Expanded(child: _buildMap()),
                _buildProgressBar(theme),
              ],
            ),
    );
  }

  Widget _buildStatusHeader(ThemeData theme, int etaMin) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: _statusColor.withValues(alpha: 0.1),
        border: Border(bottom: BorderSide(color: theme.dividerColor)),
      ),
      child: Row(
        children: [
          if (_status == 'preparando')
            const SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(strokeWidth: 2.5),
            )
          else if (_status == 'en_camino')
            const Icon(Icons.local_shipping_rounded, size: 24)
          else if (_status == 'completado')
            const Icon(Icons.check_circle, size: 24, color: Colors.green)
          else
            const Icon(Icons.cancel, size: 24, color: Colors.grey),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _statusText,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: _statusColor,
                  ),
                ),
                if (_status == 'en_camino' && etaMin > 0)
                  Text(
                    'Llega aprox. en $etaMin min',
                    style: const TextStyle(fontSize: 13, color: Colors.grey),
                  ),
                if (_status == 'preparando')
                  const Text(
                    'Empaquetando tu pedido...',
                    style: TextStyle(fontSize: 13, color: Colors.grey),
                  ),
                if (widget.data['direccion'] is String &&
                    (widget.data['direccion'] as String).isNotEmpty)
                  Text(
                    'Entregar en: ${widget.data['direccion']}',
                    style: const TextStyle(fontSize: 12, color: Colors.grey),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMap() {
    return FlutterMap(
      mapController: _mapController,
      options: MapOptions(
        initialCenter: _businessLocation!,
        initialZoom: 14,
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
              point: _businessLocation!,
              width: 36,
              height: 36,
              child: const Icon(Icons.store_rounded, color: Colors.red, size: 32),
            ),
            Marker(
              point: _userLocation!,
              width: 30,
              height: 30,
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.blue,
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 2),
                ),
                child: const Icon(Icons.person, color: Colors.white, size: 18),
              ),
            ),
            if (_deliveryLocation != null && _status != 'completado')
              Marker(
                point: _deliveryLocation!,
                width: 28,
                height: 28,
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.green,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 2.5),
                  ),
                  child: const Icon(Icons.local_shipping,
                      color: Colors.white, size: 16),
                ),
              ),
          ],
        ),
        if (_routePoints.isNotEmpty)
          PolylineLayer(
            polylines: [
              Polyline(
                points: _routePoints,
                color: Colors.blue.withValues(alpha: 0.5),
                strokeWidth: 3,
              ),
            ],
          ),
      ],
    );
  }

  Widget _buildProgressBar(ThemeData theme) {
    return Container(
      padding: EdgeInsets.fromLTRB(
        20, 12, 20, 12 + MediaQuery.of(context).padding.bottom,
      ),
      decoration: BoxDecoration(
        color: theme.scaffoldBackgroundColor,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 8,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildDot('Preparando', _status == 'preparando' || _status == 'en_camino' || _status == 'completado'),
              _buildDot('En camino', _status == 'en_camino' || _status == 'completado'),
              _buildDot('Entregado', _status == 'completado'),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: _status == 'cancelado' ? 0 : _progress,
              minHeight: 6,
              backgroundColor: Colors.grey[200],
              valueColor: AlwaysStoppedAnimation(
                _status == 'cancelado' ? Colors.grey : Colors.green,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDot(String label, bool active) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          active ? Icons.check_circle : Icons.radio_button_unchecked,
          size: 16,
          color: active ? (_status == 'completado' ? Colors.green : _statusColor) : Colors.grey,
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: TextStyle(
            fontSize: 10,
            color: active ? _statusColor : Colors.grey,
          ),
        ),
      ],
    );
  }
}
