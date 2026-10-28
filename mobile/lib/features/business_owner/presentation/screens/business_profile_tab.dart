import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:zuno/core/constants/app_constants.dart';
import 'package:zuno/core/theme/app_colors.dart';
import 'package:zuno/core/ui_config/ui_config.dart';
import 'package:zuno/features/business_owner/domain/entities/business_profile.dart';
import 'package:zuno/core/constants/api_constants.dart';
import 'package:zuno/shared/widgets/status_pill.dart';
import 'package:zuno/features/business_owner/presentation/providers/business_profile_notifier.dart';
import 'package:zuno/shared/widgets/error_banner.dart';
import 'package:zuno/shared/widgets/primary_button.dart';
import 'package:zuno/shared/widgets/app_messages.dart';
import 'package:zuno/shared/widgets/app_permissions_link.dart';
import 'package:zuno/shared/widgets/avatar_crop_screen.dart';

/// The profile as a page of its own, opened from the business home.
///
/// It stopped being a bottom-bar destination: a business sets its details up once and comes
/// back to them rarely, which is not what a permanent tab is for. The form itself is unchanged
/// — this only gives it the app bar and back arrow the shell used to provide.
class BusinessProfileScreen extends StatelessWidget {
  const BusinessProfileScreen({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Business profile')),
    body: const BusinessProfileTab(),
  );
}

class BusinessProfileTab extends ConsumerWidget {
  const BusinessProfileTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profileAsync = ref.watch(businessProfileProvider);

    return profileAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, _) => Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: ErrorBanner(message: error.toString()),
        ),
      ),
      data: (profile) => _BusinessProfileForm(profile: profile),
    );
  }
}

class _BusinessProfileForm extends ConsumerStatefulWidget {
  const _BusinessProfileForm({required this.profile});

  final BusinessProfile profile;

  @override
  ConsumerState<_BusinessProfileForm> createState() =>
      _BusinessProfileFormState();
}

class _BusinessProfileFormState extends ConsumerState<_BusinessProfileForm> {
  final _formKey = GlobalKey<FormState>();
  late final _businessNameController = TextEditingController(
    text: widget.profile.businessName,
  );
  late final _businessTypeController = TextEditingController(
    text: widget.profile.businessType,
  );
  late final _gstNumberController = TextEditingController(
    text: widget.profile.gstNumber,
  );
  late final _descriptionController = TextEditingController(
    text: widget.profile.description,
  );
  late final _addressLine1Controller = TextEditingController(
    text: widget.profile.addressLine1,
  );
  late final _addressLine2Controller = TextEditingController(
    text: widget.profile.addressLine2,
  );
  late final _cityController = TextEditingController(text: widget.profile.city);
  late final _stateController = TextEditingController(
    text: widget.profile.state,
  );
  late final _postalCodeController = TextEditingController(
    text: widget.profile.postalCode,
  );

  bool _isSaving = false;
  String? _errorMessage;

  @override
  void dispose() {
    _businessNameController.dispose();
    _businessTypeController.dispose();
    _gstNumberController.dispose();
    _descriptionController.dispose();
    _addressLine1Controller.dispose();
    _addressLine2Controller.dispose();
    _cityController.dispose();
    _stateController.dispose();
    _postalCodeController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    FocusScope.of(context).unfocus();
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isSaving = true;
      _errorMessage = null;
    });

    try {
      await ref
          .read(businessProfileProvider.notifier)
          .updateProfile(
            businessName: _businessNameController.text.trim(),
            businessType: _emptyToNull(_businessTypeController.text),
            gstNumber: _emptyToNull(_gstNumberController.text),
            description: _emptyToNull(_descriptionController.text),
            logoUrl: widget.profile.logoUrl,
            addressLine1: _emptyToNull(_addressLine1Controller.text),
            addressLine2: _emptyToNull(_addressLine2Controller.text),
            city: _emptyToNull(_cityController.text),
            addressState: _emptyToNull(_stateController.text),
            postalCode: _emptyToNull(_postalCodeController.text),
            // Keeps what was saved; the default only fills a country that was never set.
            country: widget.profile.country ?? AppConstants.defaultCountry,
          );
      if (mounted) context.showSuccessMessage('Business profile updated.');
    } catch (e) {
      setState(() => _errorMessage = e.toString());
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  String? _emptyToNull(String value) =>
      value.trim().isEmpty ? null : value.trim();

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: () => ref.refresh(businessProfileProvider.future),
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Identity, not performance. The trust record lives on Home, where an owner goes
              // to see how they are doing; this screen is for what the business *is*.
              _ProfileSummary(profile: widget.profile),
              const SizedBox(height: 14),
              // The shared pill, so this reads like every other state badge. Words, tone and
              // icon all come from the server's labels: Verified is the success green, anything
              // else is still waiting, in the "in progress" amber.
              StatusPill(
                label:
                    'Verification: '
                    '${UiConfig.current.label('BusinessVerification', widget.profile.verificationStatus)}',
                tone: UiConfig.current.tone(
                  'BusinessVerification.Badge',
                  widget.profile.verificationStatus,
                ),
                icon: UiConfig.current.icon(
                  'BusinessVerification.Badge',
                  widget.profile.verificationStatus,
                ),
              ),
              const SizedBox(height: 16),
              if (_errorMessage != null) ...[
                ErrorBanner(message: _errorMessage!),
                const SizedBox(height: 16),
              ],
              _FieldLabel('Business name'),
              TextFormField(
                controller: _businessNameController,
                decoration: const InputDecoration(border: OutlineInputBorder()),
                validator: (value) => (value == null || value.trim().isEmpty)
                    ? 'Business name is required.'
                    : null,
              ),
              const SizedBox(height: 16),
              _FieldLabel('Business type'),
              TextFormField(
                controller: _businessTypeController,
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  hintText: 'e.g. Sole Proprietorship',
                ),
              ),
              const SizedBox(height: 16),
              _FieldLabel('GST number'),
              TextFormField(
                controller: _gstNumberController,
                textCapitalization: TextCapitalization.characters,
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  hintText: '15-character GSTIN',
                ),
              ),
              const SizedBox(height: 16),
              _FieldLabel('Description'),
              TextFormField(
                controller: _descriptionController,
                maxLines: 3,
                decoration: const InputDecoration(border: OutlineInputBorder()),
              ),
              const SizedBox(height: 24),
              Text(
                'Business address',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _addressLine1Controller,
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  labelText: 'Address line 1',
                ),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _addressLine2Controller,
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  labelText: 'Address line 2',
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _cityController,
                      decoration: const InputDecoration(
                        border: OutlineInputBorder(),
                        labelText: 'City',
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextFormField(
                      controller: _stateController,
                      decoration: const InputDecoration(
                        border: OutlineInputBorder(),
                        labelText: 'State',
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _postalCodeController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  labelText: 'Postal code',
                ),
              ),
              const SizedBox(height: 28),
              PrimaryButton(
                label: 'Save changes',
                onPressed: _save,
                isLoading: _isSaving,
              ),
              const SizedBox(height: 20),
              const AppPermissionsLink(),
            ],
          ),
        ),
      ),
    );
  }
}

class _FieldLabel extends StatelessWidget {
  const _FieldLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 6),
    child: Text(text, style: Theme.of(context).textTheme.labelLarge),
  );
}

/// The business's picture, and the control for changing it.
///
/// Tappable, with a camera badge, because an avatar that can be changed and an avatar that
/// cannot look identical otherwise — and a business that cannot find where to add its picture
/// concludes the app has no such feature.
class _ProfileAvatar extends ConsumerStatefulWidget {
  const _ProfileAvatar({required this.profile});

  final BusinessProfile profile;

  @override
  ConsumerState<_ProfileAvatar> createState() => _ProfileAvatarState();
}

class _ProfileAvatarState extends ConsumerState<_ProfileAvatar> {
  bool _isBusy = false;

  /// Picks a photo, lets the owner frame it, re-encodes it, and sends it up.
  Future<void> _pick(ImageSource source) async {
    final picked = await ImagePicker().pickImage(source: source);
    if (picked == null) return;

    final rawBytes = await picked.readAsBytes();
    if (!mounted) return;

    final compressed = await AvatarCropScreen.frame(context, rawBytes);
    if (compressed == null || !mounted) return;

    setState(() => _isBusy = true);
    try {
      final previousUrl = widget.profile.logoUrl;
      await ref.read(businessProfileProvider.notifier).uploadLogo(compressed);

      // Replacing a JPEG with a JPEG reuses the same URL, and Flutter's image cache is keyed
      // on exactly that — so without evicting, the old picture stays on screen and a
      // successful upload looks like it did nothing at all.
      await _evict(previousUrl);
      await _evict(ref.read(businessProfileProvider).value?.logoUrl);

      _say('Profile picture updated');
    } catch (e) {
      _say(_readable(e), failed: true);
    } finally {
      if (mounted) setState(() => _isBusy = false);
    }
  }

  /// Drops a picture from the image cache so the next paint fetches it again.
  static Future<void> _evict(String? url) async {
    if (url == null || url.isEmpty) return;
    await NetworkImage('${ApiConstants.baseUrl}$url').evict();
  }

  Future<void> _remove() async {
    setState(() => _isBusy = true);
    try {
      final previousUrl = widget.profile.logoUrl;
      await ref.read(businessProfileProvider.notifier).removeLogo();
      await _evict(previousUrl);
      _say('Profile picture removed');
    } catch (e) {
      _say(_readable(e), failed: true);
    } finally {
      if (mounted) setState(() => _isBusy = false);
    }
  }

  void _say(String message, {bool failed = false}) {
    if (!mounted) return;
    failed
        ? context.showFailureMessage(message)
        : context.showSuccessMessage(message);
  }

  static String _readable(Object error) =>
      error.toString().replaceFirst('Exception: ', '');

  Future<void> _openMenu() async {
    final hasPicture = widget.profile.logoUrl != null;

    final choice = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text('Choose from gallery'),
              onTap: () => Navigator.pop(sheetContext, 'gallery'),
            ),
            ListTile(
              leading: const Icon(Icons.photo_camera_outlined),
              title: const Text('Take a photo'),
              onTap: () => Navigator.pop(sheetContext, 'camera'),
            ),
            if (hasPicture)
              ListTile(
                leading: Icon(
                  Icons.delete_outline,
                  color: Theme.of(sheetContext).colorScheme.error,
                ),
                title: Text(
                  'Remove photo',
                  style: TextStyle(
                    color: Theme.of(sheetContext).colorScheme.error,
                  ),
                ),
                onTap: () => Navigator.pop(sheetContext, 'remove'),
              ),
          ],
        ),
      ),
    );

    switch (choice) {
      case 'gallery':
        await _pick(ImageSource.gallery);
      case 'camera':
        await _pick(ImageSource.camera);
      case 'remove':
        await _remove();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final profile = widget.profile;
    final logoUrl = profile.logoUrl;

    return Semantics(
      button: true,
      label: logoUrl == null
          ? 'Add a profile picture'
          : 'Change the profile picture',
      child: InkWell(
        onTap: _isBusy ? null : _openMenu,
        customBorder: const CircleBorder(),
        child: Stack(
          children: [
            CircleAvatar(
              radius: 30,
              backgroundColor: theme.colorScheme.primaryContainer,
              backgroundImage: logoUrl != null
                  ? NetworkImage('${ApiConstants.baseUrl}$logoUrl')
                  : null,
              child: logoUrl == null
                  ? Text(
                      profile.businessName.isNotEmpty
                          ? profile.businessName[0].toUpperCase()
                          : '?',
                      style: theme.textTheme.headlineSmall?.copyWith(
                        color: theme.colorScheme.onPrimaryContainer,
                        fontWeight: FontWeight.w700,
                      ),
                    )
                  : null,
            ),

            if (_isBusy)
              Positioned.fill(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: theme.colorScheme.scrim.withValues(alpha: 0.45),
                  ),
                  child: const Padding(
                    padding: EdgeInsets.all(18),
                    child: CircularProgressIndicator(strokeWidth: 2.5),
                  ),
                ),
              )
            else
              // The affordance. Small, but it is the only thing saying the picture can be
              // changed at all.
              Positioned(
                right: 0,
                bottom: 0,
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primary,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: theme.colorScheme.surface,
                      width: 2,
                    ),
                  ),
                  child: Icon(
                    Icons.photo_camera,
                    size: 13,
                    color: theme.colorScheme.onPrimary,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// The business at a glance, above the editable fields.
///
/// A profile screen that opens straight into a column of text inputs reads as a form, not as
/// "this is my business". The logo, name and level say whose page this is before anything can
/// be changed.
class _ProfileSummary extends StatelessWidget {
  const _ProfileSummary({required this.profile});

  final BusinessProfile profile;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final location = [
      profile.city,
      profile.state,
    ].whereType<String>().where((s) => s.isNotEmpty).join(', ');

    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            _ProfileAvatar(profile: profile),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    profile.businessName,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  if (profile.businessType case final type?
                      when type.isNotEmpty)
                    Text(
                      type,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  if (location.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        Icon(
                          Icons.place_outlined,
                          size: 13,
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                        const SizedBox(width: 3),
                        Expanded(
                          child: Text(
                            location,
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
                  const SizedBox(height: 7),
                  StatusPill(
                    label: '${profile.levelName} · Level ${profile.level}',
                    tone: profile.level > 1
                        ? StatusTone.success
                        : StatusTone.waiting,
                    compact: true,
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
