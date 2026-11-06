import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:zuno/core/theme/app_colors.dart';
import 'package:zuno/core/utils/validators.dart';
import 'package:zuno/features/rental/domain/entities/rental_customer.dart';
import 'package:zuno/features/rental/presentation/providers/rental_order_providers.dart';

/// The customer's mobile on a rent booking, checked with a one-time code — so a booking that holds a
/// business's stock comes from a number somebody answers. Once a number is verified it stays
/// verified: the next booking with it shows a tick and asks nothing.
///
/// The parent owns [controller] and remembers [verifiedPhone]; this field sends the code, takes it
/// back, and reports a newly verified number through [onVerified].
class RentalPhoneVerifyField extends ConsumerStatefulWidget {
  const RentalPhoneVerifyField({
    required this.controller,
    required this.verifiedPhone,
    required this.onVerified,
    this.onChanged,
    super.key,
  });

  final TextEditingController controller;

  /// The number already verified, as its 10 digits; null when none is.
  final String? verifiedPhone;

  final ValueChanged<String> onVerified;

  final VoidCallback? onChanged;

  /// Whether [phone], however typed, is the [verifiedPhone].
  static bool isVerified(String phone, String? verifiedPhone) {
    final digits = Validators.indianMobileDigits(phone);
    return digits != null && digits == verifiedPhone;
  }

  @override
  ConsumerState<RentalPhoneVerifyField> createState() =>
      _RentalPhoneVerifyFieldState();
}

class _RentalPhoneVerifyFieldState
    extends ConsumerState<RentalPhoneVerifyField> {
  final _code = TextEditingController();
  final _fieldKey = GlobalKey<FormFieldState<String>>();

  /// The code last sent, for the number it was sent to; null before one is sent.
  RentalPhoneCodeSent? _sent;
  bool _isSending = false;
  bool _isVerifying = false;
  String? _message;
  int _resendIn = 0;
  Timer? _timer;

  String? get _digits => Validators.indianMobileDigits(widget.controller.text);

  bool get _isVerified => RentalPhoneVerifyField.isVerified(
    widget.controller.text,
    widget.verifiedPhone,
  );

  /// The code box belongs to the number it was sent to: typing another number puts it away.
  bool get _codeShown =>
      _sent != null && _sent!.phone == _digits && !_isVerified;

  /// The form checks its fields before this one has the new [RentalPhoneVerifyField.verifiedPhone],
  /// so a "verify this number" message would outlive the verifying: checked again here once it has.
  @override
  void didUpdateWidget(RentalPhoneVerifyField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.verifiedPhone != widget.verifiedPhone) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_fieldKey.currentState?.hasError ?? false) {
          _fieldKey.currentState!.validate();
        }
      });
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _code.dispose();
    super.dispose();
  }

  void _startCountdown(int seconds) {
    _timer?.cancel();
    setState(() => _resendIn = seconds);
    if (seconds <= 0) return;
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return timer.cancel();
      setState(() => _resendIn--);
      if (_resendIn <= 0) timer.cancel();
    });
  }

  Future<void> _send() async {
    final phone = _digits;
    if (phone == null) return;
    FocusScope.of(context).unfocus();
    setState(() {
      _isSending = true;
      _message = null;
    });
    try {
      final sent = await ref
          .read(rentalCustomerRepositoryProvider)
          .sendPhoneCode(phone);
      if (!mounted) return;
      if (sent.alreadyVerified) {
        widget.onVerified(sent.phone);
        return;
      }
      _code.clear();
      setState(() => _sent = sent);
      _startCountdown(sent.resendInSeconds);
    } catch (e) {
      if (mounted) setState(() => _message = e.toString());
    } finally {
      if (mounted) setState(() => _isSending = false);
    }
  }

  Future<void> _verify() async {
    final phone = _digits;
    final code = _code.text.trim();
    if (phone == null) return;
    if (code.isEmpty) {
      setState(() => _message = 'Enter the code we sent.');
      return;
    }
    FocusScope.of(context).unfocus();
    setState(() {
      _isVerifying = true;
      _message = null;
    });
    try {
      await ref
          .read(rentalCustomerRepositoryProvider)
          .verifyPhoneCode(phone, code);
      if (!mounted) return;
      _timer?.cancel();
      setState(() => _sent = null);
      widget.onVerified(phone);
    } catch (e) {
      if (mounted) setState(() => _message = e.toString());
    } finally {
      if (mounted) setState(() => _isVerifying = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final verified = _isVerified;
    final success = AppColors.status(StatusTone.success, theme.brightness);
    final canSend =
        _digits != null && !_isSending && !verified && _resendIn <= 0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        KeyedSubtree(
          key: const ValueKey('booking-phone'),
          child: TextFormField(
            key: _fieldKey,
            controller: widget.controller,
            keyboardType: TextInputType.phone,
            inputFormatters: [
              FilteringTextInputFormatter.digitsOnly,
              LengthLimitingTextInputFormatter(10),
            ],
            onChanged: (_) {
              setState(() => _message = null);
              widget.onChanged?.call();
            },
            decoration: InputDecoration(
              labelText: 'Mobile number',
              helperText: verified
                  ? null
                  : 'The business calls this number. We check it with a code once.',
              helperMaxLines: 2,
              border: const OutlineInputBorder(),
              counterText: '',
              suffixIcon: verified
                  ? Padding(
                      key: const ValueKey('booking-phone-verified'),
                      padding: const EdgeInsets.only(right: 12),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.verified_rounded,
                            size: 18,
                            color: success,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            'Verified',
                            style: theme.textTheme.labelMedium?.copyWith(
                              color: success,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    )
                  : Padding(
                      padding: const EdgeInsets.only(right: 4),
                      child: TextButton(
                        key: const ValueKey('booking-send-code'),
                        onPressed: canSend ? _send : null,
                        child: _isSending
                            ? const SizedBox.square(
                                dimension: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : Text(
                                _resendIn > 0
                                    ? 'Resend in ${_resendIn}s'
                                    : _sent != null
                                    ? 'Resend'
                                    : 'Send code',
                              ),
                      ),
                    ),
            ),
            validator: (value) {
              final problem = Validators.requiredIndianMobile(
                value,
                missing: 'Enter your mobile number.',
              );
              if (problem != null) return problem;
              return RentalPhoneVerifyField.isVerified(
                    value ?? '',
                    widget.verifiedPhone,
                  )
                  ? null
                  : 'Tap Send code and enter the code to verify this number.';
            },
          ),
        ),
        if (_codeShown) ...[
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: TextField(
                  key: const ValueKey('booking-otp'),
                  controller: _code,
                  keyboardType: TextInputType.number,
                  autofillHints: const [AutofillHints.oneTimeCode],
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                    LengthLimitingTextInputFormatter(8),
                  ],
                  onChanged: (_) {
                    if (_message != null) setState(() => _message = null);
                  },
                  onSubmitted: (_) => _verify(),
                  decoration: InputDecoration(
                    labelText: 'Code',
                    helperText: 'Sent to ${_sent!.phone}',
                    border: const OutlineInputBorder(),
                    counterText: '',
                  ),
                ),
              ),
              const SizedBox(width: 10),
              SizedBox(
                height: 56,
                child: FilledButton(
                  key: const ValueKey('booking-verify'),
                  onPressed: _isVerifying ? null : _verify,
                  child: _isVerifying
                      ? const SizedBox.square(
                          dimension: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Verify'),
                ),
              ),
            ],
          ),
          // No SMS is sent yet: the server hands the code back so the flow can be used meanwhile.
          if (_sent!.testCode case final code?) ...[
            const SizedBox(height: 8),
            Text(
              'Test code: $code (SMS will come later)',
              key: const ValueKey('booking-test-code'),
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ],
        if (_message case final message?) ...[
          const SizedBox(height: 6),
          Text(
            message,
            key: const ValueKey('booking-phone-message'),
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.error,
            ),
          ),
        ],
      ],
    );
  }
}
