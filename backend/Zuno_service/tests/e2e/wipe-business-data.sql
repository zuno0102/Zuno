-- Clears every business-related record, so the whole scenario can be tested from sign-up.
--
-- A hard delete, not the soft delete the app uses. Soft-deleted rows still satisfy unique indexes
-- and still turn up in any query written without the filter, so a "clean" database full of
-- is_deleted rows is not clean — it is a database where the next bug is invisible.
--
-- WHAT GOES: businesses and everything hanging off them — services, variants, their media,
-- districts and questions; orders with their answers, offers, messages and crew; hiring posts with
-- their applications, salary adjustments and pay runs; ratings; team membership; notifications.
--
-- WHAT STAYS: user accounts (so people can still sign in), customer and worker profiles, and the
-- catalogue — categories, sub-categories, states, districts. Those are reference data, not a
-- business's records.
--
-- Deletion runs child-first, following the foreign keys mapped before writing this.

\set ON_ERROR_STOP on

begin;

-- Pay runs: items reference both the batch and an application.
delete from payout_batch_items;
delete from payout_batches;

-- Hiring.
delete from hiring_post_salary_adjustments;
delete from hiring_post_applications;
delete from hiring_posts;

-- Orders.
delete from ratings;
delete from booking_worker_assignments;
delete from booking_service_answers;
delete from booking_agreement_proposals;
delete from booking_messages;
delete from booking_thread_clears;
delete from bookings;

-- Services.
delete from business_service_media;
delete from business_service_districts;
delete from business_service_questions;
delete from business_service_variants;
delete from business_services;

-- Team.
delete from business_workers;

-- Every notification pointed at one of the things above. Cleared wholesale rather than filtered:
-- a notification whose target no longer exists is a row that opens onto an error.
delete from notifications;

-- The businesses themselves. Accounts survive; their BusinessOwner role does too, so they can
-- register a business again — which is the first step of the scenario being tested.
delete from business_owner_profiles;

commit;

\echo ''
\echo 'Remaining:'
select 'business_owner_profiles' as t, count(*) from business_owner_profiles
union all select 'business_services', count(*) from business_services
union all select 'bookings', count(*) from bookings
union all select 'hiring_posts', count(*) from hiring_posts
union all select 'payout_batches', count(*) from payout_batches
union all select 'ratings', count(*) from ratings
union all select 'business_workers', count(*) from business_workers
union all select 'notifications', count(*) from notifications
union all select '--- kept ---', null
union all select 'users', count(*) from users
union all select 'customer_profiles', count(*) from customer_profiles
union all select 'worker_profiles', count(*) from worker_profiles
union all select 'service_categories', count(*) from service_categories
union all select 'districts', count(*) from districts;
