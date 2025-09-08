import 'package:flutter/material.dart';
import 'package:qr_code_scanner_plus/qr_code_scanner_plus.dart';

class QrScanScreen extends StatefulWidget {
  final Function(String) onScan;
  final bool isStation;

  QrScanScreen({required this.onScan, required this.isStation});

  @override
  _QrScanScreenState createState() => _QrScanScreenState();
}

class _QrScanScreenState extends State<QrScanScreen> {
  final GlobalKey qrKey = GlobalKey(debugLabel: 'QR');
  QRViewController? controller;
  bool _isProcessing = false;

  @override
  void dispose() {
    controller?.dispose();
    super.dispose();
  }

  void _onQRViewCreated(QRViewController controller) {
    this.controller = controller;
    controller.scannedDataStream.listen((scanData) async {
      if (_isProcessing || scanData.code == null) return;
      if (_isValidId(scanData.code!)) {
        setState(() => _isProcessing = true);
        controller.pauseCamera();

        dynamic result = await widget.onScan(scanData.code!);

        if (result is bool) {
          // If onScan returns a boolean, it indicates whether navigation was handled
          if (!result && mounted) {
            Navigator.pop(context, scanData.code);
          }
        } else {
          // If onScan returns anything else, just pop with the scanned code
          if (mounted) {
            Navigator.pop(context, scanData.code);
          }
        }
      } else {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Invalid QR Code')));
      }
    });
  }

  bool _isValidId(String code) {
    if (widget.isStation) {
      return code.startsWith('STATION-');
    }
    return code.startsWith('BIKE-');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Scan QR Code')),
      body: QRView(
        key: qrKey,
        onQRViewCreated: _onQRViewCreated,
        overlay: QrScannerOverlayShape(
          borderColor: Colors.blue,
          borderRadius: 10,
          borderLength: 30,
          borderWidth: 10,
          cutOutSize: 300,
        ),
      ),
    );
  }
}
