import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../qr_screen.dart';
import '../home/home_screen.dart';
import 'package:ebike/core/api/api_client.dart';

final _apiClient = ApiClient();

class JourneyActive extends StatefulWidget {
  final String bikeQr;
  final DateTime startTime;

  const JourneyActive(this.bikeQr, this.startTime, {super.key});

  @override
  State<JourneyActive> createState() => _JourneyActiveState();
}

class _JourneyActiveState extends State<JourneyActive> {
  final _apiClient = ApiClient();
  late Duration _duration;
  Timer? _timer;
  bool _isEnding = false;

  @override
  void initState() {
    super.initState();
    _duration = Duration.zero;
    _startTimer();
  }

  void _startTimer() {
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() {
        _duration = DateTime.now().difference(widget.startTime);
      });
    });
  }

  String _formatDuration(Duration d) {
    final h = d.inHours;
    final m = d.inMinutes.remainder(60);
    final s = d.inSeconds.remainder(60);
    return '${h}h ${m}m ${s}s';
  }

  Future<void> _endJourney() async {
    if (_isEnding) return;

    final stationId = await Navigator.push<String>(
      context,
      MaterialPageRoute(
        builder: (context) =>
            QrScanScreen(onScan: (stationQr) => stationQr, isStation: true),
      ),
    );

    if (stationId == null || !mounted) return;

    setState(() => _isEnding = true);
    try {
      final response = await _apiClient.endJourney(
  bikeId: widget.bikeQr,   // or widget.bikeId if that’s the actual field
  stationId: stationId,
);

      final code = response.statusCode ?? 0;
      if (code != 200 && code != 201) {
        throw Exception('Server returned $code');
      }

      // Accept shapes:
      // { cost: <num|string>, duration: <num|string> }
      // { data: { cost: ..., duration: ... } }
      num? costNum;
      num? durationMinutes;
      final body = response.data;

      Map? root;
      if (body is Map) {
        root = body;
      }

      Map? dataMap = root;
      if (root != null && root['data'] is Map) {
        dataMap = root['data'] as Map;
      }

      dynamic costVal = dataMap?['cost'] ?? root?['cost'];
      dynamic durVal = dataMap?['duration'] ?? root?['duration'];

      // Normalize numbers even if strings
      if (costVal is String) costVal = num.tryParse(costVal);
      if (durVal is String) durVal = num.tryParse(durVal);

      if (costVal is num) costNum = costVal;
      if (durVal is num) durationMinutes = durVal;

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Journey ended successfully.'
            '${costNum != null ? ' Cost: ₹${costNum.toStringAsFixed(2)}.' : ''}'
            '${durationMinutes != null ? ' Duration: ${durationMinutes.toStringAsFixed(0)} min.' : ''}',
          ),
          duration: const Duration(seconds: 5),
        ),
      );

      // Navigate home and clear stack
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const HomeScreen()),
        (_) => false,
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error ending journey: $e')),
      );
    } finally {
      if (mounted) setState(() => _isEnding = false);
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final info = [
      _buildInfoCard('Bike ID', widget.bikeQr),
      _buildInfoCard('Start Time', DateFormat().format(widget.startTime)),
      _buildInfoCard('Duration', _formatDuration(_duration)),
    ];

    return Scaffold(
      appBar: AppBar(title: const Text('Ongoing Journey')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            ...info,
            const SizedBox(height: 32),
            ElevatedButton(
              onPressed: _isEnding ? null : _endJourney,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                minimumSize: const Size(double.infinity, 50),
              ),
              child: _isEnding
                  ? const CircularProgressIndicator(color: Colors.white)
                  : const Text(
                      'END JOURNEY',
                      style: TextStyle(fontSize: 18, color: Colors.white),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoCard(String title, String value) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Row(
          children: [
            Text('$title: ', style: const TextStyle(fontWeight: FontWeight.bold)),
            Expanded(child: Text(value)),
          ],
        ),
      ),
    );
  }
}
