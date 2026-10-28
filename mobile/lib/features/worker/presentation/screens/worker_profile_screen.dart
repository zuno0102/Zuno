import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:zuno/shared/widgets/detail_row.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:zuno/core/constants/api_constants.dart';
import 'package:zuno/core/theme/app_colors.dart';
import 'package:zuno/core/ui_config/ui_config.dart';
import 'package:zuno/core/utils/formatting.dart';
import 'package:zuno/features/worker/domain/entities/worker_profile.dart';
import 'package:zuno/features/worker/presentation/providers/worker_dashboard_notifier.dart';
import 'package:zuno/features/worker/presentation/widgets/worker_profile_edit_sheet.dart';
import 'package:zuno/shared/widgets/error_banner.dart';
import 'package:zuno/shared/widgets/status_pill.dart';
import 'package:zuno/shared/widgets/app_messages.dart';
import 'package:zuno/shared/widgets/app_permissions_link.dart';
import 'package:zuno/shared/widgets/avatar_crop_screen.dart';

/// The worker's own details, as a page of its own.
///
/// These used to sit open on the home screen, where four labelled rows, two pills and a photo stood
/// between the money at the top and the work record at the bottom — details a worker sets up once and
/// returns to rarely, given the same room as the figures they open the app for. Home now carries a
/// summary that opens this, which is how the business side already works.
class WorkerProfileScreen extends ConsumerWidget {
  const WorkerProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dashboardAsync = ref.watch(workerDashboardProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Your profile')),
      body: dashboardAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: ErrorBanner(message: error.toString()),
          ),
        ),
        data: (dashboard) {
          final profile = dashboard.profile;

          if (profile == null) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text('Your profile could not be loaded.'),
              ),
            );
          }

          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
            children: [
              _Summary(profile: profile),
              const SizedBox(height: 12),
              _DetailsCard(profile: profile),
              const SizedBox(height: 12),
              _PayoutCard(profile: profile),
              const SizedBox(height: 12),
              const AppPermissionsLink(),
            ],
          );
        },
      ),
    );
  }
}

/// Who this is, before anything can be changed.
class _Summary extends StatelessWidget {
  const _Summary({required this.profile});

  final WorkerProfile profile;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            // Tappable, because a picture is the main thing a business has to go on when choosing
            // between two strangers for an evening's work.
            const _ProfilePhoto(),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    profile.fullName,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  Text(
                    profile.email,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 7),
                  WorkerLevelBadge(profile: profile),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Everything a business sees, and the way in to changing it.
class _DetailsCard extends StatelessWidget {
  const _DetailsCard({required this.profile});

  final WorkerProfile profile;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(18, 16, 18, 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'YOUR DETAILS',
              style: theme.textTheme.labelSmall?.copyWith(
                letterSpacing: 0.9,
                fontWeight: FontWeight.w700,
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 10),
            DetailRow.inline(
              label: 'Phone',
              // Said plainly rather than left blank: without a number no business can reach this
              // worker about a job, and they are the only person who can fix it.
              value:
                  profile.phoneNumber ??
                  'Not added — businesses cannot call you',
              isMissing: profile.phoneNumber == null,
            ),
            DetailRow.inline(
              label: 'UPI',
              value: profile.maskedUpi ?? 'Not added — you cannot be paid yet',
              isMissing: !profile.hasPayoutDestination,
            ),
            DetailRow.inline(
              label: 'Hourly rate',
              value: profile.hourlyRate == null
                  ? 'Not set'
                  : rupees(profile.hourlyRate!),
              isMissing: profile.hourlyRate == null,
            ),
            DetailRow.inline(
              label: 'Experience',
              value: profile.experienceLabel,
              isMissing: profile.experienceYears == null,
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 6,
              children: [
                StatusPill(
                  label: profile.availabilityLabel,
                  tone: profile.availabilityTone,
                  compact: true,
                ),
                StatusPill(
                  label: 'ID ${profile.verificationStatus}',
                  tone: verificationTone(profile.verificationStatus),
                  compact: true,
                ),
              ],
            ),
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: () =>
                    showWorkerProfileEditSheet(context, profile: profile),
                icon: const Icon(Icons.edit_outlined, size: 18),
                label: const Text('Edit Profile'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Whether wages can actually arrive.
///
/// Stated on its own rather than as one more row, because it is the single condition that stops money
/// reaching a worker at all — and unlike an unset hourly rate, it cannot be worked around.
class _PayoutCard extends StatelessWidget {
  const _PayoutCard({required this.profile});

  final WorkerProfile profile;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final state = switch (profile) {
      _ when !profile.hasPayoutDestination => 'NoAddress',
      _ when !profile.canReceivePayouts => 'Checking',
      _ => 'Ready',
    };
    final entry = UiConfig.current.entry('WorkerPayoutReadiness', state);
    final icon = entry.iconData;
    final title = entry.label;
    final detail = (entry.detail ?? '').replaceAll(
      '{upi}',
      '${profile.maskedUpi}',
    );
    final tone = entry.statusTone;

    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: theme.colorScheme.onSurfaceVariant),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          title,
                          style: theme.textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      StatusPill(
                        label: profile.payoutVerificationStatus,
                        tone: tone,
                        compact: true,
                      ),
                    ],
                  ),
                  const SizedBox(height: 3),
                  Text(
                    detail,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The worker's picture, and the way to change it.
///
/// Tapping it picks from the gallery and uploads. A camera option is deliberately not offered here:
/// the picker already exposes it on every phone this targets, and a second button for the same job
/// costs more than it earns.
class _ProfilePhoto extends ConsumerStatefulWidget {
  const _ProfilePhoto();

  @override
  ConsumerState<_ProfilePhoto> createState() => _ProfilePhotoState();
}

class _ProfilePhotoState extends ConsumerState<_ProfilePhoto> {
  bool _isUploading = false;

  Future<void> _pick() async {
    final picked = await ImagePicker().pickImage(source: ImageSource.gallery);

    if (picked == null) return;

    // Bytes rather than a path, because on the web `picked.path` is a blob URL and every
    // path-based API fails there. Framing it first means the circle shows the worker's face
    // rather than whatever happened to sit in the middle of the photo.
    final rawBytes = await picked.readAsBytes();
    if (!mounted) return;

    final compressed = await AvatarCropScreen.frame(context, rawBytes);
    if (compressed == null || !mounted) return;

    setState(() => _isUploading = true);

    final messenger = AppMessenger.of(context);
    final notifier = ref.read(workerDashboardProvider.notifier);

    try {
      await notifier.setPhoto(bytes: compressed);
      messenger.showSuccess('Photo updated.');
    } catch (e) {
      if (!mounted) return;
      messenger.showFailure(e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _isUploading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final photoUrl = ref
        .watch(workerDashboardProvider)
        .maybeWhen(data: (d) => d.profile?.photoUrl, orElse: () => null);

    return GestureDetector(
      onTap: _isUploading ? null : _pick,
      child: Stack(
        children: [
          WorkerAvatar(photoUrl: photoUrl, radius: 30),
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
                  ? SizedBox(
                      width: 11,
                      height: 11,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: theme.colorScheme.onPrimary,
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

/// The worker's picture wherever it appears, with the same fallback every time.
///
/// Shared so the summary here and the card on Home cannot drift apart — the home card is not a place
/// to upload from, only to recognise yourself in.
class WorkerAvatar extends StatelessWidget {
  const WorkerAvatar({required this.photoUrl, this.radius = 21, super.key});

  final String? photoUrl;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final url = photoUrl;

    return CircleAvatar(
      radius: radius,
      backgroundColor: theme.colorScheme.primaryContainer,
      // The cache is keyed on the URL, and replacing a JPEG with a JPEG reuses it — so the key
      // carries the URL and a stale picture cannot survive an upload.
      backgroundImage: url == null || url.isEmpty
          ? null
          : CachedNetworkImageProvider('${ApiConstants.baseUrl}$url'),
      child: url == null || url.isEmpty
          ? Icon(
              Icons.person,
              size: radius * 1.05,
              color: theme.colorScheme.onPrimaryContainer,
            )
          : null,
    );
  }
}

/// The worker's standing, and what the next step costs.
///
/// Names experience, never quality. There are no worker ratings in the app yet, so a badge reading
/// "Trusted" or "Top rated" would be claiming something nobody has said.
class WorkerLevelBadge extends StatelessWidget {
  const WorkerLevelBadge({
    required this.profile,
    this.showNextStep = true,
    super.key,
  });

  final WorkerProfile profile;

  /// Whether to say how many jobs the next level is away. Dropped where space is tight.
  final bool showNextStep;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    // A Wrap, not a Row: the pill and the nudge beside it overflowed a narrow card by 7.5px, and
    // the nudge is the half that can drop to its own line without losing anything.
    return Wrap(
      spacing: 6,
      runSpacing: 2,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        StatusPill(
          icon: Icons.workspace_premium_outlined,
          label: 'Level ${profile.level} · ${profile.levelName}',
          tone: profile.level >= 4
              ? StatusTone.success
              : profile.level >= 2
              ? StatusTone.progress
              : StatusTone.waiting,
          compact: true,
        ),
        if (showNextStep)
          // What is actually in the way, in the server's words. A level a worker can reach beats
          // one they were merely assigned — but only if the step named is the real one. This used
          // to be a bare job count, which became a lie once the level stopped resting on jobs
          // alone: a worker with thirty jobs for one business was told "0 jobs to level 3".
          if (profile.nextLevelRequirement case final step?
              when step.isNotEmpty)
            Text(
              '$step to level ${profile.level + 1}',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
      ],
    );
  }
}
