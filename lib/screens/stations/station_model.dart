// lib/screens/stations/station_model.dart
class Station {
  final String id;
  final String name;
  final double latitude;   // GeoJSON: [lon, lat]
  final double longitude;
  final int availableBikes;

  Station({
    required this.id,
    required this.name,
    required this.latitude,
    required this.longitude,
    required this.availableBikes,
  });

  factory Station.fromJson(Map<String, dynamic> json) {
    // ---- id / name ----
    final id = (json['_id'] ?? json['id'] ?? '').toString();
    final name = (json['name'] ?? 'Unknown').toString();

    // ---- coordinates: GeoJSON [lon, lat] ----
    double lat = 0, lon = 0;
    try {
      final loc = (json['location'] ?? {}) as Map<String, dynamic>;
      final coords = (loc['coordinates'] ?? []) as List;
      if (coords.length >= 2) {
        // coords[0] = lon, coords[1] = lat
        final c0 = coords[0];
        final c1 = coords[1];
        lon = (c0 is num) ? c0.toDouble() : double.parse(c0.toString());
        lat = (c1 is num) ? c1.toDouble() : double.parse(c1.toString());
      }
    } catch (_) {
      // keep defaults (0,0) if anything goes wrong
    }

    // ---- availableBikes can be int or List ----
    int availableCount = 0;
    final ab = json['availableBikes'];
    if (ab is int) {
      availableCount = ab;
    } else if (ab is List) {
      // Count by status=='available' when present; otherwise count all.
      try {
        availableCount = ab.where((b) {
          if (b is Map) {
            final s = b['status'];
            if (s is String) return s.toLowerCase() == 'available';
            if (s is bool) return s; // true means available
          }
          // If unknown structure, include it to avoid undercount
          return true;
        }).length;
      } catch (_) {
        availableCount = ab.length;
      }
    } else if (json['availableBikesCount'] is int) {
      // Optional: some APIs send a precomputed count
      availableCount = json['availableBikesCount'] as int;
    }

    return Station(
      id: id,
      name: name,
      latitude: lat,
      longitude: lon,
      availableBikes: availableCount,
    );
  }

  Map<String, dynamic> toJson() => {
        '_id': id,
        'name': name,
        'location': {
          'type': 'Point',
          'coordinates': [longitude, latitude], // GeoJSON order
        },
        'availableBikesCount': availableBikes,
      };
}
