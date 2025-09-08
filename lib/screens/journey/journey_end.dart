// lib/screens/journey/screens/journey_end_screen.dart
import 'package:flutter/material.dart';
import 'package:ebike/core/api/api_client.dart';
import '../qr_screen.dart';

class JourneyEndScreen extends StatelessWidget {
  final String bikeId;
  final ApiClient _apiClient = ApiClient();

  JourneyEndScreen({required this.bikeId});

  get context => null;

  Future<void> _endJourney(BuildContext context) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder:
            (context) => QrScanScreen(
              onScan: (stationId) => _handleScannedStation(stationId),
              isStation: true,
            ),
      ),
    );
  }

  Future<void> _handleScannedStation(String stationId) async {
    try {
      final response = await _apiClient.endJourney(bikeId, stationId);
      if (response.statusCode == 200) {
        await _apiClient.updateBikeStatus(bikeId, 'available');
        showDialog(
          context: context,
          builder:
              (_) => AlertDialog(
                title: Text('Journey Ended'),
                content: Text(
                  'Total Cost: \$${response.data['cost'].toStringAsFixed(2)}',
                ),
                actions: [
                  TextButton(
                    onPressed:
                        () => Navigator.popUntil(
                          context,
                          (route) => route.isFirst,
                        ),
                    child: Text('OK'),
                  ),
                ],
              ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error ending journey: ${e.toString()}')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('End Journey')),
      body: Center(
        child: ElevatedButton(
          onPressed: () => _endJourney(context),
          child: Text('Scan Station QR to End Journey'),
        ),
      ),
    );
  }
}
