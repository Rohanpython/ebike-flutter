import 'package:flutter/material.dart';
import 'package:ebike/screens/journey/journey_active.dart';
import '../qr_screen.dart';
import 'package:ebike/core/api/api_client.dart';
class JourneyStartScreen extends StatefulWidget {
  final String stationId; // Station where the journey starts
  const JourneyStartScreen({super.key, required this.stationId});

  @override
  State<JourneyStartScreen> createState() => _JourneyStartScreenState();
}

class _JourneyStartScreenState extends State<JourneyStartScreen> {
  final _apiClient = ApiClient();
  bool _isLoading = false;

  Future<void> _scanBikeQR() async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) =>
            QrScanScreen(onScan: _handleScannedBike, isStation: false),
      ),
    );
  }

  Future<bool> _handleScannedBike(String bikeQr) async {
    if (_isLoading || !mounted) return false;
    setState(() => _isLoading = true);

    try {
      // 1) quick status check
      final bikeStatus = await _apiClient.getBikeStatus(bikeQr);
      if (bikeStatus == 'in_use') {
        if (!mounted) return false;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Bike is already in use')),
        );
        return false;
      }

      // 2) start journey
          final response = await _apiClient.startJourney(
      bikeQr: bikeQr,
      stationId: widget.stationId,
    );

      final code = response.statusCode ?? 0;
      if (code != 200 && code != 201) {
        throw Exception('Server returned $code');
      }

      // 3) parse journey info (optional for now)
      String? journeyId;
      String? bikeId;
      final body = response.data;
      if (body is Map) {
        // flat
        if (body['journeyId'] is String) journeyId = body['journeyId'];
        if (body['bikeId'] is String) bikeId = body['bikeId'];
        // nested
        if (journeyId == null &&
            body['data'] is Map &&
            body['data']['journeyId'] is String) {
          journeyId = body['data']['journeyId'];
        }
        if (bikeId == null &&
            body['data'] is Map &&
            body['data']['bikeId'] is String) {
          bikeId = body['data']['bikeId'];
        }
      }

      // 4) close the scanner screen if still on stack
      if (mounted && Navigator.of(context).canPop()) {
        Navigator.of(context).pop();
      }

      // 5) go to your existing active screen
      if (!mounted) return true;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => JourneyActive(bikeQr, DateTime.now()),
          // if you later add journeyId to JourneyActive, pass it here
        ),
      );

      return true;
    } catch (e) {
      if (!mounted) return false;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error starting journey: $e')),
      );
      return false;
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final child = _isLoading
        ? const CircularProgressIndicator()
        : const Text('Scan Bike QR to Start Journey');

    return Scaffold(
      appBar: AppBar(title: const Text('Journey Tracking')),
      body: Center(
        child: ElevatedButton(
          onPressed: _isLoading ? null : _scanBikeQR,
          child: child,
        ),
      ),
    );
  }
}
