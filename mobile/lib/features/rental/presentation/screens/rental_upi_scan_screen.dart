import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:zuno/core/theme/app_colors.dart';

/// Scans the QR a customer's UPI app shows (GPay, PhonePe, Paytm…) and returns what it says, so a
/// refund can be paid to their UPI ID. The caller reads the UPI ID out of it.
class RentalUpiScanScreen extends StatefulWidget {
  const RentalUpiScanScreen({super.key});

  @override
  State<RentalUpiScanScreen> createState() => _RentalUpiScanScreenState();
}

class _RentalUpiScanScreenState extends State<RentalUpiScanScreen> {
  final _controller = MobileScannerController();
  bool _done = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onDetect(BarcodeCapture capture) {
    final raw = capture.barcodes.isEmpty
        ? null
        : capture.barcodes.first.rawValue;
    if (_done || raw == null || raw.isEmpty) return;
    _done = true;
    Navigator.of(context).pop(raw);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Scan customer's UPI QR")),
      body: Stack(
        alignment: Alignment.center,
        children: [
          MobileScanner(controller: _controller, onDetect: _onDetect),
          Container(
            width: 240,
            height: 240,
            decoration: BoxDecoration(
              border: Border.all(color: AppColors.onMedia, width: 3),
              borderRadius: BorderRadius.circular(16),
            ),
          ),
          Positioned(
            bottom: 32,
            left: 24,
            right: 24,
            child: Text(
              'Ask the customer to open "Receive money" or their QR in GPay, '
              'PhonePe or Paytm, and point the camera at it.',
              textAlign: TextAlign.center,
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(color: AppColors.onMedia),
            ),
          ),
        ],
      ),
    );
  }
}
