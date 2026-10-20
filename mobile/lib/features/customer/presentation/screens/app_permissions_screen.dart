import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:zuno/core/location/location_service.dart';
import 'package:zuno/core/permissions/permission_service.dart';

/// What Zuno asks the phone for, why, and how to change your mind.
///
/// Worth a page because the permissions here are not obvious from the screens that use them: a
/// customer who declined location once has no way to discover that it is why nothing appears nearby,
/// and Android gives them no route back except Settings, buried three levels deep.
///
/// Each row says what it is for in terms of what the person gets, never in terms of the API. "So
/// businesses near you come first" rather than "ACCESS_FINE_LOCATION".
class AppPermissionsScreen extends ConsumerStatefulWidget {
  const AppPermissionsScreen({super.key});

  @override
  ConsumerState<AppPermissionsScreen> createState() =>
      _AppPermissionsScreenState();
}

class _AppPermissionsScreenState extends ConsumerState<AppPermissionsScreen> {
  PermissionSnapshot? _permissions;
  bool _isChecking = true;

  @override
  void initState() {
    super.initState();
    _check();
  }

  Future<void> _check() async {
    setState(() => _isChecking = true);

    // Read, not requested — and that is the whole fix here. This page used to find out where it
    // stood by asking for a position, so a customer who opened it to read a row got the location
    // prompt, at the one moment the app had no use for a location. Location is asked for where it
    // is needed: on the control that chooses a place.
    final snapshot = await ref.read(permissionServiceProvider).snapshot();

    if (!mounted) return;
    setState(() {
      _permissions = snapshot;
      _isChecking = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final service = ref.read(locationServiceProvider);

    final (locationState, locationDetail) = switch (_permissions?.location) {
      null => ('Checking…', 'Reading the current setting.'),
      PermissionState.granted => (
        'Allowed',
        'Services and jobs near you are sorted by distance.',
      ),
      PermissionState.blocked => (
        'Blocked',
        'Zuno is not allowed to read your location. You can change that in app settings.',
      ),
      PermissionState.notAsked => (
        'Not asked yet',
        'Zuno asks for this the first time you choose a place to search in, and not before.',
      ),
      PermissionState.denied => (
        'Not allowed',
        'You can still type a place instead — nothing here depends on it.',
      ),
    };

    final (cameraState, cameraDetail) = switch (_permissions?.camera) {
      null => ('Checking…', 'Reading the current setting.'),
      PermissionState.granted => (
        'Allowed',
        'Used for your profile picture and for scanning a job code.',
      ),
      PermissionState.blocked => (
        'Blocked',
        'Zuno is not allowed to use the camera. You can change that in app settings.',
      ),
      _ => (
        'Not allowed',
        'You can still choose a picture from your gallery, which needs no permission.',
      ),
    };

    return Scaffold(
      appBar: AppBar(title: const Text('App permissions')),
      body: RefreshIndicator(
        onRefresh: _check,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
          children: [
            Text(
              'Zuno asks for as little as it can. Nothing here is required to browse or to book — '
              'each one makes a particular screen work better.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 16),

            _PermissionCard(
              icon: Icons.place_outlined,
              title: 'Location',
              state: _isChecking ? 'Checking…' : locationState,
              detail: locationDetail,
              isGranted: switch (_permissions?.location) {
                null => null,
                PermissionState.granted => true,
                // Never asked is not the same as refused, and a red cross against something nobody
                // has been asked about reads as a fault.
                PermissionState.notAsked => null,
                _ => false,
              },
              usedFor: const [
                'Sorting services by how far away they are',
                'Finding work near you, if you also work through Zuno',
              ],
              actionLabel: 'Open app settings',
              // No button in a browser: there is no app settings page to open, so pressing it did
              // nothing at all. The card says where the setting really lives instead.
              onAction: kIsWeb ? null : service.openSettings,
              webHint:
                  'Change this behind the padlock (or ⓘ) to the left of the web address, '
                  'under Permissions, then Location.',
              onRecheck: _check,
            ),

            _PermissionCard(
              icon: Icons.photo_camera_outlined,
              title: 'Camera and photos',
              state: _isChecking ? 'Checking…' : cameraState,
              detail: cameraDetail,
              isGranted: switch (_permissions?.camera) {
                null => null,
                PermissionState.granted => true,
                _ => false,
              },
              usedFor: const [
                'Adding a photo to your profile',
                'Scanning a booking QR code on the day',
              ],
              actionLabel: 'Open app settings',
              onAction: kIsWeb
                  ? null
                  : ref.read(permissionServiceProvider).openAppSettings,
              webHint:
                  'The browser asks for the camera itself, the moment a page uses it. '
                  'Choosing a picture needs no permission at all.',
              onRecheck: _check,
            ),

            const _PermissionCard(
              icon: Icons.notifications_none_rounded,
              title: 'Notifications',
              state: 'Not used yet',
              detail:
                  'Zuno does not send notifications today. When it does, it will ask first and '
                  'this page will say what for.',
              isGranted: null,
              usedFor: [],
            ),
          ],
        ),
      ),
    );
  }
}

class _PermissionCard extends StatelessWidget {
  const _PermissionCard({
    required this.icon,
    required this.title,
    required this.state,
    required this.detail,
    required this.isGranted,
    required this.usedFor,
    this.actionLabel,
    this.onAction,
    this.webHint,
    this.onRecheck,
  });

  final IconData icon;
  final String title;
  final String state;
  final String detail;

  /// Null where the app genuinely does not know, rather than guessing at a tick or a cross.
  final bool? isGranted;

  final List<String> usedFor;
  final String? actionLabel;
  final Future<void> Function()? onAction;

  /// Where the setting actually lives in a browser, shown in place of the button.
  ///
  /// A web page cannot open any settings screen, so the button was simply dead there. Saying where
  /// to go is the only honest version of that offer.
  final String? webHint;

  final VoidCallback? onRecheck;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final stateColour = switch (isGranted) {
      true => theme.colorScheme.primary,
      false => theme.colorScheme.error,
      null => theme.colorScheme.onSurfaceVariant,
    };

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 20, color: theme.colorScheme.onSurfaceVariant),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    title,
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                Text(
                  state,
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: stateColour,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              detail,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
                height: 1.35,
              ),
            ),

            if (usedFor.isNotEmpty) ...[
              const SizedBox(height: 10),
              for (final use in usedFor)
                Padding(
                  padding: const EdgeInsets.only(bottom: 3),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(top: 6, right: 8),
                        child: Container(
                          width: 4,
                          height: 4,
                          decoration: BoxDecoration(
                            color: theme.colorScheme.primary,
                            shape: BoxShape.circle,
                          ),
                        ),
                      ),
                      Expanded(
                        child: Text(use, style: theme.textTheme.bodySmall),
                      ),
                    ],
                  ),
                ),
            ],

            if (webHint case final hint? when onAction == null) ...[
              const SizedBox(height: 8),
              Text(
                hint,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                  height: 1.4,
                ),
              ),
            ],

            if (onAction != null || onRecheck != null) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  if (onAction case final action?)
                    TextButton(
                      onPressed: action,
                      style: TextButton.styleFrom(
                        visualDensity: VisualDensity.compact,
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                      ),
                      child: Text(actionLabel ?? 'Open settings'),
                    ),
                  if (onRecheck case final recheck?)
                    TextButton(
                      // Settings opens in another app, so nothing tells Zuno the answer changed.
                      onPressed: recheck,
                      style: TextButton.styleFrom(
                        visualDensity: VisualDensity.compact,
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                      ),
                      child: const Text('Check again'),
                    ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}
