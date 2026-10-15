import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:zuno/features/booking/presentation/providers/booking_providers.dart';
import 'package:zuno/features/worker/presentation/screens/worker_booking_detail_screen.dart';
import 'package:zuno/shared/widgets/app_messages.dart';
import 'package:zuno/core/theme/app_colors.dart';

const _qrPrefix = 'zuno-booking:';

class ScanBookingQrScreen extends ConsumerStatefulWidget {
  const ScanBookingQrScreen({super.key});

  @override
  ConsumerState<ScanBookingQrScreen> createState() =>
      _ScanBookingQrScreenState();
}

class _ScanBookingQrScreenState extends ConsumerState<ScanBookingQrScreen> {
  final _controller = MobileScannerController();
  bool _isProcessing = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _onDetect(BarcodeCapture capture) async {
    if (_isProcessing) return;

    final rawValue = capture.barcodes.isEmpty
        ? null
        : capture.barcodes.first.rawValue;
    if (rawValue == null || !rawValue.startsWith(_qrPrefix)) {
      return;
    }

    final bookingId = rawValue.substring(_qrPrefix.length);
    setState(() => _isProcessing = true);
    await _controller.stop();

    try {
      final booking = await ref
          .read(bookingRepositoryProvider)
          .getJobByIdAsWorker(bookingId);
      if (mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (_) => WorkerBookingDetailScreen(booking: booking),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        context.showFailureMessage(e.toString().replaceFirst('Exception: ', ''));
        setState(() => _isProcessing = false);
        await _controller.start();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Scan booking QR')),
      body: Stack(
        alignment: Alignment.center,
        children: [
          MobileScanner(controller: _controller, onDetect: _onDetect),
          Container(
            width: 240,
            height: 240,
            decoration: BoxDecoration(
              border: Border.all(color: Colors.white, width: 3),
              borderRadius: BorderRadius.circular(16),
            ),
          ),
          if (_isProcessing)
            Container(
              color: AppColors.scrim,
              child: const Center(child: CircularProgressIndicator()),
            ),
          Positioned(
            bottom: 32,
            child: Text(
              'Point the camera at the customer\'s booking QR code',
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(color: Colors.white),
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
    );
  }
}
