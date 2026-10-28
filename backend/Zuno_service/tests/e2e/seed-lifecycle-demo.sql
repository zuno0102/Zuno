-- Four orders on the Test Owner account, one parked at each step of the chain, so the whole
-- lifecycle can be walked in the app:
--
--   A  Ready to start      Confirmed, its hour has come, crew accepted   -> [Start work]
--   B  Ready to complete   Work under way                                -> [Mark completed]
--   C  Ready to pay        Work done, two crew owed through a hire post  -> [Pay crew]
--   D  Already settled     Finished and paid                            -> counted, nothing to do
--
-- Nothing is hardcoded: the business, its service, its customer and its address are looked up
-- from whatever is already there, and every date is relative to now(), so this stays valid
-- whenever it runs. Re-runnable — it clears its own previous rows first.
--
-- One worker per order. A worker mid-job takes nothing else until that job is closed, so sharing
-- one between B and C would make the seed contradict its own rule.

begin;

-- ---------------------------------------------------------------------------------------------
-- What we are working with
-- ---------------------------------------------------------------------------------------------
create temporary table demo_ctx as
select
    b.id                                                                    as business_id,
    (select s.id from business_services s
      where s.business_owner_profile_id = b.id and s.is_deleted = false
      order by s.created_date limit 1)                                      as service_id,
    (select s.price from business_services s
      where s.business_owner_profile_id = b.id and s.is_deleted = false
      order by s.created_date limit 1)                                      as price,
    (select bk.customer_profile_id from bookings bk
      where bk.business_owner_profile_id = b.id
      order by bk.created_date desc limit 1)                                as customer_id,
    (select bk.address_id from bookings bk
      where bk.business_owner_profile_id = b.id
      order by bk.created_date desc limit 1)                                as address_id
from business_owner_profiles b
join users u on u.id = b.user_id
where u.email = 'owner@zuno.local';

create temporary table demo_workers as
select
    (select w.id from worker_profiles w join users u on u.id = w.user_id
      where u.email = 'w1@zuno.local')      as ravi,
    (select w.id from worker_profiles w join users u on u.id = w.user_id
      where u.email = 'w2@zuno.local')      as anita,
    (select w.id from worker_profiles w join users u on u.id = w.user_id
      where u.email = 'w3@zuno.local')      as suresh,
    (select w.id from worker_profiles w join users u on u.id = w.user_id
      where u.email = 'shajil@zuno.local')  as shajil;

-- ---------------------------------------------------------------------------------------------
-- Start from a known state: drop anything an earlier run of this script left behind
-- ---------------------------------------------------------------------------------------------
-- Pay runs first: opening one and then abandoning it — a checkout that never completed — leaves
-- batch items pointing at the applications below, and the delete fails on the foreign key.
delete from payout_batch_items i
 using payout_batches b, hiring_posts p
 where b.id = i.payout_batch_id
   and p.id = b.hiring_post_id
   and p.title like 'DEMO-LIFECYCLE%';

delete from payout_batches b
 using hiring_posts p
 where p.id = b.hiring_post_id
   and p.title like 'DEMO-LIFECYCLE%';

delete from hiring_post_applications a
 using hiring_posts p
 where p.id = a.hiring_post_id
   and p.title like 'DEMO-LIFECYCLE%';

delete from hiring_posts where title like 'DEMO-LIFECYCLE%';

delete from booking_worker_assignments a
 using bookings b
 where b.id = a.booking_id
   and b.notes like 'DEMO-LIFECYCLE%';

delete from bookings where notes like 'DEMO-LIFECYCLE%';

-- ...and release these four workers from any other future job, so each demo order has someone
-- who can actually be put on it.
update booking_worker_assignments a
   set is_deleted = true, modified_date = now()
  from bookings b, demo_ctx c, demo_workers w
 where b.id = a.booking_id
   and b.business_owner_profile_id = c.business_id
   and b.scheduled_date > now() - interval '1 day'
   and a.worker_profile_id in (w.ravi, w.anita, w.suresh, w.shajil)
   and a.is_deleted = false;

-- ---------------------------------------------------------------------------------------------
-- The four orders. booking_status: 4 = Completed, 3 = InProgress, 6 = Confirmed
-- ---------------------------------------------------------------------------------------------
create temporary table demo_orders as
with rows_to_add(label, status, starts_in, started_ago, finished_ago) as (
    values
        ('A · ready to start',    6, interval '-1 hour',  null::interval,        null::interval),
        ('B · ready to complete', 3, interval '-3 hours', interval '2 hours',    null::interval),
        ('C · ready to pay',      4, interval '-2 days',  interval '2 days',     interval '1 day'),
        ('D · already settled',   4, interval '-9 days',  interval '9 days',     interval '8 days')
),
-- Wrapped in a CTE: an INSERT cannot be the direct source of CREATE TABLE AS.
added as (
    insert into bookings (
        id, customer_profile_id, business_owner_profile_id, business_service_id, address_id,
        booking_status, scheduled_date, notes, price_quoted, required_worker_count,
        work_started_at, completed_at, created_date, is_deleted, status)
    select
        gen_random_uuid(), c.customer_id, c.business_id, c.service_id, c.address_id,
        r.status,
        now() + r.starts_in,
        'DEMO-LIFECYCLE ' || r.label,
        coalesce(c.price, 4200),
        1,
        case when r.started_ago  is null then null else now() - r.started_ago  end,
        case when r.finished_ago is null then null else now() - r.finished_ago end,
        now(), false, 1
    from rows_to_add r, demo_ctx c
    returning id, notes, booking_status
)
select * from added;

-- ---------------------------------------------------------------------------------------------
-- Crew. assignment_status: 2 = Accepted, 4 = Completed
-- ---------------------------------------------------------------------------------------------
insert into booking_worker_assignments (
    id, booking_id, worker_profile_id, assignment_status,
    responded_at, completed_at, created_date, is_deleted, status)
select
    gen_random_uuid(),
    o.id,
    case
        when o.notes like '%A ·%' then w.ravi
        when o.notes like '%B ·%' then w.anita
        when o.notes like '%C ·%' then w.suresh
        else w.shajil
    end,
    -- The crew is finished exactly where the order is.
    case when o.booking_status = 4 then 4 else 2 end,
    now() - interval '3 days',
    case when o.booking_status = 4 then now() - interval '1 day' else null end,
    now(), false, 1
from demo_orders o, demo_workers w;

-- ---------------------------------------------------------------------------------------------
-- Wages. C is owed; D was paid. Both go through a hiring post, because that is the only place
-- an in-app wage can live — a worker added straight from the roster is paid offline.
--
-- hiring_post_status 1 = Open, application_status 4 = Accepted,
-- payment_status 1 = Unpaid, 3 = Paid, salary_unit 1 = PerEvent
-- ---------------------------------------------------------------------------------------------
create temporary table demo_posts as
with added as (
    insert into hiring_posts (
        id, business_owner_profile_id, booking_id, title, event_date, duration_minutes,
        workers_needed, salary_amount, salary_unit, hiring_post_status, location,
        work_started_at, work_completed_at, created_date, is_deleted, status)
    select
        gen_random_uuid(), c.business_id, o.id,
        'DEMO-LIFECYCLE crew for ' || substring(o.notes from 'DEMO-LIFECYCLE (.*)'),
        now() - interval '2 days', 180,
        1, 900, 1, 1, 'Nila Nagar, Thrissur',
        now() - interval '2 days',
        now() - interval '1 day',
        now(), false, 1
    from demo_orders o, demo_ctx c
    where o.notes like '%C ·%' or o.notes like '%D ·%'
    returning id, title, booking_id
)
select * from added;

insert into hiring_post_applications (
    id, hiring_post_id, worker_profile_id, application_status,
    responded_at, worker_responded_at, agreed_salary_amount, agreed_salary_unit,
    payment_status, paid_at, created_date, is_deleted, status)
select
    gen_random_uuid(), p.id,
    case when p.title like '%C ·%' then w.suresh else w.shajil end,
    4,
    now() - interval '4 days', now() - interval '4 days',
    900, 1,
    -- C is still owed; D was paid, which is what makes D count and C not.
    case when p.title like '%C ·%' then 1 else 3 end,
    case when p.title like '%C ·%' then null else now() - interval '12 hours' end,
    now(), false, 1
from demo_posts p, demo_workers w;

-- D is fully settled, so stamp the moment it closed out.
update hiring_posts set settled_at = now() - interval '12 hours'
 where title like 'DEMO-LIFECYCLE%' and title like '%D ·%';

-- ---------------------------------------------------------------------------------------------
-- Bring the stored count in line with the rule, so the "+1" on screen is a real change rather
-- than a figure catching up. Same rule the server uses: an order counts when it is finished and
-- owes nobody; a hiring post counts on its own only when it has no order.
-- ---------------------------------------------------------------------------------------------
update business_owner_profiles p
   set completed_job_count =
       (select count(*) from bookings b
         where b.business_owner_profile_id = p.id
           and b.booking_status = 4
           and not exists (
                 select 1 from hiring_post_applications a
                 join hiring_posts hp on hp.id = a.hiring_post_id
                 where hp.booking_id = b.id
                   and a.application_status = 4
                   and a.payment_status <> 3))
     + (select count(*) from hiring_posts hp
         where hp.business_owner_profile_id = p.id
           and hp.booking_id is null
           and hp.work_completed_at is not null
           and exists (select 1 from hiring_post_applications a
                        where a.hiring_post_id = hp.id and a.application_status = 4)
           and not exists (select 1 from hiring_post_applications a
                            where a.hiring_post_id = hp.id
                              and a.application_status = 4
                              and a.payment_status <> 3))
  from demo_ctx c
 where p.id = c.business_id;

commit;

-- ---------------------------------------------------------------------------------------------
-- What to expect on screen
-- ---------------------------------------------------------------------------------------------
select
    substring(b.notes from 'DEMO-LIFECYCLE (.*)')        as order_card,
    b.booking_status                                     as status_code,
    to_char(b.scheduled_date, 'DD Mon HH24:MI')          as scheduled,
    u.first_name                                         as crew,
    coalesce(sum(a.agreed_salary_amount) filter
        (where a.payment_status <> 3), 0)                as still_owed,
    case
        when b.booking_status = 6 then 'tap Start work'
        when b.booking_status = 3 then 'tap Mark completed'
        when coalesce(sum(a.agreed_salary_amount) filter
             (where a.payment_status <> 3), 0) > 0 then 'tap Pay crew'
        else 'nothing — already counted'
    end                                                  as next_step
from bookings b
join booking_worker_assignments bw on bw.booking_id = b.id and bw.is_deleted = false
join worker_profiles w on w.id = bw.worker_profile_id
join users u on u.id = w.user_id
left join hiring_posts hp on hp.booking_id = b.id
left join hiring_post_applications a on a.hiring_post_id = hp.id and a.application_status = 4
where b.notes like 'DEMO-LIFECYCLE%'
group by b.id, b.notes, b.booking_status, b.scheduled_date, u.first_name
order by 1;

select completed_job_count as counted_now, level
from business_owner_profiles p
join users u on u.id = p.user_id
where u.email = 'owner@zuno.local';
