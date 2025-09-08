import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:ebike/core/constants.dart'; // const String baseUrl = 'http://localhost:5000/api';

class ApiClient {
  // Singleton with a public constructor, so `ApiClient()` works
  static final ApiClient _instance = ApiClient._internal();
  factory ApiClient() => _instance;
  ApiClient._internal() {
    _dio = Dio(
      BaseOptions(
        baseUrl: baseUrl, // e.g. http://localhost:5000/api
        headers: const {'Content-Type': 'application/json'},
        connectTimeout: const Duration(seconds: 8),
        receiveTimeout: const Duration(seconds: 20),
      ),
    );

    _dio.interceptors.add(InterceptorsWrapper(
      onRequest: (options, handler) async {
        final user = FirebaseAuth.instance.currentUser;
        final idToken = await user?.getIdToken(); // refreshes if needed
        if (idToken != null) {
          options.headers['Authorization'] = 'Bearer $idToken';
        }
        handler.next(options);
      },
      onError: (DioException e, handler) async {
        if (e.response?.statusCode == 401 && e.requestOptions.extra['__retried__'] != true) {
          try {
            final user = FirebaseAuth.instance.currentUser;
            final freshToken = await user?.getIdToken(true); // force refresh
            if ((freshToken ?? '').isNotEmpty) {
              final req = e.requestOptions;
              req.headers['Authorization'] = 'Bearer $freshToken';
              req.extra['__retried__'] = true;
              final retry = await _dio.fetch(req);
              return handler.resolve(retry);
            }
          } catch (_) {}
        }
        handler.next(e);
      },
    ));
  }

  late final Dio _dio;

  Future<Response> getNearbyStations({
    required double latitude,
    required double longitude,
    int maxDistance = 5000,
  }) {
    return _dio.get('/stations/nearby', queryParameters: {
      'latitude': latitude,
      'longitude': longitude,
      'maxDistance': maxDistance,
    });
  }

  Future<Response> startJourney({required String bikeQr, required String stationId}) {
    return _dio.post('/journeys/start', data: jsonEncode({'bikeQr': bikeQr, 'stationId': stationId}));
  }

  Future<Response> endJourney({required String bikeId, required String stationId}) {
    return _dio.post('/journeys/end', data: jsonEncode({'bikeId': bikeId, 'stationId': stationId}));
  }

  Future<String> getBikeStatus(String bikeId) async {
    final res = await _dio.get('/bikes/$bikeId');
    return (res.data['bike'] as Map)['status'] as String;
    // adjust mapping if your API differs
  }

  Future<Response> updateBikeStatus(String bikeId, String status) {
    return _dio.patch('/bikes/$bikeId', data: jsonEncode({'status': status}));
  }
}
