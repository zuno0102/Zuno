#!/usr/bin/env bash
# Nine bookings for cust@zuno.local, one per state the Bookings tab can be in.
#
# The point is to see every branch of that screen at once: the chip wording, which actions appear,
# and the cases that only show up in combination — a completed order that has been rated against one
# that has not, a cancelled order carrying its reason, an order waiting on the customer to accept the
# business's terms.
#
# Idempotent: fixed ids in the b0000000-/a0000000- range, deleted before being re-inserted.
set -euo pipefail

CUSTOMER='bab6b30d-a972-493a-a771-51bca718fd81'   # cust@zuno.local
CUSTOMER_USER='fe005632-5e9a-4051-9c2f-e60ba5c0bf46'
OWNER_USER='9ab8541b-8fe1-4e9c-b7cb-e75ef27a6309' # owner@zuno.local, Test Owner
WORKER='af3e3b58-4be3-4d49-afd5-27944ee6f180'     # shajil, for the crew rows

# Two businesses, so the list is not one name nine times.
TEST_OWNER='0252ffb3-568f-44b2-a7ef-fc58acedb347'
SHAJIL_BIZ='53c4521a-fa56-4b6c-9a35-bd6cb0389298'

PAINTINGS='0934fd83-9469-4c98-9cb3-c44755796cc3'      # Test Owner, hourly
CATERING='9cddde4c-2ed3-402a-aa1c-9887886c4723'       # Test Owner, per person
BAHHS='394e53a4-4354-4e61-9462-12621274a001'          # Test Owner, per person
PAINT_SECTOR='0266c09d-512f-463c-afd4-758ca438349f'   # shajil shajil, fixed

PSQL="${PSQL:-psql}"
SECRETS="C:/Users/TLTuser/AppData/Roaming/Microsoft/UserSecrets/4e5c30fb-10fa-4613-a907-38ad9e1b98d5/secrets.json"
PGPASSWORD=$(grep -o '"ConnectionStrings:ZunoDatabase": "[^"]*"' "$SECRETS" | grep -o 'Password=[^;"]*' | cut -d= -f2)
export PGPASSWORD

q() { "$PSQL" -h 127.0.0.1 -U postgres -d "${ZUNO_DB:-zuno}" -At -F' | ' -c "$1"; }

# booking_status: 1 Pending, 2 Assigned, 3 InProgress, 4 Completed, 5 Cancelled, 6 Confirmed
# price_type:     1 Fixed, 2 Hourly, 3 Daily, 4 PerPerson
# assignment:     1 Assigned, 2 Accepted, 3 Rejected, 4 Completed
# payment:        1 Unpaid, 2 Processing, 3 Paid, 4 Failed, 5 Disputed, 6 AwaitingWorkerConfirmation
q "
begin;

delete from ratings                     where booking_id::text like 'b0000000-0000-0000-0000-%';
delete from booking_agreement_proposals where booking_id::text like 'b0000000-0000-0000-0000-%';
delete from booking_worker_assignments  where booking_id::text like 'b0000000-0000-0000-0000-%';
delete from bookings                    where id::text        like 'b0000000-0000-0000-0000-%';
delete from addresses                   where id::text        like 'a0000000-0000-0000-0000-%';

insert into addresses (id, owner_user_id, line1, city, state, postal_code, country, is_default, is_deleted, status, created_date)
select ('a0000000-0000-0000-0000-' || lpad(i::text, 12, '0'))::uuid,
       '$CUSTOMER_USER',
       (array['12 Main Road','44 Beach Road','7 Temple Street','221 MG Road','9 Lake View',
              '88 Hill Street','3 Market Lane','56 Garden Road','14 Station Road'])[i],
       'Thiruvananthapuram', 'Kerala', '695001', 'India', false, false, 1, now()
from generate_series(1, 9) as i;

insert into bookings
  (id, customer_profile_id, business_owner_profile_id, business_service_id, address_id,
   booking_status, scheduled_date, notes, price_quoted, price_type, required_worker_count,
   work_started_at, completed_at, cancelled_at, cancellation_reason,
   is_deleted, status, created_date)
values
  -- 1. Just placed. Waiting on the business; the customer can still cancel, and cannot call yet.
  ('b0000000-0000-0000-0000-000000000001', '$CUSTOMER', '$TEST_OWNER', '$PAINTINGS',
   'a0000000-0000-0000-0000-000000000001', 1, now() + interval '9 days',
   'Two bedrooms and the hall.', 4500, 1, 2, null, null, null, null, false, 1, now() - interval '2 hours'),

  -- 2. The business has countered with a crew size and price. The ball is with the customer.
  ('b0000000-0000-0000-0000-000000000002', '$CUSTOMER', '$TEST_OWNER', '$CATERING',
   'a0000000-0000-0000-0000-000000000002', 1, now() + interval '20 days',
   'Reception for about 150 guests.', 67500, 4, 6, null, null, null, null, false, 1, now() - interval '1 day'),

  -- 3. Agreed and confirmed, still weeks away.
  ('b0000000-0000-0000-0000-000000000003', '$CUSTOMER', '$SHAJIL_BIZ', '$PAINT_SECTOR',
   'a0000000-0000-0000-0000-000000000003', 6, now() + interval '14 days',
   'Exterior, two coats.', 15000, 1, 3, null, null, null, null, false, 1, now() - interval '3 days'),

  -- 4. Crew named, and the day is tomorrow.
  ('b0000000-0000-0000-0000-000000000004', '$CUSTOMER', '$TEST_OWNER', '$BAHHS',
   'a0000000-0000-0000-0000-000000000004', 2, now() + interval '1 day',
   'Lighting for the function.', 12500, 4, 4, null, null, null, null, false, 1, now() - interval '5 days'),

  -- 5. Happening now: the crew has started and nobody has closed it.
  ('b0000000-0000-0000-0000-000000000005', '$CUSTOMER', '$TEST_OWNER', '$PAINTINGS',
   'a0000000-0000-0000-0000-000000000005', 3, now() - interval '3 hours',
   'Kitchen and utility.', 3800, 2, 2, now() - interval '3 hours', null, null, null, false, 1, now() - interval '8 days'),

  -- 6. Finished and rated. The rating row below is what makes this one different from 7.
  ('b0000000-0000-0000-0000-000000000006', '$CUSTOMER', '$SHAJIL_BIZ', '$PAINT_SECTOR',
   'a0000000-0000-0000-0000-000000000006', 4, now() - interval '12 days',
   'Single room, white.', 9000, 1, 2, now() - interval '12 days', now() - interval '12 days',
   null, null, false, 1, now() - interval '20 days'),

  -- 7. Finished, not rated. This is the one that should still offer to rate it.
  ('b0000000-0000-0000-0000-000000000007', '$CUSTOMER', '$TEST_OWNER', '$CATERING',
   'a0000000-0000-0000-0000-000000000007', 4, now() - interval '5 days',
   'Birthday lunch, 40 people.', 18000, 4, 3, now() - interval '5 days', now() - interval '5 days',
   null, null, false, 1, now() - interval '15 days'),

  -- 8. Called off by the customer, with the reason they gave.
  ('b0000000-0000-0000-0000-000000000008', '$CUSTOMER', '$TEST_OWNER', '$BAHHS',
   'a0000000-0000-0000-0000-000000000008', 5, now() + interval '4 days',
   null, 7500, 4, 2, null, null, now() - interval '2 days',
   'Function postponed to next month.', false, 1, now() - interval '9 days'),

  -- 9. Finished a while ago and the crew is still owed. Reads as Completed to the customer, who was
  --    never party to the wage; the business is the one carrying it.
  ('b0000000-0000-0000-0000-000000000009', '$CUSTOMER', '$TEST_OWNER', '$PAINTINGS',
   'a0000000-0000-0000-0000-000000000009', 4, now() - interval '30 days',
   'Whole flat before moving in.', 22000, 1, 4, now() - interval '30 days', now() - interval '29 days',
   null, null, false, 1, now() - interval '40 days');

-- The business's offer on booking 2, still open, which is what the customer has to answer.
insert into booking_agreement_proposals
  (id, booking_id, proposed_by_role, proposed_by_user_id, worker_count, price, message,
   proposal_status, is_deleted, status, created_date)
values
  ('b0000000-0000-0000-0000-00000000f002', 'b0000000-0000-0000-0000-000000000002',
   2, '$OWNER_USER', 6, 67500,
   'Six of us for a 150-guest reception, including service staff.', 1, false, 1, now() - interval '20 hours');

-- Crew on the orders far enough along to have any.
insert into booking_worker_assignments
  (id, booking_id, worker_profile_id, role, assignment_status, agreed_salary_amount,
   agreed_salary_unit, payment_status, is_deleted, status, created_date)
values
  ('b0000000-0000-0000-0000-00000000e004', 'b0000000-0000-0000-0000-000000000004',
   '$WORKER', 'Lighting assistant', 1, 900, 1, 1, false, 1, now() - interval '4 days'),
  ('b0000000-0000-0000-0000-00000000e005', 'b0000000-0000-0000-0000-000000000005',
   '$WORKER', 'Painter', 2, 1200, 1, 1, false, 1, now() - interval '7 days'),
  ('b0000000-0000-0000-0000-00000000e007', 'b0000000-0000-0000-0000-000000000007',
   '$WORKER', 'Service staff', 4, 800, 1, 3, false, 1, now() - interval '14 days'),
  ('b0000000-0000-0000-0000-00000000e009', 'b0000000-0000-0000-0000-000000000009',
   '$WORKER', 'Painter', 4, 1500, 1, 1, false, 1, now() - interval '38 days');

-- The rating that makes booking 6 the already-rated one.
insert into ratings
  (id, booking_id, customer_profile_id, business_owner_profile_id, score, comment,
   is_deleted, status, created_date)
values
  ('b0000000-0000-0000-0000-00000000d006', 'b0000000-0000-0000-0000-000000000006',
   '$CUSTOMER', '$SHAJIL_BIZ', 5, 'Neat work and finished a day early.', false, 1, now() - interval '11 days');

commit;
" > /dev/null

echo "=== what the Bookings tab will show ==="
q "select case b.booking_status
            when 1 then 'Pending' when 2 then 'Assigned' when 3 then 'InProgress'
            when 4 then 'Completed' when 5 then 'Cancelled' when 6 then 'Confirmed' end,
          coalesce(v.name, s.name),
          bo.business_name,
          b.scheduled_date::date,
          case when r.id is not null then 'rated ' || r.score else '' end ||
          case when p.id is not null then 'offer to answer' else '' end ||
          case when b.cancellation_reason is not null then 'has a reason' else '' end
     from bookings b
     join business_services s on s.id = b.business_service_id
     left join business_service_variants v on v.id = b.business_service_variant_id
     join business_owner_profiles bo on bo.id = b.business_owner_profile_id
     left join ratings r on r.booking_id = b.id
     left join booking_agreement_proposals p on p.booking_id = b.id and p.proposal_status = 1
    where b.customer_profile_id = '$CUSTOMER' and not b.is_deleted
    order by b.created_date desc;"
