// lib/screens/stations/station_selection_screen.dart
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:ebike/screens/stations/station_model.dart';
import '../journey/journey_start.dart';
import 'package:ebike/core/api/api_client.dart';

class StationSelectionScreen extends StatefulWidget {
  final LatLng startLocation;
  final LatLng endLocation;

  const StationSelectionScreen({
    super.key,
    required this.startLocation,
    required this.endLocation,
  });

  @override
  State<StationSelectionScreen> createState() => _StationSelectionScreenState();
}

class _StationSelectionScreenState extends State<StationSelectionScreen> {
  final _apiClient = ApiClient();
  final _distance = const Distance();

  List<Station> _stations = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _fetchNearbyStations();
  }

  Future<void> _fetchNearbyStations() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      // Use the passed-in startLocation to query nearby stations
      final response = await _apiClient.getNearbyStations(
        latitude: widget.startLocation.latitude,
        longitude: widget.startLocation.longitude,
        // maxDistance: 5000, // optional
      );

      if (response.statusCode != 200) {
        throw Exception('Server returned ${response.statusCode}');
      }

      final data = response.data;

      // Accept either a raw List or { "stations": [...] }
      List list;
      if (data is List) {
        list = data;
      } else if (data is Map && data['stations'] is List) {
        list = data['stations'];
      } else if (data is String) {
        final parsed = jsonDecode(data);
        if (parsed is List) {
          list = parsed;
        } else if (parsed is Map && parsed['stations'] is List) {
          list = parsed['stations'];
        } else {
          throw Exception('Unexpected stations response shape');
        }
      } else {
        throw Exception('Unexpected stations response shape');
      }

      final stations = list
          .whereType<Map>() // ignore non-map entries
          .map((m) => Station.fromJson(m.cast<String, dynamic>()))
          .toList();

      // Sort by distance from start
      stations.sort((a, b) {
        final da = _distance.distance(
          widget.startLocation,
          LatLng(a.latitude, a.longitude),
        );
        final db = _distance.distance(
          widget.startLocation,
          LatLng(b.latitude, b.longitude),
        );
        return da.compareTo(db);
      });

      if (!mounted) return;
      setState(() {
        _stations = stations;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString());
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error loading stations: $e')),
      );
    } finally {
      if (!mounted) return;
      setState(() => _isLoading = false);
    }
  }

  void _showStationDetails(Station station) {
    showModalBottomSheet(
      context: context,
      builder: (context) {
        final meters = _distance.distance(
          widget.startLocation,
          LatLng(station.latitude, station.longitude),
        );
        final km = meters / 1000.0;

        return Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(station.name,
                  style: const TextStyle(
                      fontSize: 20, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Text('Available bikes: ${station.availableBikes}'),
              const SizedBox(height: 4),
              Text('Distance: ${km.toStringAsFixed(2)} km'),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) =>
                          JourneyStartScreen(stationId: station.id),
                    ),
                  );
                },
                child: const Text('Start Journey at This Station'),
              ),
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final markers = _stations
        .map(
          (s) => Marker(
            point: LatLng(s.latitude, s.longitude),
            child: GestureDetector(
              onTap: () => _showStationDetails(s),
              child: const Icon(
                Icons.pedal_bike,
                color: Colors.deepPurpleAccent,
                size: 40,
              ),
            ),
          ),
        )
        .toList();

    // Add a marker for the user's start location for reference
    final startMarker = Marker(
      point: widget.startLocation,
      child: const Icon(
        Icons.my_location,
        size: 28,
      ),
    );

    return Scaffold(
      appBar: AppBar(
        title: const Text('Select a Station'),
        actions: [
          IconButton(
            onPressed: _isLoading ? null : _fetchNearbyStations,
            icon: const Icon(Icons.refresh, size: 20),
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.error_outline, size: 36),
                        const SizedBox(height: 8),
                        Text(
                          'Failed to load stations.\n$_error',
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 12),
                        ElevatedButton(
                          onPressed: _fetchNearbyStations,
                          child: const Text('Try again'),
                        ),
                      ],
                    ),
                  ),
                )
              : Column(
                  children: [
                    Expanded(
                      flex: 3,
                      child: FlutterMap(
                        options: MapOptions(
                          initialCenter: widget.startLocation,
                          initialZoom: 14,
                        ),
                        children: [
                          TileLayer(
                            urlTemplate:
                                "https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png",
                            subdomains: const ['a', 'b', 'c'],
                          ),
                          MarkerLayer(markers: [startMarker, ...markers]),
                        ],
                      ),
                    ),
                    Expanded(
                      flex: 2,
                      child: _stations.isEmpty
                          ? const Center(child: Text('No stations found nearby'))
                          : ListView.separated(
                              itemCount: _stations.length,
                              separatorBuilder: (_, __) =>
                                  const Divider(height: 1),
                              itemBuilder: (context, index) {
                                final station = _stations[index];
                                final meters = _distance.distance(
                                  widget.startLocation,
                                  LatLng(station.latitude, station.longitude),
                                );
                                final km = meters / 1000.0;

                                return ListTile(
                                  leading: const Icon(Icons.ev_station),
                                  title: Text(station.name),
                                  subtitle: Text(
                                    'Available bikes: ${station.availableBikes} • ${km.toStringAsFixed(2)} km',
                                  ),
                                  onTap: () => _showStationDetails(station),
                                );
                              },
                            ),
                    ),
                  ],
                ),
    );
  }
}
