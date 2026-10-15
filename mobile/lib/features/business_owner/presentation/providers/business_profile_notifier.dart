import 'dart:typed_data';

import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:zuno/features/business_owner/domain/entities/business_profile.dart';
import 'package:zuno/features/business_owner/presentation/providers/business_providers.dart';

part 'business_profile_notifier.g.dart';

@riverpod
class BusinessProfileNotifier extends _$BusinessProfileNotifier {
  @override
  Future<BusinessProfile> build() =>
      ref.watch(businessRepositoryProvider).getMyProfile();

  Future<void> updateProfile({
    required String businessName,
    String? businessType,
    String? gstNumber,
    String? description,
    String? logoUrl,
    String? addressLine1,
    String? addressLine2,
    String? city,
    String? addressState,
    String? postalCode,
    String? country,
  }) async {
    // Deliberately does not set state = AsyncLoading() first: this method is called from a
    // form that is still on screen mid-save, and flipping to AsyncLoading would make the
    // watching widget's `.when(loading: ...)` branch tear down that very form, unmounting it
    // before the success snackbar / failure error banner can render. Errors propagate to the
    // caller so the form's own try/catch can show them without losing the user's input.
    final updated = await ref
        .read(businessRepositoryProvider)
        .updateMyProfile(
          businessName: businessName,
          businessType: businessType,
          gstNumber: gstNumber,
          description: description,
          logoUrl: logoUrl,
          addressLine1: addressLine1,
          addressLine2: addressLine2,
          city: city,
          state: addressState,
          postalCode: postalCode,
          country: country,
        );
    state = AsyncData(updated);
  }

  /// Sets the business's profile picture.
  ///
  /// Like [updateProfile], this never flips to [AsyncLoading]: the picture is changed from a
  /// screen that stays on show throughout, and tearing it down mid-upload would take the
  /// progress indicator with it. Errors propagate so the caller can say what went wrong.
  Future<void> uploadLogo(Uint8List imageBytes) async {
    final updated = await ref
        .read(businessRepositoryProvider)
        .uploadLogo(imageBytes);
    state = AsyncData(updated);
  }

  /// Removes the business's profile picture.
  Future<void> removeLogo() async {
    final updated = await ref.read(businessRepositoryProvider).removeLogo();
    state = AsyncData(updated);
  }
}
