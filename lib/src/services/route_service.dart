import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';

class RoadRoute {
  const RoadRoute({required this.distanceMeters, required this.durationSeconds, required this.points, required this.trafficAware});
  final double distanceMeters;
  final double durationSeconds;
  final List<LatLng> points;
  final bool trafficAware;
  double get distanceKm => distanceMeters / 1000;
  int get durationMinutes => (durationSeconds / 60).ceil().clamp(1, 9999).toInt();
}

class RouteService {
  const RouteService();
  static const googleRoutesApiKey = String.fromEnvironment('GOOGLE_ROUTES_API_KEY');

  Future<RoadRoute> fetchDrivingRoute({required LatLng origin, required LatLng destination}) async {
    if (googleRoutesApiKey.isNotEmpty) {
      try {
        return await _fetchGoogleTrafficRoute(origin: origin, destination: destination);
      } catch (_) {
        // Keep tracking available if Google quota, key, or network fails.
      }
    }
    return _fetchOsrmRoute(origin: origin, destination: destination);
  }

  Future<RoadRoute> _fetchGoogleTrafficRoute({required LatLng origin, required LatLng destination}) async {
    final response = await http.post(
      Uri.parse('https://routes.googleapis.com/directions/v2:computeRoutes'),
      headers: const {
        'Content-Type': 'application/json',
        'X-Goog-Api-Key': googleRoutesApiKey,
        'X-Goog-FieldMask': 'routes.duration,routes.distanceMeters,routes.polyline.encodedPolyline',
      },
      body: jsonEncode({
        'origin': {'location': {'latLng': {'latitude': origin.latitude, 'longitude': origin.longitude}}},
        'destination': {'location': {'latLng': {'latitude': destination.latitude, 'longitude': destination.longitude}}},
        'travelMode': 'DRIVE',
        'routingPreference': 'TRAFFIC_AWARE_OPTIMAL',
        'computeAlternativeRoutes': false,
        'languageCode': 'en-US',
        'units': 'METRIC',
      }),
    ).timeout(const Duration(seconds: 15));
    if (response.statusCode != 200) throw StateError('Google Routes returned ${response.statusCode}.');
    final decoded = jsonDecode(response.body) as Map<String, dynamic>;
    final routes = decoded['routes'] as List<dynamic>?;
    if (routes == null || routes.isEmpty) throw StateError('Google Routes returned no route.');
    final route = routes.first as Map<String, dynamic>;
    final durationText = route['duration'] as String? ?? '0s';
    final encodedPolyline = (route['polyline'] as Map<String, dynamic>?)?['encodedPolyline'] as String? ?? '';
    return RoadRoute(
      distanceMeters: (route['distanceMeters'] as num).toDouble(),
      durationSeconds: double.parse(durationText.replaceFirst('s', '')),
      points: _decodeGooglePolyline(encodedPolyline),
      trafficAware: true,
    );
  }

  Future<RoadRoute> _fetchOsrmRoute({required LatLng origin, required LatLng destination}) async {
    final uri = Uri.https(
      'router.project-osrm.org',
      '/route/v1/driving/${origin.longitude},${origin.latitude};${destination.longitude},${destination.latitude}',
      {'overview': 'full', 'geometries': 'geojson', 'steps': 'false'},
    );
    final response = await http.get(uri).timeout(const Duration(seconds: 12));
    if (response.statusCode != 200) throw StateError('Routing service returned ${response.statusCode}.');
    final decoded = jsonDecode(response.body) as Map<String, dynamic>;
    final routes = decoded['routes'] as List<dynamic>?;
    if (decoded['code'] != 'Ok' || routes == null || routes.isEmpty) throw StateError('No drivable route was found.');
    final route = routes.first as Map<String, dynamic>;
    final coordinates = (route['geometry'] as Map<String, dynamic>)['coordinates'] as List<dynamic>;
    final points = coordinates.map((coordinate) {
      final pair = coordinate as List<dynamic>;
      return LatLng((pair[1] as num).toDouble(), (pair[0] as num).toDouble());
    }).toList(growable: false);
    return RoadRoute(
      distanceMeters: (route['distance'] as num).toDouble(),
      durationSeconds: (route['duration'] as num).toDouble(),
      points: points,
      trafficAware: false,
    );
  }

  List<LatLng> _decodeGooglePolyline(String encoded) {
    if (encoded.isEmpty) return const [];
    final points = <LatLng>[];
    var index = 0;
    var latitude = 0;
    var longitude = 0;
    while (index < encoded.length) {
      final lat = _decodeValue(encoded, index);
      index = lat.nextIndex;
      latitude += lat.value;
      final lng = _decodeValue(encoded, index);
      index = lng.nextIndex;
      longitude += lng.value;
      points.add(LatLng(latitude / 1e5, longitude / 1e5));
    }
    return points;
  }

  ({int value, int nextIndex}) _decodeValue(String encoded, int startIndex) {
    var index = startIndex;
    var result = 0;
    var shift = 0;
    int byte;
    do {
      if (index >= encoded.length) throw const FormatException('Invalid route polyline.');
      byte = encoded.codeUnitAt(index++) - 63;
      result |= (byte & 0x1f) << shift;
      shift += 5;
    } while (byte >= 0x20);
    return (value: (result & 1) != 0 ? ~(result >> 1) : result >> 1, nextIndex: index);
  }
}
