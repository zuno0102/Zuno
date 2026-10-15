import 'package:flutter/material.dart';
import 'package:zuno/features/auth/domain/entities/user.dart';
import 'package:zuno/shared/widgets/profile_avatar.dart';

/// The strip above the search field: who is signed in, and where they are looking.
///
/// Light rather than the gradient used on the other roles — a customer's home is a shopping
/// surface, and a heavy coloured banner would compete with the service pictures below it.
class CustomerHomeHeader extends StatelessWidget {
  const CustomerHomeHeader({
    required this.user,
    this.location,
    this.trailing,
    super.key,
  });

  final User? user;

  /// Where results are drawn from. Null until the customer picks somewhere.
  final String? location;

  /// Sits at the end of the strip — the notification bell.
  ///
  /// Passed in rather than built here: the bell needs to know where each notification leads, and
  /// that is the shell's knowledge, not this header's.
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final name = user == null
        ? 'Welcome'
        : '${user!.firstName} ${user!.lastName}'.trim();

    return Padding(
      padding: EdgeInsets.fromLTRB(16, MediaQuery.of(context).padding.top + 12, 12, 4),
      child: Row(
        children: [
          ProfileAvatar(user: user),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Row(
                  children: [
                    Icon(
                      Icons.place_outlined,
                      size: 13,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                    const SizedBox(width: 3),
                    Flexible(
                      child: Text(
                        location ?? 'Everywhere',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          ?trailing,
        ],
      ),
    );
  }
}

