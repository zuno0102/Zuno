-- Every notification a business owner can receive, on owner@zuno.local, for testing on the phone.
--
-- Rows are inserted directly rather than produced by driving a customer and three workers through
-- the API. The chain from command handler to row is already proved by e2e-notifications.sh (103
-- live assertions); what this is for is the phone — the badge on the gradient header, the list,
-- and whether each row opens the screen it promises.
--
-- Every target points at a REAL order or post of this business's, so tapping actually loads
-- something rather than erroring on a made-up id.
--
-- Idempotent: fixed ids, deleted before re-inserting. No order, post, rating or status is touched.
--
-- Kinds   (Zuno.Domain/Enums/NotificationKind.cs)
--   40 BookingRequested  41 NewApplicants   42 OfferAnswered   43 AssignmentAnswered
--   44 WorkerFinishedWork  45 BookingCancelledByCustomer  46 RatingReceived
--   47 PaymentDisputed   60 ChatMessage
-- Targets (Zuno.Domain/Enums/NotificationTarget.cs)
--   1 Booking  3 BookingChat  10 HiringPost  11 HiringPostApplicants  40 Payouts  50 Profile

\set ON_ERROR_STOP on

begin;

delete from notifications where id::text like 'bb000000-0000-0000-0000-%';

insert into notifications
  (id, user_id, kind, title, body, target, target_id, read_at, is_deleted, status, created_date)
values
  -- Oldest first, so the newest ends up at the top of the list where the eye lands.

  -- Read already, so the list shows what a settled row looks like beside the unread ones.
  ('bb000000-0000-0000-0000-000000000001',
   '9ab8541b-8fe1-4e9c-b7cb-e75ef27a6309', 46,
   'You were rated 4 stars',
   '',
   50, '00000000-0000-0000-0000-000000000000',
   now() - interval '6 days', false, 1, now() - interval '6 days'),

  ('bb000000-0000-0000-0000-000000000002',
   '9ab8541b-8fe1-4e9c-b7cb-e75ef27a6309', 45,
   'Zuno Customer cancelled their booking',
   'The job on 30 Aug is off.',
   1, 'd0000000-0000-0000-0000-0000000000b7',
   now() - interval '4 days', false, 1, now() - interval '4 days'),

  -- Everything below is unread. This is what the badge on the header counts.

  -- The one about money going missing. Deliberately the oldest unread, so it is still on screen
  -- after the newer ones push down — a dispute must not scroll quietly out of sight.
  ('bb000000-0000-0000-0000-000000000003',
   '9ab8541b-8fe1-4e9c-b7cb-e75ef27a6309', 47,
   'Ravi Kumar reports they were not paid ₹900',
   'Nothing reached my UPI, and the job was two weeks ago.',
   40, '1a0aeb73-f13f-4a20-ac8c-51658acd062f',
   null, false, 1, now() - interval '2 days'),

  ('bb000000-0000-0000-0000-000000000004',
   '9ab8541b-8fe1-4e9c-b7cb-e75ef27a6309', 44,
   'Shajil S finished their part of the job',
   'The job on 14 Sep.',
   1, 'b0000000-0000-0000-0000-000000000005',
   null, false, 1, now() - interval '28 hours'),

  ('bb000000-0000-0000-0000-000000000005',
   '9ab8541b-8fe1-4e9c-b7cb-e75ef27a6309', 42,
   'Anita Menon turned down STEP 3km - catering helper',
   'The place is open again.',
   10, '86856b6f-a3ce-49b6-8ef3-b062a2224ed0',
   null, false, 1, now() - interval '9 hours'),

  ('bb000000-0000-0000-0000-000000000006',
   '9ab8541b-8fe1-4e9c-b7cb-e75ef27a6309', 41,
   'Suresh Nair applied to STEP 6km - kitchen assistant',
   '3 applicants are now waiting on your answer.',
   11, '8e2ab92c-28d1-48a2-82a2-3ef73fd257c1',
   null, false, 1, now() - interval '5 hours'),

  -- No body on purpose: an acceptance needs no follow-up, and the row should render without a
  -- second line.
  ('bb000000-0000-0000-0000-000000000007',
   '9ab8541b-8fe1-4e9c-b7cb-e75ef27a6309', 43,
   'Priya Menon accepted the job tomorrow',
   '',
   1, 'b0000000-0000-0000-0000-000000000004',
   null, false, 1, now() - interval '90 minutes'),

  ('bb000000-0000-0000-0000-000000000008',
   '9ab8541b-8fe1-4e9c-b7cb-e75ef27a6309', 40,
   'New booking request',
   'wedding catering on 11 Oct.',
   1, 'b0000000-0000-0000-0000-000000000002',
   null, false, 1, now() - interval '25 minutes'),

  -- Titled with the sender and bodied with what they said, the way a messaging app does it.
  ('bb000000-0000-0000-0000-000000000009',
   '9ab8541b-8fe1-4e9c-b7cb-e75ef27a6309', 60,
   'Zuno Customer',
   'Can the crew come at 5 instead of 6?',
   3, 'd0000000-0000-0000-0000-0000000000b6',
   null, false, 1, now() - interval '4 minutes');

commit;

\echo ''
\echo 'Seeded for owner@zuno.local:'
select count(*) filter (where read_at is null) || ' unread of ' || count(*) || ' total' as badge
from notifications
where user_id = '9ab8541b-8fe1-4e9c-b7cb-e75ef27a6309' and is_deleted = false;

select to_char(created_date, 'DD Mon HH24:MI') as when,
       case when read_at is null then 'UNREAD' else 'read' end as state,
       title
from notifications
where user_id = '9ab8541b-8fe1-4e9c-b7cb-e75ef27a6309' and is_deleted = false
order by created_date desc;
