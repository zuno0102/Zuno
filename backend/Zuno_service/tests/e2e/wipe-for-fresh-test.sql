-- Clears every account and everything they did, so the app can be tested from a standing start.
--
-- Deliberately KEPT:
--   roles, service_categories, service_sub_categories, states, districts
--       Reference data that ships with the app, not test data. Without a category no service can
--       be listed, and without districts a service covers nowhere — the first screen of testing
--       would fail for want of data nobody was going to type in by hand.
--   the admin account, and its profile
--       Approving a business is an admin act. Delete the only admin and every new business stays
--       invisible to customers, so the customer half of the app cannot be tested at all.
--   __EFMigrationsHistory
--       The record of which migrations have run. Clearing it would make the app try to build a
--       schema that is already there.

begin;

truncate table
    addresses,
    booking_agreement_proposals,
    booking_messages,
    booking_service_answers,
    booking_thread_clears,
    booking_worker_assignments,
    bookings,
    business_owner_profiles,
    business_service_districts,
    business_service_media,
    business_service_questions,
    business_service_variants,
    business_services,
    business_workers,
    customer_profiles,
    hiring_post_applications,
    hiring_post_salary_adjustments,
    hiring_posts,
    notifications,
    payout_batch_items,
    payout_batches,
    ratings,
    refresh_tokens,
    worker_payout_details,
    worker_profiles
cascade;

-- Everyone except the admin. Done after the truncates, so nothing still points at these rows.
delete from users
where id not in (select user_id from admin_profiles);

commit;
