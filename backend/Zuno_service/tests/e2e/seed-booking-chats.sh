#!/usr/bin/env bash
# Conversations on the seeded bookings, covering what the Chat tab has to render.
#
# Five threads, chosen for what they put on screen rather than for variety's sake:
#
#   * unread from the business on a confirmed order, so the list shows a badge and bold preview;
#   * a thread whose last word is the customer's, so the preview reads "You: ...";
#   * a long back-and-forth, for bubble grouping and the one-timestamp-per-run rule;
#   * a single unanswered message from the customer, both ticks still single;
#   * an old settled thread on a completed booking, everything read.
#
# Bookings 1, 7 and 8 are left without any, which is also a case: they stay out of the chat list and
# are reached only from the booking's own Message button — and 1 (pending) and 8 (cancelled) have no
# Message button at all, because the conversation opens on confirmation and closes on cancellation.
#
# Idempotent: every row is deleted and re-inserted by fixed id.
set -euo pipefail

CUSTOMER_USER='fe005632-5e9a-4051-9c2f-e60ba5c0bf46'   # cust@zuno.local
OWNER_USER='9ab8541b-8fe1-4e9c-b7cb-e75ef27a6309'      # owner@zuno.local, Test Owner
SHAJIL_OWNER=''                                         # filled in below

PSQL="${PSQL:-psql}"
SECRETS="C:/Users/TLTuser/AppData/Roaming/Microsoft/UserSecrets/4e5c30fb-10fa-4613-a907-38ad9e1b98d5/secrets.json"
PGPASSWORD=$(grep -o '"ConnectionStrings:ZunoDatabase": "[^"]*"' "$SECRETS" | grep -o 'Password=[^;"]*' | cut -d= -f2)
export PGPASSWORD

q() { "$PSQL" -h 127.0.0.1 -U postgres -d "${ZUNO_DB:-zuno}" -At -F' | ' -c "$1"; }

# The owner behind "shajil shajil", for the threads on that business's bookings.
SHAJIL_OWNER=$(q "select b.user_id from business_owner_profiles b where b.business_name = 'shajil shajil' limit 1;")

# sender_role: 1 Customer, 2 Business
q "
begin;

delete from booking_messages where id::text like 'c0000000-0000-0000-0000-%';

insert into booking_messages
  (id, booking_id, sender_role, sender_user_id, body, read_at, is_deleted, status, created_date)
values
  -- Booking 3, confirmed and a fortnight out. Business wrote last and the customer has not read it:
  -- this is the thread that should carry an unread badge and a bold preview.
  --
  -- On a confirmed order rather than a pending one on purpose. Messaging opens when the business
  -- takes the order on, so a thread on a pending booking is not offered at all.
  ('c0000000-0000-0000-0000-000000000201', 'b0000000-0000-0000-0000-000000000003',
   1, '$CUSTOMER_USER', 'Hello — will the two coats be done in a single day?',
   now() - interval '22 hours', false, 1, now() - interval '23 hours'),
  ('c0000000-0000-0000-0000-000000000202', 'b0000000-0000-0000-0000-000000000003',
   2, '$SHAJIL_OWNER', 'Two days for exterior. The second coat needs the first one dry.',
   now() - interval '21 hours', false, 1, now() - interval '22 hours'),
  ('c0000000-0000-0000-0000-000000000203', 'b0000000-0000-0000-0000-000000000003',
   2, '$SHAJIL_OWNER', 'We will bring our own ladders and sheeting.',
   null, false, 1, now() - interval '20 hours'),
  ('c0000000-0000-0000-0000-000000000204', 'b0000000-0000-0000-0000-000000000003',
   2, '$SHAJIL_OWNER', 'Could you move the car off the drive that morning?',
   null, false, 1, now() - interval '3 hours'),

  -- Booking 4, tomorrow. The customer spoke last, so the preview reads 'You: ...' and there is no
  -- badge even though the thread is recent.
  ('c0000000-0000-0000-0000-000000000401', 'b0000000-0000-0000-0000-000000000004',
   2, '$OWNER_USER', 'We will be there by 4pm to set up the lights.',
   now() - interval '5 hours', false, 1, now() - interval '6 hours'),
  ('c0000000-0000-0000-0000-000000000402', 'b0000000-0000-0000-0000-000000000004',
   1, '$CUSTOMER_USER', 'Perfect. The hall opens at 3:30, ask for Rahul at the desk.',
   null, false, 1, now() - interval '5 hours'),

  -- Booking 6, finished and rated weeks ago. Everything read, nothing to act on — what a settled
  -- thread looks like far down the list.
  ('c0000000-0000-0000-0000-000000000601', 'b0000000-0000-0000-0000-000000000006',
   1, '$CUSTOMER_USER', 'Could you start on the Monday rather than the Sunday?',
   now() - interval '21 days', false, 1, now() - interval '21 days'),
  ('c0000000-0000-0000-0000-000000000602', 'b0000000-0000-0000-0000-000000000006',
   2, '$SHAJIL_OWNER', 'Monday is fine. We will come at 8.',
   now() - interval '20 days', false, 1, now() - interval '20 days'),
  ('c0000000-0000-0000-0000-000000000603', 'b0000000-0000-0000-0000-000000000006',
   1, '$CUSTOMER_USER', 'Thank you — the room looks very good.',
   now() - interval '11 days', false, 1, now() - interval '11 days'),

  -- Booking 9, an old completed job: one message from the customer that nobody answered. Single
  -- tick, no reply, and it still belongs in the list.
  ('c0000000-0000-0000-0000-000000000901', 'b0000000-0000-0000-0000-000000000009',
   1, '$CUSTOMER_USER', 'Do you have the paint code you used for the hall?',
   null, false, 1, now() - interval '26 days'),

  -- Booking 5, happening right now. A longer exchange, with runs from each side, for the bubble
  -- grouping and the one-timestamp-per-run rule.
  ('c0000000-0000-0000-0000-000000000501', 'b0000000-0000-0000-0000-000000000005',
   2, '$OWNER_USER', 'On our way, about 20 minutes out.',
   now() - interval '4 hours', false, 1, now() - interval '4 hours'),
  ('c0000000-0000-0000-0000-000000000502', 'b0000000-0000-0000-0000-000000000005',
   1, '$CUSTOMER_USER', 'Great.',
   now() - interval '3 hours', false, 1, now() - interval '4 hours' + interval '5 minutes'),
  ('c0000000-0000-0000-0000-000000000503', 'b0000000-0000-0000-0000-000000000005',
   1, '$CUSTOMER_USER', 'The side gate is open, come straight through.',
   now() - interval '3 hours', false, 1, now() - interval '4 hours' + interval '6 minutes'),
  ('c0000000-0000-0000-0000-000000000504', 'b0000000-0000-0000-0000-000000000005',
   2, '$OWNER_USER', 'Found it, thanks.',
   now() - interval '3 hours', false, 1, now() - interval '3 hours' - interval '30 minutes'),
  ('c0000000-0000-0000-0000-000000000505', 'b0000000-0000-0000-0000-000000000005',
   2, '$OWNER_USER', 'We have started on the kitchen.',
   now() - interval '2 hours', false, 1, now() - interval '3 hours'),
  ('c0000000-0000-0000-0000-000000000506', 'b0000000-0000-0000-0000-000000000005',
   2, '$OWNER_USER', 'Utility will need a second coat — included, no extra charge.',
   null, false, 1, now() - interval '40 minutes');

commit;
" > /dev/null

echo "=== threads the customer will see, newest first ==="
q "select bo.business_name,
          coalesce(v.name, s.name),
          (select count(*) from booking_messages m
            where m.booking_id = b.id and m.sender_role = 2 and m.read_at is null) || ' unread',
          (select case when m.sender_role = 1 then 'You: ' else '' end || m.body
             from booking_messages m where m.booking_id = b.id
            order by m.created_date desc limit 1)
     from bookings b
     join business_owner_profiles bo on bo.id = b.business_owner_profile_id
     join business_services s on s.id = b.business_service_id
     left join business_service_variants v on v.id = b.business_service_variant_id
    where exists (select 1 from booking_messages m where m.booking_id = b.id)
    order by (select max(m.created_date) from booking_messages m where m.booking_id = b.id) desc;"
