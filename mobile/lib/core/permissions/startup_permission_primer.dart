import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zuno/core/permissions/permission_service.dart';

/// Asks for the camera once, the first time somebody reaches a dashboard.
///
/// Before this, nothing was ever requested up front: the camera dialog appeared the moment somebody
/// tapped their own profile picture, mid-task and with no explanation, and a refusal there left the
/// picker open over a screen that could no longer do anything. Asking once, in a sentence that says
/// what it is for, is the difference between a decision and an interruption.
///
/// **Location is deliberately not asked here.** It is the one permission this app can genuinely do
/// without — somebody who never opens Find work or picks a service area never needs it — so it stays
/// where it belongs, on the button that needs it. Asking for a location at launch is what teaches
/// people to refuse everything.
///
/// The same for all three roles. A customer, a worker and a business owner all set a profile
/// picture, and a worker also scans a job's QR code, so the camera is the one answer every side of
/// the app needs.
class StartupPermissionPrimer extends ConsumerStatefulWidget {
  const StartupPermissionPrimer({required this.child, super.key});

  final Widget child;

  /// Remembered per install, so this is asked once and never again.
  ///
  /// Not per account: the permission belongs to the phone, and somebody switching between a worker
  /// and a customer login on one device has already answered.
  static const storageKey = 'permissions_primed';

  @override
  ConsumerState<StartupPermissionPrimer> createState() =>
      _StartupPermissionPrimerState();
}

class _StartupPermissionPrimerState
    extends ConsumerState<StartupPermissionPrimer> {
  @override
  void initState() {
    super.initState();
    // After the first frame: the dashboard should be on screen behind the question, so somebody can
    // see what they are being asked on behalf of.
    WidgetsBinding.instance.addPostFrameCallback((_) => _primeOnce());
  }

  Future<void> _primeOnce() async {
    final service = ref.read(permissionServiceProvider);

    SharedPreferences? store;
    try {
      store = await SharedPreferences.getInstance();
      if (store.getBool(StartupPermissionPrimer.storageKey) ?? false) return;
    } on Exception {
      // Storage that cannot be read is not a reason to block the app. The cost of asking twice is
      // one dialog; the cost of failing here would be a dashboard that never appears.
    }

    // Nothing to ask for if it is already granted — reinstalls and upgrades land here.
    if (await service.hasCamera()) {
      await _remember(store);
      return;
    }

    if (!mounted) return;

    final agreed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Zuno needs your camera'),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('For your profile picture, photos of your work, and scanning a job code.'),
            SizedBox(height: 12),
            Text(
              'Your location is only asked for later, when you choose where to '
              'search — never before.',
              style: TextStyle(fontSize: 12.5),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Not now'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Continue'),
          ),
        ],
      ),
    );

    // Either answer counts as asked. Somebody who said "not now" meant it, and the camera still
    // asks for itself at the moment it is opened — this was the explanation, not the only chance.
    await _remember(store);

    if (agreed != true) return;

    await service.requestEssentials();
  }

  Future<void> _remember(SharedPreferences? store) async {
    try {
      await (store ?? await SharedPreferences.getInstance()).setBool(
        StartupPermissionPrimer.storageKey,
        true,
      );
    } on Exception {
      // Failing to remember costs one extra dialog next launch, which is not worth an error.
    }
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
