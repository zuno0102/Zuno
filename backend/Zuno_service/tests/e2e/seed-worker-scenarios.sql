-- Puts the four worker-availability scenarios onto the Test Owner account, so every case on the
-- Workers tab can be seen in the app:
--
--   Ravi Kumar   two jobs on ONE date          -> Booked; schedule shows one heading, two rows
--   Anita Menon  jobs on THREE different dates -> Booked; schedule shows three headings
--   Suresh Nair  hired through a HIRING POST   -> Booked; the case that used to read as free
--   Shajil S     nothing at all                -> Free; schedule empty
--
-- Nothing is hardcoded: the business, its service, its customer and its address are all looked
-- up from whatever is already there, and every date is relative to now(), so this stays valid
-- whenever it is run. Times are spaced well past the 30-minute travel rule, so each row is one
-- the app's own clash check would have allowed.
--
-- Re-runnable: it clears these four workers' future work for this business first.

begin;

with ctx as (
    select
        b.id                as business_id,
        (select s.id from business_services s
          where s.business_owner_profile_id = b.id and s.is_deleted = false
          order by s.created_date limit 1)                                as service_id,
        (select bk.customer_profile_id from bookings bk
          where bk.business_owner_profile_id = b.id
          order by bk.created_date desc limit 1)                          as customer_id,
        (select bk.address_id from bookings bk
          where bk.business_owner_profile_id = b.id
          order by bk.created_date desc limit 1)                          as address_id,
        (select s.price from business_services s
          where s.business_owner_profile_id = b.id and s.is_deleted = false
          order by s.created_date limit 1)                                as price
    from business_owner_profiles b
    join users u on u.id = b.user_id
    where u.email = 'owner@zuno.local'
),
workers as (
    select
        (select w.id from worker_profiles w join users u on u.id = w.user_id
          where u.email = 'w1@zuno.local')      as ravi,
        (select w.id from worker_profiles w join users u on u.id = w.user_id
          where u.email = 'w2@zuno.local')      as anita,
        (select w.id from worker_profiles w join users u on u.id = w.user_id
          where u.email = 'w3@zuno.local')      as suresh,
        (select w.id from worker_profiles w join users u on u.id = w.user_id
          where u.email = 'shajil@zuno.local')  as shajil
),
-- Start from a known state rather than stacking on a previous run.
cleared as (
    update booking_worker_assignments a
       set is_deleted = true, modified_date = now()
      from bookings bk, ctx, workers w
     where bk.id = a.booking_id
       and bk.business_owner_profile_id = ctx.business_id
       and bk.scheduled_date > now()
       and a.worker_profile_id in (w.ravi, w.anita, w.suresh, w.shajil)
       and a.is_deleted = false
    returning a.id
),
-- The jobs themselves. booking_status 6 = Confirmed, which is what the business sees after
-- accepting an order.
slots(label, worker_email, starts_in) as (
    values
        ('Ravi morning',   'w1@zuno.local',     interval '7 days  9 hours'),
        ('Ravi afternoon', 'w1@zuno.local',     interval '7 days 16 hours'),
        ('Anita first',    'w2@zuno.local',     interval '3 days 10 hours'),
        ('Anita second',   'w2@zuno.local',     interval '9 days 11 hours'),
        ('Anita third',    'w2@zuno.local',     interval '15 days 8 hours')
),
new_bookings as (
    insert into bookings (
        id, customer_profile_id, business_owner_profile_id, business_service_id, address_id,
        booking_status, scheduled_date, notes, price_quoted, required_worker_count,
        created_date, is_deleted, status)
    select
        gen_random_uuid(), ctx.customer_id, ctx.business_id, ctx.service_id, ctx.address_id,
        6,
        date_trunc('day', now()) + s.starts_in,
        'SCENARIO-SEED ' || s.label,
        coalesce(ctx.price, 2500),
        1,
        now(), false, 1
    from slots s, ctx
    returning id, notes, scheduled_date
)
-- assignment_status 2 = Accepted: the worker has said yes and is genuinely holding the slot.
insert into booking_worker_assignments (
    id, booking_id, worker_profile_id, assignment_status,
    responded_at, created_date, is_deleted, status)
select
    gen_random_uuid(),
    nb.id,
    (select w.id from worker_profiles w join users u on u.id = w.user_id
      where u.email = s.worker_email),
    2, now(), now(), false, 1
from new_bookings nb
join slots s on nb.notes = 'SCENARIO-SEED ' || s.label;

commit;

-- What the app will now show, per worker.
select
    u.first_name || ' ' || u.last_name              as worker,
    count(a.id)                                     as live_jobs,
    count(distinct date(b.scheduled_date))          as distinct_dates,
    coalesce(min(b.scheduled_date)::text, '-')      as first_job
from worker_profiles w
join users u on u.id = w.user_id
left join booking_worker_assignments a
       on a.worker_profile_id = w.id
      and a.is_deleted = false
      and a.assignment_status in (1, 2)
left join bookings b
       on b.id = a.booking_id
      and b.completed_at is null
      and b.booking_status <> 5
      and b.scheduled_date > now()
where u.email in ('w1@zuno.local', 'w2@zuno.local', 'w3@zuno.local', 'shajil@zuno.local')
group by u.first_name, u.last_name
order by 2 desc;
