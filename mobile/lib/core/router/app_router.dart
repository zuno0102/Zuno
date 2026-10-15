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
import 'package:zuno/features/customer/presentation/screens/customer_dashboard_shell.dart';
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
        builder: (context, state) => const CustomerDashboardShell(),
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

String _homeRouteForRole(String role) => switch (role) {
  'Customer' => '/customer',
  'BusinessOwner' => '/business-owner',
  'Worker' => '/worker',
  'SuperAdmin' => '/admin',
  _ => '/login',
};
