import 'package:flutter/foundation.dart';

/// A `Listenable` GoRouter's `refreshListenable` can watch. Fed by `ref.listen` on the
/// auth provider (see `app_router.dart`) so GoRouter re-evaluates `redirect` on every
/// auth-state change, including transitions through loading/error, not just data.
class GoRouterRefreshNotifier extends ChangeNotifier {
  void refresh() => notifyListeners();
}
