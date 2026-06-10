import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

class LocationPickerScreen extends StatefulWidget {
  final double initialLat;
  final double initialLng;

  const LocationPickerScreen({
    super.key,
    required this.initialLat,
    required this.initialLng,
  });

  @override
  State<LocationPickerScreen> createState() => _LocationPickerScreenState();
}

class _LocationPickerScreenState extends State<LocationPickerScreen> {
  final MapController _mapController = MapController();
  final TextEditingController _addressController = TextEditingController();
  LatLng _selectedLocation = const LatLng(0, 0);

  @override
  void initState() {
    super.initState();
    _selectedLocation = LatLng(widget.initialLat, widget.initialLng);
  }

  @override
  void dispose() {
    _addressController.dispose();
    _mapController.dispose();
    super.dispose();
  }

  void _onMapMoved() {
    setState(() {
      _selectedLocation = _mapController.camera.center;
    });
  }

  void _confirm() {
    Navigator.pop(context, {
      'lat': _selectedLocation.latitude,
      'lng': _selectedLocation.longitude,
      'direccion': _addressController.text.trim(),
    });
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).padding.bottom;

    return Scaffold(
      appBar: AppBar(title: const Text('Elegir ubicación de entrega')),
      body: Stack(
        children: [
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: _selectedLocation,
              initialZoom: 15,
              onMapEvent: (_) => _onMapMoved(),
            ),
            children: [
              TileLayer(
                urlTemplate:
                    'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.infoservice.cmq',
                tileProvider: NetworkTileProvider(),
              ),
              MarkerLayer(
                markers: [
                  Marker(
                    point: _businessLocation,
                    width: 36,
                    height: 36,
                    child: const Icon(Icons.store_rounded,
                        color: Colors.red, size: 32),
                  ),
                ],
              ),
            ],
          ),
          Center(
            child: Transform.translate(
              offset: const Offset(0, -30),
              child: const Icon(Icons.location_on,
                  color: Colors.blue, size: 42),
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: Container(
              padding: EdgeInsets.fromLTRB(16, 16, 16, 16 + bottom),
              decoration: BoxDecoration(
                color: Theme.of(context).scaffoldBackgroundColor,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.1),
                    blurRadius: 8,
                    offset: const Offset(0, -2),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: _addressController,
                    decoration: InputDecoration(
                      hintText: 'Dirección de entrega (ej: Jr. Colina 410)',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      prefixIcon: const Icon(Icons.edit_location_alt,
                          size: 20),
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 12),
                      isDense: true,
                    ),
                    textInputAction: TextInputAction.done,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Arrastra el mapa para ajustar la ubicación',
                    style: TextStyle(
                        fontSize: 12, color: Colors.grey[600]),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: _confirm,
                      icon: const Icon(Icons.check, size: 18),
                      label: const Text('Confirmar ubicación'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

const _businessLocation = LatLng(-11.7775086, -75.499446);
