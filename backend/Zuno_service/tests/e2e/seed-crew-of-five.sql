-- One order crewed by five, work finished, nobody paid — so the pay run is a real five-line
-- batch rather than a single worker.
--
--   Ravi · Anita · Suresh · Shajil · Test      ₹900 each      ₹4,500 to collect
--
-- Everything is looked up rather than named: the business, its service, its customer and its
-- address come from whatever is already there, and the dates are relative to now(). Re-runnable —
-- it clears its own rows first, payout batches included, since an abandoned checkout leaves
-- batch items pointing at the applications.

begin;

create temporary table five_ctx as
select
    b.id                                                                as business_id,
    (select s.id from business_services s
      where s.business_owner_profile_id = b.id and s.is_deleted = false
      order by s.created_date limit 1)                                  as service_id,
    (select s.price from business_services s
      where s.business_owner_profile_id = b.id and s.is_deleted = false
      order by s.created_date limit 1)                                  as price,
    (select bk.customer_profile_id from bookings bk
      where bk.business_owner_profile_id = b.id
      order by bk.created_date desc limit 1)                            as customer_id,
    (select bk.address_id from bookings bk
      where bk.business_owner_profile_id = b.id
      order by bk.created_date desc limit 1)                            as address_id
from business_owner_profiles b
join users u on u.id = b.user_id
where u.email = 'owner@zuno.local';

-- The five, in the order they will read on the pay sheet.
create temporary table five_crew as
select w.id as worker_id, u.first_name, row_number() over (order by u.first_name) as seat
from worker_profiles w
join users u on u.id = w.user_id
where u.email in ('w1@zuno.local', 'w2@zuno.local', 'w3@zuno.local',
                  'shajil@zuno.local', 'worker@zuno.local');

-- Test Worker was removed from the roster; a crew of five needs all five back on it.
-- assignment_status 2 = Active.
update business_workers bw
   set assignment_status = 2, modified_date = now()
  from five_ctx c, five_crew f
 where bw.business_owner_profile_id = c.business_id
   and bw.worker_profile_id = f.worker_id
   and bw.assignment_status <> 2;

-- ---------------------------------------------------------------------------------------------
-- Clear a previous run of this script
-- ---------------------------------------------------------------------------------------------
delete from payout_batch_items i
 using payout_batches b, hiring_posts p
 where b.id = i.payout_batch_id and p.id = b.hiring_post_id
   and p.title like 'DEMO-FIVE%';

delete from payout_batches b using hiring_posts p
 where p.id = b.hiring_post_id and p.title like 'DEMO-FIVE%';

delete from hiring_post_applications a using hiring_posts p
 where p.id = a.hiring_post_id and p.title like 'DEMO-FIVE%';

delete from hiring_posts where title like 'DEMO-FIVE%';

delete from booking_worker_assignments a using bookings b
 where b.id = a.booking_id and b.notes like 'DEMO-FIVE%';

delete from bookings where notes like 'DEMO-FIVE%';

-- Free the five from other future work, so none of them is mid-job elsewhere.
update booking_worker_assignments a
   set is_deleted = true, modified_date = now()
  from bookings b, five_ctx c, five_crew f
 where b.id = a.booking_id
   and b.business_owner_profile_id = c.business_id
   and b.scheduled_date > now() - interval '1 day'
   and a.worker_profile_id = f.worker_id
   and a.is_deleted = false;

-- ---------------------------------------------------------------------------------------------
-- The order: finished two days ago. booking_status 4 = Completed.
-- ---------------------------------------------------------------------------------------------
create temporary table five_order as
with added as (
    insert into bookings (
        id, customer_profile_id, business_owner_profile_id, business_service_id, address_id,
        booking_status, scheduled_date, notes, price_quoted, required_worker_count,
        work_started_at, completed_at, created_date, is_deleted, status)
    select
        gen_random_uuid(), c.customer_id, c.business_id, c.service_id, c.address_id,
        4,
        now() - interval '2 days',
        'DEMO-FIVE wedding catering · crew of 5',
        coalesce(c.price, 4200) * 3,
        5,
        now() - interval '2 days',
        now() - interval '1 day',
        now(), false, 1
    from five_ctx c
    returning id
)
select * from added;

-- All five worked it. assignment_status 4 = Completed.
insert into booking_worker_assignments (
    id, booking_id, worker_profile_id, assignment_status,
    responded_at, completed_at, created_date, is_deleted, status)
select gen_random_uuid(), o.id, f.worker_id, 4,
       now() - interval '4 days', now() - interval '1 day', now(), false, 1
from five_order o, five_crew f;

-- ---------------------------------------------------------------------------------------------
-- The hiring post that owes them. This is where an in-app wage lives — a worker added straight
-- from the roster is paid offline and appears on no pay run.
-- ---------------------------------------------------------------------------------------------
create temporary table five_post as
with added as (
    insert into hiring_posts (
        id, business_owner_profile_id, booking_id, title, event_date, duration_minutes,
        workers_needed, salary_amount, salary_unit, hiring_post_status, location,
        work_started_at, work_completed_at, created_date, is_deleted, status)
    select gen_random_uuid(), c.business_id, o.id,
           'DEMO-FIVE crew for the wedding',
           now() - interval '2 days', 240,
           5, 900, 1, 2, 'Nila Nagar, Thrissur',
           now() - interval '2 days',
           now() - interval '1 day',
           now(), false, 1
    from five_order o, five_ctx c
    returning id
)
select * from added;

-- Five accepted workers, all still owed. application_status 4 = Accepted, payment_status 1 = Unpaid.
insert into hiring_post_applications (
    id, hiring_post_id, worker_profile_id, application_status,
    responded_at, worker_responded_at, agreed_salary_amount, agreed_salary_unit,
    payment_status, created_date, is_deleted, status)
select gen_random_uuid(), p.id, f.worker_id, 4,
       now() - interval '5 days', now() - interval '5 days',
       900, 1, 1, now(), false, 1
from five_post p, five_crew f;

-- Keep the stored count honest: the same rule the server uses, so a later "+1" is a real change.
update business_owner_profiles p
   set completed_job_count =
       (select count(*) from bookings b
         where b.business_owner_profile_id = p.id
           and b.booking_status = 4
           and not exists (
                 select 1 from hiring_post_applications a
                 join hiring_posts hp on hp.id = a.hiring_post_id
                 where hp.booking_id = b.id
                   and a.application_status = 4 and a.payment_status <> 3))
     + (select count(*) from hiring_posts hp
         where hp.business_owner_profile_id = p.id
           and hp.booking_id is null and hp.work_completed_at is not null
           and exists (select 1 from hiring_post_applications a
                        where a.hiring_post_id = hp.id and a.application_status = 4)
           and not exists (select 1 from hiring_post_applications a
                            where a.hiring_post_id = hp.id
                              and a.application_status = 4 and a.payment_status <> 3))
  from five_ctx c
 where p.id = c.business_id;

commit;

select f.first_name as crew, 900 as owed, d.upi_vpa
from five_crew f
join worker_payout_details d on d.worker_profile_id = f.worker_id
order by f.seat;

select count(*) as crew_size, sum(a.agreed_salary_amount) as to_collect
from hiring_post_applications a
join hiring_posts p on p.id = a.hiring_post_id
where p.title like 'DEMO-FIVE%' and a.payment_status <> 3;

select completed_job_count as counted_now
from business_owner_profiles p join users u on u.id = p.user_id
where u.email = 'owner@zuno.local';
