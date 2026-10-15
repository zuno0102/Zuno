import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:zuno/core/constants/api_constants.dart';
import 'package:zuno/features/auth/domain/entities/user.dart';

/// The signed-in person's picture, falling back to the first letter of their name.
///
/// One widget for every place the account avatar appears. The home header and the profile page
/// showed the same person two different ways before this existed — the page had the photo, the
/// header only ever had the letter — and anywhere else the avatar turns up would have been a third
/// chance to forget the picture.
class ProfileAvatar extends StatelessWidget {
  const ProfileAvatar({required this.user, this.radius = 22, super.key});

  final User? user;

  final double radius;

  /// The full address of [user]'s picture, or null when they have not set one.
  ///
  /// The server stores a root-relative path, so it only resolves against the API host — the same
  /// host the picture was uploaded to.
  static String? photoUrlFor(User? user) {
    final path = user?.profileImageUrl;
    if (path == null || path.isEmpty) return null;
    return '${ApiConstants.baseUrl}$path';
  }

  /// Forgets the cached copy of [user]'s picture.
  ///
  /// Housekeeping, not correctness: each upload is saved under its own versioned name, so a new
  /// picture arrives at a new address and is fetched on sight. Call this with the *previous* user
  /// after an upload, to release bytes nothing will ask for again.
  static Future<void> evict(User? user) async {
    final url = photoUrlFor(user);
    if (url == null) return;
    await CachedNetworkImage.evictFromCache(url);
    // cached_network_image keeps its own store, but Flutter also holds decoded frames keyed on the
    // provider — clearing one without the other leaves the stale picture on screen.
    await CachedNetworkImageProvider(url).evict();
  }

  String get _initial {
    final name = user?.firstName ?? '';
    return name.isEmpty ? '?' : name[0].toUpperCase();
  }

  Widget _letter(ThemeData theme) => Center(
    child: Text(
      _initial,
      style: theme.textTheme.titleMedium?.copyWith(
        // Scales with the circle: the same letter has to read at 22 in the header and at 30 on
        // the profile page.
        fontSize: radius * 0.72,
        color: theme.colorScheme.onPrimaryContainer,
        fontWeight: FontWeight.w700,
      ),
    ),
  );

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final photoUrl = photoUrlFor(user);
    final diameter = radius * 2;

    return ClipOval(
      child: Container(
        width: diameter,
        height: diameter,
        color: theme.colorScheme.primaryContainer,
        // Not CircleAvatar's backgroundImage: that has no way to fall back when the picture cannot
        // be fetched, so an offline phone would show an empty coloured disc where a name used to
        // be. Here the letter stands in both while the picture loads and if it never arrives.
        child: photoUrl == null
            ? _letter(theme)
            : CachedNetworkImage(
                imageUrl: photoUrl,
                width: diameter,
                height: diameter,
                fit: BoxFit.cover,
                placeholder: (_, _) => _letter(theme),
                errorWidget: (_, _, _) => _letter(theme),
              ),
      ),
    );
  }
}
