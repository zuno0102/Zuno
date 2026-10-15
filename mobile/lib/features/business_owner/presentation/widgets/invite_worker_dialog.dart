import 'package:zuno/core/utils/formatting.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:zuno/features/business_owner/domain/entities/business_worker.dart';
import 'package:zuno/features/business_owner/presentation/providers/business_workers_notifier.dart';
import 'package:zuno/features/hiring_post/domain/entities/hiring_post.dart';
import 'package:zuno/features/hiring_post/presentation/providers/business_hiring_posts_notifier.dart';
import 'package:zuno/shared/widgets/error_banner.dart';

/// Invites someone by email or phone, suggesting the business's own workers as they type.
///
/// [post] pins the invite to one job. Passing it is what the crew section on a hiring post
/// does — the job is already known there, so the picker would only be asking a question that
/// has already been answered.
Future<void> showInviteWorkerDialog(BuildContext context, {HiringPost? post}) {
  return showDialog<void>(
    context: context,
    builder: (context) => _InviteWorkerDialog(post: post),
  );
}

class _InviteWorkerDialog extends ConsumerStatefulWidget {
  const _InviteWorkerDialog({this.post});

  /// When set, the invite goes to this job and the job picker is hidden.
  final HiringPost? post;

  @override
  ConsumerState<_InviteWorkerDialog> createState() =>
      _InviteWorkerDialogState();
}

class _InviteWorkerDialogState extends ConsumerState<_InviteWorkerDialog> {
  final _formKey = GlobalKey<FormState>();
  String _identifier = '';

  /// Null means "just add them to my workers list". Otherwise the invite is for one
  /// specific job, which is what gives the worker a date, time, place and rate to judge.
  String? _selectedPostId;

  bool _isSubmitting = false;
  String? _errorMessage;

  /// True when the dialog was opened from a job, so that job is fixed.
  bool get _isPinnedToPost => widget.post != null;

  @override
  void initState() {
    super.initState();
    _selectedPostId = widget.post?.id;
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
    });

    final identifier = _identifier.trim();
    final postId = _selectedPostId;

    try {
      if (postId == null) {
        await ref.read(businessWorkersProvider.notifier).invite(identifier);
      } else {
        await ref
            .read(businessHiringPostsProvider.notifier)
            .inviteWorker(postId: postId, workerIdentifier: identifier);
      }
      // Closing is the last thing done on success: calling setState afterwards would touch a
      // widget that is already on its way out.
      if (mounted) {
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = e.toString();
          _isSubmitting = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final postsAsync = ref.watch(businessHiringPostsProvider);

    // Every job someone can still be sent to, of both kinds: crew for a customer's order, and
    // crew for work the business took on outside the app. See HiringPost.isInvitable.
    final invitable = postsAsync.maybeWhen(
      data: (posts) => posts.where((p) => p.isInvitable()).toList(),
      orElse: () => const <HiringPost>[],
    );

    // The list refreshes under us after a successful invite, and the job just used can drop out
    // of it once its pending count rises. DropdownButtonFormField asserts its value is present
    // among its items, so fall back to null rather than pointing at a job no longer listed.
    final selectedId = invitable.any((p) => p.id == _selectedPostId)
        ? _selectedPostId
        : null;

    final selected = invitable
        .where((p) => p.id == selectedId)
        .cast<HiringPost?>()
        .firstWhere((p) => true, orElse: () => null);

    final pinned = widget.post;

    return AlertDialog(
      title: Text(pinned == null ? 'Invite a worker' : 'Invite to ${pinned.title}'),
      content: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (_errorMessage != null) ...[
                ErrorBanner(message: _errorMessage!),
                const SizedBox(height: 12),
              ],
              _WorkerIdentifierField(
                onChanged: (value) => _identifier = value,
              ),
              const SizedBox(height: 16),
              if (pinned != null)
                _JobSummary(post: pinned)
              else ...[
                DropdownButtonFormField<String?>(
                  initialValue: selectedId,
                  isExpanded: true,
                  decoration: const InputDecoration(
                    labelText: 'Invite them to',
                    border: OutlineInputBorder(),
                  ),
                  items: [
                    const DropdownMenuItem<String?>(
                      value: null,
                      child: Text('My workers list (no specific job)'),
                    ),
                    ...invitable.map(
                      (p) => DropdownMenuItem<String?>(
                        value: p.id,
                        // A job for a customer's order is named by that order, the way it reads
                        // in the bookings tab, so the two can be matched at a glance. The
                        // business's own work has no order to name and goes by its title.
                        child: Text(
                          p.bookingReference ??
                              '${p.title} · '
                                  '${formatDate(p.eventDate.toLocal())}',
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ),
                  ],
                  onChanged: (value) => setState(() => _selectedPostId = value),
                ),
                const SizedBox(height: 12),
                if (selected != null)
                  _JobSummary(post: selected)
                else
                  Text(
                    invitable.isEmpty
                        ? 'You have no open jobs to invite them to right now. They will '
                              'just be added to your workers list.'
                        : 'Pick a job and they will see its date, time, place and pay, '
                              'and can accept or turn it down.',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isSubmitting ? null : () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _isSubmitting ? null : _submit,
          child: _isSubmitting
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Text(
                  _isPinnedToPost || selectedId != null
                      ? 'Send job offer'
                      : 'Send invite',
                ),
        ),
      ],
    );
  }
}

/// Email/phone entry that suggests the business's own workers as you type.
///
/// The field still accepts free text, because the whole point of inviting by identifier is to
/// reach someone who is not on the roster yet. The suggestions just spare the business from
/// retyping — and from guessing — the address of people they already work with.
class _WorkerIdentifierField extends ConsumerWidget {
  const _WorkerIdentifierField({required this.onChanged});

  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final workers = ref
        .watch(businessWorkersProvider)
        .maybeWhen(
          data: (list) => list
              .where((w) => w.isActive && (w.workerEmail ?? w.workerPhone) != null)
              .toList(),
          orElse: () => const <BusinessWorker>[],
        );

    return Autocomplete<BusinessWorker>(
      optionsBuilder: (value) {
        final query = value.text.trim().toLowerCase();
        if (query.isEmpty) return workers;
        return workers.where((w) {
          final haystack = [
            w.workerName,
            w.workerEmail ?? '',
            w.workerPhone ?? '',
          ].join(' ').toLowerCase();
          return haystack.contains(query);
        });
      },
      displayStringForOption: (w) => w.workerEmail ?? w.workerPhone ?? '',
      onSelected: (w) => onChanged(w.workerEmail ?? w.workerPhone ?? ''),
      fieldViewBuilder: (context, textController, focusNode, onSubmitted) {
        // Reported through onChanged rather than by attaching a listener here: this builder
        // runs on every rebuild, and a listener added here would stack up on each one.
        return TextFormField(
          controller: textController,
          focusNode: focusNode,
          // Deliberately not autofocused.
          //
          // Autocomplete drops its list whenever the field holds focus and the builder returns
          // anything — and on an empty query that is every worker. Taking focus on open therefore
          // meant the dialog appeared with the whole roster already hanging over it, covering the
          // "Invite them to" dropdown underneath and raising the keyboard before anybody had
          // asked for either. Without it the dialog opens quiet, and the list arrives when the
          // field is tapped, which is when somebody is actually choosing.
          onChanged: onChanged,
          decoration: InputDecoration(
            labelText: 'Email or phone',
            hintText: workers.isEmpty
                ? 'The one they registered with'
                : 'Type a name, or the email they registered with',
            prefixIcon: const Icon(Icons.person_search_outlined),
            border: const OutlineInputBorder(),
          ),
          validator: (value) => (value == null || value.trim().isEmpty)
              ? 'Enter their email or phone number.'
              : null,
        );
      },
      optionsViewBuilder: (context, onSelected, options) => Align(
        alignment: Alignment.topLeft,
        child: Material(
          elevation: 4,
          borderRadius: BorderRadius.circular(8),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 220, maxWidth: 340),
            child: ListView.builder(
              shrinkWrap: true,
              padding: EdgeInsets.zero,
              itemCount: options.length,
              itemBuilder: (context, index) {
                final w = options.elementAt(index);
                return ListTile(
                  dense: true,
                  leading: CircleAvatar(
                    radius: 14,
                    backgroundColor: theme.colorScheme.primaryContainer,
                    child: Text(
                      w.workerName.isEmpty ? '?' : w.workerName[0].toUpperCase(),
                      style: theme.textTheme.labelMedium,
                    ),
                  ),
                  title: Text(w.workerName),
                  subtitle: Text(w.workerEmail ?? w.workerPhone ?? ''),
                  // Flags people already on another job, so the business can avoid an
                  // invite the clash check would only refuse.
                  trailing: w.isAtWork || w.isBooked
                      ? Text(
                          'busy',
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: theme.colorScheme.error,
                          ),
                        )
                      : null,
                  onTap: () => onSelected(w),
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}

/// The details the worker will be shown, echoed back to the business before sending — so it
/// is obvious what is being offered, and to whose diary the clash check will be applied.
class _JobSummary extends StatelessWidget {
  const _JobSummary({required this.post});

  final HiringPost post;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final where = post.location?.trim() ?? '';

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.colorScheme.secondaryContainer.withValues(alpha: 0.35),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _Line(
            icon: Icons.event_outlined,
            text:
                '${formatDate(post.eventDate.toLocal())}'
                ' · ${post.scheduleLabel}',
          ),
          if (where.isNotEmpty)
            _Line(icon: Icons.place_outlined, text: where),
          _Line(icon: Icons.payments_outlined, text: post.salaryLabel),
          _Line(
            icon: Icons.groups_outlined,
            text:
                '${post.workersNeeded - post.filledCount} of '
                '${post.workersNeeded} place(s) still open',
          ),
        ],
      ),
    );
  }
}

class _Line extends StatelessWidget {
  const _Line({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 15, color: theme.colorScheme.primary),
          const SizedBox(width: 8),
          Expanded(child: Text(text, style: theme.textTheme.bodySmall)),
        ],
      ),
    );
  }
}
