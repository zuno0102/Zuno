import 'dart:convert';

import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:zuno/core/router/go_router_refresh_notifier.dart';
import 'package:zuno/features/admin/presentation/screens/admin_dashboard_shell.dart';
import 'package:zuno/features/auth/presentation/providers/auth_notifier.dart';
import 'package:zuno/features/auth/presentation/providers/auth_state.dart';
import 'package:zuno/features/auth/presentation/screens/forgot_password_screen.dart';
import 'package:zuno/features/auth/presentation/screens/login_screen.dart';
import 'package:zuno/features/auth/presentation/screens/register_screen.dart';
import 'package:zuno/features/business_owner/presentation/screens/business_owner_dashboard_shell.dart';
import 'package:zuno/features/customer/presentation/screens/business_detail_screen.dart';
import 'package:zuno/features/customer/presentation/screens/service_detail_screen.dart';
import 'package:zuno/features/rental/presentation/screens/customer_app_shell.dart';
import 'package:zuno/features/worker/presentation/screens/worker_dashboard_shell.dart';

part 'app_router.g.dart';

const _publicPaths = ['/login', '/register', '/forgot-password'];

@Riverpod(keepAlive: true)
GoRouter appRouter(Ref ref) {
  final refreshNotifier = GoRouterRefreshNotifier();
  ref.listen(authProvider, (previous, next) => refreshNotifier.refresh());

  return GoRouter(
    initialLocation: '/login',
    refreshListenable: refreshNotifier,
    // Lets the browser's back button bring a pushed screen back (see ScreenExtraCodec).
    extraCodec: const ScreenExtraCodec(),
    redirect: (context, state) {
      final authState = ref.read(authProvider);
      final isPublicRoute = _publicPaths.contains(state.matchedLocation);

      if (authState.isLoading) {
        return null;
      }

      final value = authState.value;
      if (value is! AuthAuthenticated) {
        return isPublicRoute ? null : '/login';
      }

      if (isPublicRoute) {
        return _homeRouteForRole(value.user.role);
      }

      return null;
    },
    routes: [
      // Where every screen opened with pushScreen() lands.
      //
      // The device's back button only knows about history the router put there, and a screen
      // pushed straight onto the Navigator leaves none: back then skipped past it to whatever
      // the router thought was showing, or did nothing at all. Routing those pushes through
      // here gives each one an entry, so back behaves like the arrow in the corner.
      //
      // One path for all of them because they are handed a built widget, not an id. Giving
      // each its own URL means being able to rebuild it from that URL, which is a different
      // and much larger job — see the note on reloading below.
      GoRoute(
        path: '/screen',
        redirect: (context, state) {
          // A reload or a shared link arrives with no widget to show, since extra does not
          // survive either. Home is a better answer than a blank page.
          if (state.extra is Widget) return null;
          final user = ref.read(authProvider).value;
          return user is AuthAuthenticated
              ? _homeRouteForRole(user.user.role)
              : '/login';
        },
        // Never `extra!`: a history entry the browser hands back after a reload has no screen in
        // it, and a crash here is the grey page. Home instead.
        builder: (context, state) => switch (state.extra) {
          final Widget screen => screen,
          _ => const _BackToHome(),
        },
      ),
      GoRoute(path: '/login', builder: (context, state) => const LoginScreen()),
      GoRoute(
        path: '/register',
        builder: (context, state) => const RegisterScreen(),
      ),
      GoRoute(
        path: '/forgot-password',
        builder: (context, state) => const ForgotPasswordScreen(),
      ),
      GoRoute(
        path: '/customer',
        // Service | Rent on top; the Service side is the customer app as it was.
        builder: (context, state) => const CustomerAppShell(),
      ),
      GoRoute(
        path: '/customer/business/:id',
        builder: (context, state) =>
            BusinessDetailScreen(businessId: state.pathParameters['id']!),
      ),
      GoRoute(
        path: '/customer/service/:id',
        builder: (context, state) => ServiceDetailScreen(
          serviceId: state.pathParameters['id']!,
          // Opened from the home banner, the page is the service and nothing else. A query
          // parameter rather than a constructor argument passed by hand, so the route stays one
          // link that carries its own context.
          showRelatedServices: state.uri.queryParameters['related'] != '0',
        ),
      ),
      GoRoute(
        path: '/business-owner',
        builder: (context, state) => const BusinessOwnerDashboardShell(),
      ),
      GoRoute(
        path: '/worker',
        builder: (context, state) => const WorkerDashboardShell(),
      ),
      GoRoute(
        path: '/admin',
        builder: (context, state) => const AdminDashboardShell(),
      ),
    ],
  );
}

/// Shown for a pushed screen that can no longer be found (the page was reloaded): goes to the
/// login route, which sends a signed-in user straight to their home.
class _BackToHome extends StatefulWidget {
  const _BackToHome();

  @override
  State<_BackToHome> createState() => _BackToHomeState();
}

class _BackToHomeState extends State<_BackToHome> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) GoRouter.of(context).go('/login');
    });
  }

  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}

/// How a screen opened with `pushScreen` survives the browser's history.
///
/// The router writes every page into the browser's history so back and forward work, but a built
/// screen cannot be written there: without a codec go_router silently stores nothing, and the
/// browser's back button then handed `/screen` back with no screen — `extra!` threw, and the web
/// app showed a grey page. This keeps each pushed screen in memory under a number and writes the
/// number instead, so back finds the very same screen again. After a reload memory is empty and
/// the number finds nothing: the route then goes home instead of crashing.
class ScreenExtraCodec extends Codec<Object?, Object?> {
  const ScreenExtraCodec();

  /// Pushed screens by number. Bounded: the oldest are forgotten, as a browser forgets history.
  static final _screens = <int, Widget>{};
  static var _next = 0;
  static const _keep = 100;

  /// For tests: how many pushed screens are kept.
  @visibleForTesting
  static int get remembered => _screens.length;

  @override
  Converter<Object?, Object?> get encoder => const _ScreenEncoder();

  @override
  Converter<Object?, Object?> get decoder => const _ScreenDecoder();
}

class _ScreenEncoder extends Converter<Object?, Object?> {
  const _ScreenEncoder();

  @override
  Object? convert(Object? input) {
    if (input is! Widget) return null;
    // The same screen written twice (go_router reports a page more than once) keeps one number.
    for (final entry in ScreenExtraCodec._screens.entries) {
      if (identical(entry.value, input)) return {'screen': entry.key};
    }
    final number = ScreenExtraCodec._next++;
    ScreenExtraCodec._screens[number] = input;
    if (ScreenExtraCodec._screens.length > ScreenExtraCodec._keep) {
      ScreenExtraCodec._screens.remove(ScreenExtraCodec._screens.keys.first);
    }
    return {'screen': number};
  }
}

class _ScreenDecoder extends Converter<Object?, Object?> {
  const _ScreenDecoder();

  @override
  Object? convert(Object? input) {
    if (input is! Map) return null;
    final number = input['screen'];
    return number is int ? ScreenExtraCodec._screens[number] : null;
  }
}

String _homeRouteForRole(String role) => switch (role) {
  'Customer' => '/customer',
  'BusinessOwner' => '/business-owner',
  'Worker' => '/worker',
  'SuperAdmin' => '/admin',
  _ => '/login',
};
