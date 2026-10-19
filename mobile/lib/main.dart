import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:zuno/core/maps/google_maps_loader.dart';
import 'package:zuno/core/notifications/system_notifications.dart';
import 'package:zuno/core/router/app_router.dart';
import 'package:zuno/core/theme/app_colors.dart';
import 'package:zuno/core/theme/app_theme.dart';
import 'package:zuno/features/auth/presentation/providers/auth_notifier.dart';
import 'package:zuno/features/auth/presentation/providers/auth_state.dart';

Future<void> main() async {
  // Needed before any plugin is touched, which the notification channel below is.
  WidgetsFlutterBinding.ensureInitialized();

  // Set up before the first frame, so a notification tapped from a cold start — where the tap is
  // what launched the app — is already recorded by the time a screen exists to act on it.
  // Failure here must not stop the app: not being able to draw a banner is a degraded app, while
  // not starting is no app at all.
  try {
    await SystemNotifications.instance.init();
  } catch (error, stack) {
    debugPrint('[Notifications] Could not set up the shade: $error\n$stack');
  }

  // Google's map script, on the web only and only when a key was built in. Awaited (with its own
  // time limit) so the first map drawn is a Google one rather than a fallback.
  await loadGoogleMapsScript();

  runApp(const ProviderScope(child: ZunoApp()));
}

class ZunoApp extends ConsumerWidget {
  const ZunoApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(appRouterProvider);

    // The signed-in role colours the whole app, not only the dashboards.
    //
    // Each shell wraps itself in a `RoleTheme`, which works for the tabs inside it and for nothing
    // else: a pushed route, a dialog and a snackbar are all children of the Navigator that
    // `MaterialApp` owns, above those wrappers. So a worker who opened their profile — a route
    // pushed from the dashboard — got a business-indigo screen and business-indigo messages on a
    // green app, and there is no wrapper that could have caught them.
    //
    // Setting it here catches every one of those at the source. Signed out it stays null, which
    // keeps the login and register screens on the neutral brand colours.
    final authValue = ref.watch(authProvider).value;
    final role = authValue is AuthAuthenticated
        ? AppColors.roleFromName(authValue.user.role)
        : null;

    return MaterialApp.router(
      title: 'Zuno',
      debugShowCheckedModeBanner: false,
      theme: role == null
          ? AppTheme.light
          : AppTheme.forRole(role, Brightness.light),
      darkTheme: role == null
          ? AppTheme.dark
          : AppTheme.forRole(role, Brightness.dark),
      routerConfig: router,
    );
  }
}
