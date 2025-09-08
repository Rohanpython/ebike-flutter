import 'package:ebike/core/auth_helper.dart';
import 'package:ebike/screens/auth/login_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'package:permission_handler/permission_handler.dart';
import '../stations/station_selection_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _startLocationController = TextEditingController();
  final _endLocationController = TextEditingController();
  final _mapController = MapController();
  LatLng _currentPosition = const LatLng(0, 0);
  LatLng? _startLocation;
  LatLng? _endLocation;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _requestLocationPermission();
  }

  Future<void> _requestLocationPermission() async {
    final status = await Permission.location.request();
    if (status.isGranted) {
      await _getCurrentLocation();
    } else {
      if (!mounted) return;
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Location permission denied')),
      );
    }
  }

  Future<void> _getCurrentLocation() async {
    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        if (!mounted) return;
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Location services are disabled')),
        );
        return;
      }
      final position = await Geolocator.getCurrentPosition();
      if (!mounted) return;
      setState(() {
        _currentPosition = LatLng(position.latitude, position.longitude);
        _startLocation = LatLng(position.latitude, position.longitude);
        _startLocationController.text = "My Location";
        _isLoading = false;
      });
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _mapController.move(_currentPosition, 15);
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error getting location: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('eBike Rental'),
        actions: [
          IconButton(
            icon: const Icon(Icons.exit_to_app, size: 20, color: Colors.black),
            onPressed: () async {
              await AuthHelper.instance.signOut();
              if (!mounted) return;
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(builder: (_) => LoginScreen()),
              );
            },
          ),
        ],
        actionsPadding: const EdgeInsets.only(right: 20),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    children: [
                      TextField(
                        controller: _startLocationController,
                        decoration: InputDecoration(
                          labelText: 'Start Location',
                          suffixIcon: IconButton(
                            icon: const Icon(Icons.search),
                            onPressed: () => _searchLocation(
                                _startLocationController.text, true),
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: _endLocationController,
                        decoration: InputDecoration(
                          labelText: 'End Location',
                          suffixIcon: IconButton(
                            icon: const Icon(Icons.search),
                            onPressed: () => _searchLocation(
                                _endLocationController.text, false),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: _startLocation != null ? _findStations : null,
                        child: const Text('Find Stations'),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: FlutterMap(
                    mapController: _mapController,
                    options: MapOptions(
                      initialCenter: _currentPosition,
                      initialZoom: 15.0,
                      onMapReady: () {
                        _mapController.move(_currentPosition, 15);
                      },
                    ),
                    children: [
                      TileLayer(
                        urlTemplate:
                            "https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png",
                        subdomains: const ['a', 'b', 'c'],
                      ),
                      MarkerLayer(
                        markers: [
                          if (_startLocation != null)
                            Marker(
                              width: 40.0,
                              height: 40.0,
                              point: _startLocation!,
                              child: const Icon(
                                Icons.location_pin,
                                color: Colors.blue,
                                size: 40.0,
                              ),
                            ),
                          if (_endLocation != null)
                            Marker(
                              width: 40.0,
                              height: 40.0,
                              point: _endLocation!,
                              child: const Icon(
                                Icons.location_pin,
                                color: Colors.red,
                                size: 40.0,
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
    );
  }

  Future<void> _searchLocation(String address, bool isStart) async {
    if (address.isEmpty) return;
    try {
      final locations = await locationFromAddress(address);
      if (locations.isNotEmpty) {
        final location = locations.first;
        final latLng = LatLng(location.latitude, location.longitude);
        if (!mounted) return;
        setState(() {
          if (isStart) {
            _startLocation = latLng;
          } else {
            _endLocation = latLng;
          }
        });
        _mapController.move(latLng, 15);
      }
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Location not found')),
      );
    }
  }

  void _findStations() {
    if (_startLocation == null) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => StationSelectionScreen(
          startLocation: _startLocation!,
          endLocation: _endLocation ?? _startLocation!,
        ),
      ),
    );
  }

  @override
  void dispose() {
    _mapController.dispose();
    _startLocationController.dispose();
    _endLocationController.dispose();
    super.dispose();
  }
}
