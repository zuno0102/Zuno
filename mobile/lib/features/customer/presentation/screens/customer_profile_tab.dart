import 'dart:async';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:zuno/features/auth/presentation/providers/auth_notifier.dart';
import 'package:zuno/features/auth/presentation/providers/auth_state.dart';
import 'package:zuno/features/booking/presentation/providers/booking_message_providers.dart';
import 'package:zuno/features/booking/presentation/providers/customer_bookings_notifier.dart';
import 'package:zuno/features/customer/presentation/screens/app_permissions_screen.dart';
import 'package:zuno/features/customer/presentation/widgets/edit_account_sheet.dart';
import 'package:zuno/shared/widgets/change_password_sheet.dart';
import 'package:zuno/shared/widgets/profile_avatar.dart';
import 'package:zuno/shared/widgets/section_header.dart';
import 'package:zuno/shared/widgets/app_messages.dart';

/// The customer's account page.
///
/// Only lists what the app can actually do. A settings row that opens nothing is worse than no row at
/// all — it teaches people the app is unfinished, and they stop trying the ones that work.
class CustomerProfileTab extends ConsumerWidget {
  const CustomerProfileTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authValue = ref.watch(authProvider).value;
    final user = authValue is AuthAuthenticated ? authValue.user : null;

    return ListView(
      padding: const EdgeInsets.only(bottom: 28),
      children: [
        _ProfileHeader(
          onEdit: user == null
              ? null
              : () async {
                  final saved = await showEditAccountSheet(context, user: user);
                  if (saved && context.mounted) {
                    context.showSuccessMessage('Your details are saved.');
                  }
                },
        ),

        const _ActivitySummary(),

        // The one review prompt in the app. With no ratings at all, no business can clear the
        // rating bar that gates Level 3 — so this is where that unblocks.
        const _ReviewPrompt(),

        const SectionHeader(title: 'Account'),
        _SettingsCard(
          rows: [
            _SettingsRow(
              icon: Icons.person_outline,
              title: 'Edit your details',
              subtitle: 'Name and mobile number',
              onTap: user == null
                  ? null
                  : () => showEditAccountSheet(context, user: user),
            ),
            _SettingsRow(
              icon: Icons.lock_outline,
              title: 'Change password',
              subtitle: 'You stay signed in on this phone',
              onTap: () => showChangePasswordSheet(context),
            ),
          ],
        ),

        const SectionHeader(title: 'Settings'),
        _SettingsCard(
          rows: [
            _SettingsRow(
              icon: Icons.shield_outlined,
              title: 'App permissions',
              subtitle: 'Location, camera and photos',
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => const AppPermissionsScreen(),
                ),
              ),
            ),
            _SettingsRow(
              icon: Icons.badge_outlined,
              title: 'Account type',
              // Not a link: nobody can change their own role, and a row that looks tappable and
              // refuses is a worse answer than one that simply states the fact.
              trailingText: user?.role ?? 'Customer',
            ),
          ],
        ),

        const SectionHeader(title: 'About Zuno'),
        const _AboutCard(),

        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
          child: _SettingsCard(
            rows: [
              _SettingsRow(
                icon: Icons.logout,
                title: 'Log out',
                isDestructive: true,
                onTap: () => _confirmLogout(context, ref),
              ),
            ],
            inset: false,
          ),
        ),
      ],
    );
  }

  /// Asks first.
  ///
  /// Logging out is one tap from the bottom of a page people scroll through, and signing back in
  /// means finding a password. Cheap to confirm, annoying to undo.
  Future<void> _confirmLogout(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Log out?'),
        content: const Text('You will need your password to sign back in.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Stay'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(dialogContext).colorScheme.error,
            ),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Log out'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await ref.read(authProvider.notifier).logout();
    }
  }
}

/// Who is signed in, with the way to correct it.
class _ProfileHeader extends ConsumerWidget {
  const _ProfileHeader({required this.onEdit});

  final VoidCallback? onEdit;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final authValue = ref.watch(authProvider).value;
    final user = authValue is AuthAuthenticated ? authValue.user : null;
    final name = user == null
        ? 'Signed in'
        : '${user.firstName} ${user.lastName}'.trim();

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 4),
      child: Row(
        children: [
          const _ProfilePhoto(),
          const SizedBox(width: 14),
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
                if (user?.email case final email?)
                  Text(
                    email,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                // Said plainly when it is missing: without a number a business cannot ring about a
                // booking, and the customer is the only person who can fix that.
                Text(
                  user?.phoneNumber ?? 'No mobile number — add one so businesses can call',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: user?.phoneNumber == null
                        ? theme.colorScheme.error
                        : theme.colorScheme.onSurfaceVariant,
                    fontWeight: user?.phoneNumber == null ? FontWeight.w600 : null,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: onEdit,
            icon: const Icon(Icons.edit_outlined, size: 20),
            tooltip: 'Edit your details',
          ),
        ],
      ),
    );
  }
}

/// A line of figures from what the customer has actually done here.
///
/// Counted from bookings and conversations the app has already loaded, so it costs no request. It
/// exists because a profile page with nothing but settings rows tells somebody nothing about
/// themselves.
class _ActivitySummary extends ConsumerWidget {
  const _ActivitySummary();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final bookings = ref.watch(customerBookingsProvider).value ?? const [];
    final threads = ref.watch(bookingThreadsProvider).value ?? const [];

    if (bookings.isEmpty) return const SizedBox.shrink();

    final completed = bookings.where((b) => b.isCompleted).length;
    final active = bookings.where((b) => !b.isCompleted && !b.isCancelled).length;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
      child: Row(
        children: [
          _Stat(label: 'Bookings', value: '${bookings.length}'),
          _Stat(label: 'Under way', value: '$active'),
          _Stat(label: 'Finished', value: '$completed'),
          _Stat(label: 'Chats', value: '${threads.length}', last: true),
        ],
      ).withDividers(theme),
    );
  }
}

extension on Row {
  /// Hairlines between the figures, so they read as one strip rather than four loose numbers.
  Widget withDividers(ThemeData theme) => Container(
    padding: const EdgeInsets.symmetric(vertical: 12),
    decoration: BoxDecoration(
      color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
      borderRadius: BorderRadius.circular(14),
    ),
    child: this,
  );
}

class _Stat extends StatelessWidget {
  const _Stat({required this.label, required this.value, this.last = false});

  final String label;
  final String value;
  final bool last;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Expanded(
      child: DecoratedBox(
        decoration: BoxDecoration(
          border: last
              ? null
              : Border(
                  right: BorderSide(
                    color: theme.colorScheme.outlineVariant.withValues(alpha: 0.5),
                  ),
                ),
        ),
        child: Column(
          children: [
            Text(
              value,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            Text(
              label,
              style: theme.textTheme.labelSmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SettingsCard extends StatelessWidget {
  const _SettingsCard({required this.rows, this.inset = true});

  final List<_SettingsRow> rows;
  final bool inset;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: inset
          ? const EdgeInsets.symmetric(horizontal: 16)
          : EdgeInsets.zero,
      child: Column(
        children: [
          for (var i = 0; i < rows.length; i++) ...[
            if (i > 0) const Divider(height: 1, indent: 56),
            rows[i],
          ],
        ],
      ),
    );
  }
}

class _SettingsRow extends StatelessWidget {
  const _SettingsRow({
    required this.icon,
    required this.title,
    this.subtitle,
    this.trailingText,
    this.onTap,
    this.isDestructive = false,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final String? trailingText;
  final VoidCallback? onTap;
  final bool isDestructive;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tint = isDestructive ? theme.colorScheme.error : null;

    return ListTile(
      leading: Icon(icon, color: tint),
      title: Text(title, style: TextStyle(color: tint)),
      subtitle: subtitle == null ? null : Text(subtitle!),
      trailing: trailingText != null
          ? Text(
              trailingText!,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            )
          // A chevron only where there is somewhere to go.
          : onTap == null
          ? null
          : Icon(
              Icons.chevron_right_rounded,
              color: theme.colorScheme.onSurfaceVariant,
            ),
      onTap: onTap,
    );
  }
}

class _AboutCard extends StatelessWidget {
  const _AboutCard();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Zuno',
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w700,
                letterSpacing: 1.5,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Local services, booked properly. Every business here is verified before it can take '
              'an order, and the people who do the work are paid through the same booking.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
                height: 1.4,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Nudges a customer to rate a finished booking.
///
/// Deliberately quiet when they have nothing to rate: a prompt that appears before the customer
/// has ever booked is noise.
class _ReviewPrompt extends ConsumerWidget {
  const _ReviewPrompt();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final bookings = ref.watch(customerBookingsProvider);

    final unrated = bookings.maybeWhen(
      data: (list) => list.where((b) => b.canBeRated).length,
      orElse: () => 0,
    );

    if (unrated == 0) {
      return const SizedBox.shrink();
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
      child: Container(
        padding: const EdgeInsets.all(13),
        decoration: BoxDecoration(
          color: theme.colorScheme.primaryContainer.withValues(alpha: 0.45),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              Icons.star_border_rounded,
              size: 19,
              color: theme.colorScheme.primary,
            ),
            const SizedBox(width: 9),
            Expanded(
              child: Text(
                unrated == 1
                    ? 'Rate your finished booking. Your review sits on that event, so the '
                          'next customer knows what they are booking.'
                    : 'You have $unrated finished bookings to rate. Each review sits on its '
                          'own event, so the next customer knows what they are booking.',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurface,
                  height: 1.35,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The customer's own picture, and the way to change it.
///
/// Tapping it picks from the gallery and uploads. A camera option is deliberately not offered as a
/// second button: the picker already exposes the camera on every phone this targets.
///
/// It carries a camera badge because an avatar that can be changed and one that cannot look
/// identical otherwise — and somebody who cannot find where to add their picture concludes the app
/// has no such feature.
class _ProfilePhoto extends ConsumerStatefulWidget {
  const _ProfilePhoto();

  @override
  ConsumerState<_ProfilePhoto> createState() => _ProfilePhotoState();
}

class _ProfilePhotoState extends ConsumerState<_ProfilePhoto> {
  bool _isUploading = false;

  Future<void> _pick() async {
    final picked = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      // Resized before it leaves the phone: a modern camera file is several megabytes, the server
      // caps the upload, and nothing here is shown larger than a thumbnail.
      maxWidth: 800,
      maxHeight: 800,
      imageQuality: 85,
    );

    if (picked == null || !mounted) return;

    setState(() => _isUploading = true);
    final messenger = AppMessenger.of(context);

    try {
      final before = ref.read(authProvider).value;
      final previous = before is AuthAuthenticated ? before.user : null;

      await ref
          .read(authProvider.notifier)
          .updateMyPhoto(
            filePath: picked.path,
            // Stated from the file, because the server validates the content type and refuses
            // anything it does not recognise.
            contentType: _contentTypeFor(picked.path),
          );

      // The new picture has its own address, so the avatar is already showing it by now. This only
      // releases the bytes of the one it replaced, which nothing will ask for again.
      unawaited(ProfileAvatar.evict(previous));

      messenger.showSuccess('Photo updated.');
    } catch (e) {
      if (!mounted) return;
      messenger.showFailure(e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _isUploading = false);
    }
  }

  static String _contentTypeFor(String path) {
    final lower = path.toLowerCase();
    if (lower.endsWith('.png')) return 'image/png';
    if (lower.endsWith('.webp')) return 'image/webp';
    return 'image/jpeg';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final authValue = ref.watch(authProvider).value;
    final user = authValue is AuthAuthenticated ? authValue.user : null;

    return GestureDetector(
      onTap: _isUploading ? null : _pick,
      child: Stack(
        children: [
          ProfileAvatar(user: user, radius: 30),
          Positioned(
            right: 0,
            bottom: 0,
            child: Container(
              padding: const EdgeInsets.all(3),
              decoration: BoxDecoration(
                color: theme.colorScheme.primary,
                shape: BoxShape.circle,
                border: Border.all(color: theme.colorScheme.surface, width: 2),
              ),
              child: _isUploading
                  ? const SizedBox(
                      width: 11,
                      height: 11,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : Icon(
                      Icons.camera_alt,
                      size: 11,
                      color: theme.colorScheme.onPrimary,
                    ),
            ),
          ),
        ],
      ),
    );
  }
}
