class ApiConstants {
  const ApiConstants._();

  /// Configuration-driven — supply via `--dart-define=API_BASE_URL=...`.
  /// Defaults to the Android-emulator loopback alias for the host machine's localhost.
  static const String baseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://10.0.2.2:5056',
  );

  static const String apiVersion = 'v1';

  static const Duration connectTimeout = Duration(seconds: 15);
  static const Duration receiveTimeout = Duration(seconds: 15);

  static const String registerPath = '/api/$apiVersion/auth/register';
  static const String loginPath = '/api/$apiVersion/auth/login';
  static const String refreshTokenPath = '/api/$apiVersion/auth/refresh-token';
  static const String revokeTokenPath = '/api/$apiVersion/auth/revoke-token';
  static const String forgotPasswordPath =
      '/api/$apiVersion/auth/forgot-password';
  static const String resetPasswordPath =
      '/api/$apiVersion/auth/reset-password';
  static const String changePasswordPath =
      '/api/$apiVersion/auth/change-password';
  static const String currentUserPath = '/api/$apiVersion/auth/me';

  /// The signed-in account's own picture.
  static const String currentUserPhotoPath = '$currentUserPath/photo';

  static const String serviceCategoriesPath =
      '/api/$apiVersion/service-categories';
  static const String statesPath = '/api/$apiVersion/states';
  static const String districtsPath = '/api/$apiVersion/districts';

  /// The app owner's catalogue: the kinds of work the whole product offers.
  static const String adminCatalogCategoriesPath =
      '/api/$apiVersion/admin/catalog/categories';
  static String adminCatalogCategoryPath(String id) =>
      '$adminCatalogCategoriesPath/$id';
  static String adminCatalogSubCategoriesPath(String categoryId) =>
      '${adminCatalogCategoryPath(categoryId)}/sub-categories';
  static String adminCatalogSubCategoryPath(String id) =>
      '/api/$apiVersion/admin/catalog/sub-categories/$id';

  static const String businessProfilePath = '/api/$apiVersion/business/profile';

  /// The business's profile picture: POST to set it, DELETE to remove it.
  static const String businessProfileLogoPath = '$businessProfilePath/logo';
  static const String businessDashboardPath =
      '/api/$apiVersion/business/dashboard';
  static const String businessServicesPath =
      '/api/$apiVersion/business/services';
  static String businessServicePath(String id) => '$businessServicesPath/$id';
  static const String businessWorkersPath = '/api/$apiVersion/business/workers';
  static const String inviteWorkerPath =
      '/api/$apiVersion/business/workers/invite';
  static String businessWorkerPath(String id) => '$businessWorkersPath/$id';

  static String businessWorkerBusyDatesPath(String id) =>
      '$businessWorkersPath/$id/busy-dates';
  /// The boxes this service asks a customer to fill in. PUT replaces the whole set.
  static String businessServiceQuestionsPath(String id) =>
      '${businessServicePath(id)}/questions';
  static String businessServiceImageSlotPath(String id, int slot) =>
      '${businessServicePath(id)}/images/$slot';
  static String businessServiceVideoPath(String id) =>
      '${businessServicePath(id)}/video';
  static String businessServiceVariantsPath(String id) =>
      '${businessServicePath(id)}/variants';
  static String businessServiceVariantPath(String id, String variantId) =>
      '${businessServiceVariantsPath(id)}/$variantId';
  static String businessServiceVariantImageSlotPath(
    String id,
    String variantId,
    int slot,
  ) => '${businessServiceVariantPath(id, variantId)}/images/$slot';
  static String businessServiceVariantVideoPath(String id, String variantId) =>
      '${businessServiceVariantPath(id, variantId)}/video';

  static const String workerProfilePath = '/api/$apiVersion/worker/profile';
  static const String workerDashboardPath = '/api/$apiVersion/worker/dashboard';
  static const String workerPhotoPath = '/api/$apiVersion/worker/profile/photo';

  /// Looking a place up by name. Proxied through our own server, never called direct.
  static const String placeSearchPath = '/api/$apiVersion/places/search';

  /// The road route between two points, for drawing the way to a job.
  static const String placeRoutePath = '/api/$apiVersion/places/route';

  /// Naming the place at a set of coordinates, so a shared location can be shown as a name.
  static const String placeReversePath = '/api/$apiVersion/places/reverse';
  static String hiringBusinessPath(String id) =>
      '$workerHiringPostsPath/businesses/$id';

  static const String workerInvitationsPath =
      '/api/$apiVersion/worker/invitations';
  static String respondToWorkerInvitationPath(String id) =>
      '$workerInvitationsPath/$id/respond';

  static const String customerServicesPath =
      '/api/$apiVersion/customer/services';
  static String customerServiceDetailPath(String id) =>
      '$customerServicesPath/$id';

  /// Today's seven banner services, rotated daily by the server.
  static const String customerBannersPath = '$customerServicesPath/banners';

  /// Every section of the home screen in one answer, composed so none of them repeat.
  static const String customerHomeSectionsPath = '$customerServicesPath/home';

  static const String customerBusinessesPath =
      '/api/$apiVersion/customer/businesses';
  static String customerBusinessDetailPath(String id) =>
      '$customerBusinessesPath/$id';

  static const String customerBookingsPath =
      '/api/$apiVersion/customer/bookings';

  /// One order on its own. What a notification needs: it carries an id, not a booking.
  static String customerBookingPath(String id) => '$customerBookingsPath/$id';
  static String customerBookingCancelPath(String id) =>
      '$customerBookingsPath/$id/cancel';
  static String customerBookingRatePath(String id) =>
      '$customerBookingsPath/$id/rate';

  // Messages on a booking. One pair of routes for both sides: who is asking is settled from the
  // booking, not from the path, so there is no customer and business version to drift apart.
  static const String bookingThreadsPath = '/api/$apiVersion/bookings/threads';
  static String bookingMessagesPath(String bookingId) =>
      '/api/$apiVersion/bookings/$bookingId/messages';

  static const String businessBookingsPath =
      '/api/$apiVersion/business/bookings';

  /// One order on its own, for the same reason as the customer's.
  static String businessBookingPath(String id) => '$businessBookingsPath/$id';
  static String businessBookingConfirmPath(String id) =>
      '$businessBookingsPath/$id/confirm';
  static String businessBookingStartPath(String id) =>
      '$businessBookingsPath/$id/start';
  /// Offering, countering and accepting the crew size and price.
  ///
  /// Two routes for each verb, one per side — the server works out who is calling and enforces
  /// that only the other side may answer an open offer.
  static String businessBookingTermsPath(String id) =>
      '$businessBookingsPath/$id/terms';
  static String businessBookingAcceptTermsPath(String id, String proposalId) =>
      '$businessBookingsPath/$id/terms/$proposalId/accept';
  static String customerBookingTermsPath(String id) =>
      '$customerBookingsPath/$id/terms';
  static String customerBookingAcceptTermsPath(String id, String proposalId) =>
      '$customerBookingsPath/$id/terms/$proposalId/accept';

  static String businessBookingCompletePath(String id) =>
      '$businessBookingsPath/$id/complete';
  static String businessBookingAssignWorkerPath(String id) =>
      '$businessBookingsPath/$id/assign-worker';

  /// What one crew member is on one job. A blank role takes it away.
  static String businessBookingCrewRolePath(String id, String workerProfileId) =>
      '$businessBookingsPath/$id/crew/$workerProfileId/role';
  static String businessBookingCancelPath(String id) =>
      '$businessBookingsPath/$id/cancel';

  static const String workerJobsPath = '/api/$apiVersion/worker/jobs';
  static String workerJobPath(String id) => '$workerJobsPath/$id';
  static String workerJobRespondPath(String id) =>
      '$workerJobsPath/$id/respond';
  static String workerJobCompletePath(String id) =>
      '$workerJobsPath/$id/complete';

  // The job's lead moving the WHOLE order, not their own row. Separate routes because the
  // business controller is closed to the BusinessOwner role, and a lead is a worker.
  static String workerJobStartJobPath(String id) =>
      '$workerJobsPath/$id/start-job';
  static String workerJobFinishJobPath(String id) =>
      '$workerJobsPath/$id/finish-job';

  static const String businessHiringPostsPath =
      '/api/$apiVersion/business/hiring-posts';
  static String businessHiringPostImagePath(String id) =>
      '$businessHiringPostsPath/$id/image';
  static String confirmHiringPostApplicationPath(String applicationId) =>
      '$businessHiringPostsPath/applications/$applicationId/confirm';
  static String rejectHiringPostApplicationPath(String applicationId) =>
      '$businessHiringPostsPath/applications/$applicationId/reject';
  static String updateHiringPostPath(String id) =>
      '$businessHiringPostsPath/$id';
  static String deleteHiringPostPath(String id) =>
      '$businessHiringPostsPath/$id';
  static String startHiringPostWorkPath(String id) =>
      '$businessHiringPostsPath/$id/start';
  static String completeHiringPostWorkPath(String id) =>
      '$businessHiringPostsPath/$id/complete';
  static String inviteWorkerToHiringPostPath(String id) =>
      '$businessHiringPostsPath/$id/invite';
  static String raiseHiringPostSalaryPath(String applicationId) =>
      '$businessHiringPostsPath/applications/$applicationId/salary';

  /// Opens a pay run for everyone still owed on a job.
  static String hiringPostPayoutsPath(String id) =>
      '$businessHiringPostsPath/$id/payouts';

  /// Confirms the business's single payment cleared, which triggers the split.
  static String confirmHiringPostPayoutPath(String batchId) =>
      '$businessHiringPostsPath/payouts/$batchId/confirm';

  static const String workerHiringPostsPath =
      '/api/$apiVersion/worker/hiring-posts';
  static String applyToHiringPostPath(String id) =>
      '$workerHiringPostsPath/$id/apply';
  /// Jobs a business invited this worker onto, still waiting on an answer.
  static const String workerJobOffersPath = '$workerHiringPostsPath/offers';

  /// Work this worker took through a hiring post, past and future.
  static const String workerPostJobsPath = '$workerHiringPostsPath/mine';

  static String respondToHiringPostOfferPath(String applicationId) =>
      '$workerHiringPostsPath/applications/$applicationId/respond';

  /// The worker confirming wages arrived, or reporting that they never did.
  static String respondToPaymentPath(String applicationId) =>
      '$workerHiringPostsPath/applications/$applicationId/payment-response';

  // ---- notifications -----------------------------------------------------------------------
  // One set for all three roles. A notification is addressed to a user, not a role, and the
  // server decides what comes back from the token.

  static const String notificationsPath = '/api/$apiVersion/notifications';

  /// Just the badge number. Its own call because it is asked for on every app resume.
  static const String unreadNotificationCountPath =
      '$notificationsPath/unread-count';

  static String markNotificationReadPath(String id) =>
      '$notificationsPath/$id/read';

  static const String markAllNotificationsReadPath =
      '$notificationsPath/read-all';
}
