-- Fills an EMPTY, migrated database with production-sized dummy data, for performance tests.
--
-- NEVER run against a real database: it inserts hundreds of thousands of fake accounts.
-- Usage (from backend/Zuno_service/tests/perf):
--   psql -h 127.0.0.1 -U postgres -d zuno_perf -v scale=1 -v pwhash="'<bcrypt hash>'" -f seed-volume.sql
-- scale=1 gives ~200k users and ~1M orders; scale=0.1 a tenth of that for a quick run.
-- Every account's password is the one the hash was made from. Ids are derived from a counter, so a
-- rerun on a fresh database gives the same rows.

\set ON_ERROR_STOP on
\timing on

select current_database() as db \gset
\if :{?scale}
\else
  \set scale 1
\endif

-- Refuse to touch the real databases by name.
select (:'db' in ('zuno', 'zuno_prod', 'postgres')) as forbidden \gset
\if :forbidden
  \echo 'Refusing to fill' :'db' '- use a scratch database such as zuno_perf.'
  \quit
\endif

create temporary table n as
select
  greatest(1, (120000 * :scale)::bigint) as customers,
  greatest(1, (70000 * :scale)::bigint) as workers,
  greatest(1, (10000 * :scale)::bigint) as businesses,
  greatest(1, (1000000 * :scale)::bigint) as bookings,
  greatest(1, (100000 * :scale)::bigint) as posts,
  greatest(1, (10000 * :scale)::bigint) as vacancies,
  greatest(1, (2000000 * :scale)::bigint) as notifications;

create temporary table districts_with_centre as
select row_number() over (order by id) as rn, id, centre_latitude as lat, centre_longitude as lon
from districts where centre_latitude is not null;
select count(*) as district_count from districts_with_centre \gset

create temporary table cats as
select row_number() over (order by id) as rn, id from service_categories where is_deleted = false;
select count(*) as cat_count from cats \gset

-- ---- Users and profiles ------------------------------------------------------------------------

insert into users (id, email, phone_number, password_hash, first_name, last_name, role_id,
                   email_confirmed, phone_number_confirmed, is_active, failed_login_attempts,
                   created_date, is_deleted, status)
select md5('user-c-' || i)::uuid, 'perf_c' || i || '@zuno.local', '6' || lpad(i::text, 9, '0'),
       :pwhash, 'Cust', 'P' || i, '11111111-1111-1111-1111-111111111111',
       true, false, true, 0, now() - (i % 700) * interval '1 day', false, 1
from generate_series(1, (select customers from n)) i;

insert into users (id, email, phone_number, password_hash, first_name, last_name, role_id,
                   email_confirmed, phone_number_confirmed, is_active, failed_login_attempts,
                   created_date, is_deleted, status)
select md5('user-w-' || i)::uuid, 'perf_w' || i || '@zuno.local', '7' || lpad(i::text, 9, '0'),
       :pwhash, 'Work', 'P' || i, '33333333-3333-3333-3333-333333333333',
       true, false, true, 0, now() - (i % 700) * interval '1 day', false, 1
from generate_series(1, (select workers from n)) i;

insert into users (id, email, phone_number, password_hash, first_name, last_name, role_id,
                   email_confirmed, phone_number_confirmed, is_active, failed_login_attempts,
                   created_date, is_deleted, status)
select md5('user-b-' || i)::uuid, 'perf_b' || i || '@zuno.local', '8' || lpad(i::text, 9, '0'),
       :pwhash, 'Boss', 'P' || i, '22222222-2222-2222-2222-222222222222',
       true, false, true, 0, now() - (i % 700) * interval '1 day', false, 1
from generate_series(1, (select businesses from n)) i;

insert into addresses (id, owner_user_id, label, line1, city, state, postal_code, country,
                       latitude, longitude, is_default, created_date, is_deleted, status)
select md5('addr-' || i)::uuid, md5('user-c-' || i)::uuid, 'Home', i || ' Main road', 'City', 'Tamil Nadu',
       '600001', 'India', d.lat + ((i % 50) - 25) * 0.002, d.lon + ((i % 40) - 20) * 0.002, true,
       now(), false, 1
from generate_series(1, (select customers from n)) i
join districts_with_centre d on d.rn = 1 + (i % :district_count);

insert into customer_profiles (id, user_id, default_address_id, preferred_language, created_date, is_deleted, status)
select md5('cust-' || i)::uuid, md5('user-c-' || i)::uuid, md5('addr-' || i)::uuid, 'en', now(), false, 1
from generate_series(1, (select customers from n)) i;

insert into worker_profiles (id, user_id, experience_years, hourly_rate, availability_status,
                             verification_status, current_latitude, current_longitude,
                             created_date, is_deleted, status)
select md5('wp-' || i)::uuid, md5('user-w-' || i)::uuid, (i % 15)::smallint, 150 + (i % 300),
       1 + (i % 3), (i % 5 = 0)::int, d.lat, d.lon, now(), false, 1
from generate_series(1, (select workers from n)) i
join districts_with_centre d on d.rn = 1 + (i % :district_count);

insert into business_owner_profiles (id, user_id, business_name, verification_status, verified_at,
                                     completed_job_count, level, open_dispute_count,
                                     customer_review_count, worker_review_count,
                                     created_date, is_deleted, status)
select md5('bp-' || i)::uuid, md5('user-b-' || i)::uuid, 'Perf Business ' || i, 1, now(),
       i % 120, 1 + (i % 5), 0, 0, 0, now(), false, 1
from generate_series(1, (select businesses from n)) i;

-- Three services each, offered in two districts.
insert into business_services (id, business_owner_profile_id, service_category_id, name, price_type,
                               price, estimated_duration_minutes, is_active, required_worker_count,
                               created_date, is_deleted, status)
select md5('svc-' || i || '-' || s)::uuid, md5('bp-' || i)::uuid, c.id, 'Service ' || s || ' of ' || i,
       1, 500 + (i % 50) * 100, 120, true, 1 + (s % 3), now(), false, 1
from generate_series(1, (select businesses from n)) i
cross join generate_series(1, 3) s
join cats c on c.rn = 1 + ((i + s) % :cat_count);

insert into business_service_districts (id, business_service_id, district_id, created_date, is_deleted, status)
select md5('bsd-' || i || '-' || s || '-' || k)::uuid, md5('svc-' || i || '-' || s)::uuid, d.id, now(), false, 1
from generate_series(1, (select businesses from n)) i
cross join generate_series(1, 3) s
cross join generate_series(0, 1) k
join districts_with_centre d on d.rn = 1 + ((i + k * 7) % :district_count);

-- Ten workers on each business's roster.
insert into business_workers (id, business_owner_profile_id, worker_profile_id, assignment_status,
                              invited_at, responded_at, created_date, is_deleted, status)
select md5('bw-' || i || '-' || k)::uuid, md5('bp-' || i)::uuid,
       md5('wp-' || (1 + (i * 10 + k) % (select workers from n)))::uuid, 2, now(), now(), now(), false, 1
from generate_series(1, (select businesses from n)) i
cross join generate_series(0, 9) k
on conflict do nothing;

-- ---- Orders and their crews --------------------------------------------------------------------

-- Spread over the last year and the next two months; the mix of states real traffic would leave.
insert into bookings (id, customer_profile_id, business_owner_profile_id, business_service_id, address_id,
                      booking_status, scheduled_date, price_quoted, completed_at, cancelled_at,
                      required_worker_count, price_type, created_date, is_deleted, status)
select md5('bk-' || i)::uuid,
       md5('cust-' || c)::uuid,
       md5('bp-' || b)::uuid,
       md5('svc-' || b || '-' || (1 + i % 3))::uuid,
       md5('addr-' || c)::uuid,
       st, sched, 500 + (i % 50) * 100,
       case when st = 4 then sched + interval '3 hours' end,
       case when st = 5 then sched - interval '1 day' end,
       1 + (i % 3), 1, sched - interval '5 days', false, 1
from (
  select i,
         1 + (i * 7919) % (select customers from n) as c,
         1 + (i * 104729) % (select businesses from n) as b,
         now() - interval '365 days' + (i % 425) * interval '1 day' + (i % 12) * interval '1 hour' as sched,
         case when i % 425 < 365 then (array[4,4,4,4,5,4,4,4,6,4])[1 + i % 10]
              else (array[1,6,6,2,1])[1 + i % 5] end as st
  from generate_series(1, (select bookings from n)) i
) x;

insert into booking_worker_assignments (id, booking_id, worker_profile_id, assignment_status, responded_at,
                                        completed_at, agreed_salary_amount, agreed_salary_unit, payment_status,
                                        created_date, is_deleted, status)
select md5('bwa-' || i || '-' || k)::uuid, md5('bk-' || i)::uuid,
       md5('wp-' || (1 + (i * 31 + k * 977) % (select workers from n)))::uuid,
       case when i % 425 < 365 then 4 else 2 end, now(),
       case when i % 425 < 365 then now() end,
       700, 1, case when i % 425 < 365 then 3 else 1 end, now(), false, 1
from generate_series(1, (select bookings from n)) i
cross join generate_series(1, 1 + (i % 2)) k
where (array[4,4,4,4,5,4,4,4,6,4])[1 + i % 10] <> 5 or i % 425 >= 365;

-- ---- Hiring posts and applications -------------------------------------------------------------

insert into hiring_posts (id, business_owner_profile_id, title, event_date, location, workers_needed,
                          hiring_post_status, salary_amount, salary_unit, duration_minutes,
                          district_id, latitude, longitude, location_precision, work_completed_at,
                          created_date, is_deleted, status)
select md5('hp-' || i)::uuid, md5('bp-' || (1 + i % (select businesses from n)))::uuid, 'Perf post ' || i,
       ev, 'Venue ' || i, 1 + i % 5, case when ev < now() then 2 else 1 end, 600 + (i % 20) * 50, 1, 180,
       d.id, d.lat + ((i % 30) - 15) * 0.003, d.lon + ((i % 30) - 15) * 0.003, 3,
       case when ev < now() then ev + interval '3 hours' end, ev - interval '7 days', false, 1
from (
  select i, now() - interval '300 days' + (i % 360) * interval '1 day' as ev
  from generate_series(1, (select posts from n)) i
) x
join districts_with_centre d on d.rn = 1 + (i % :district_count);

insert into hiring_post_applications (id, hiring_post_id, worker_profile_id, application_status, responded_at,
                                      agreed_salary_amount, agreed_salary_unit, payment_status,
                                      created_date, is_deleted, status)
select md5('hpa-' || i || '-' || k)::uuid, md5('hp-' || i)::uuid,
       md5('wp-' || (1 + (i * 13 + k * 4099) % (select workers from n)))::uuid,
       (array[1,4,4,3,5])[k], now(), 650, 1, case when k in (2, 3) then 3 else 1 end, now(), false, 1
from generate_series(1, (select posts from n)) i
cross join generate_series(1, 5) k;

-- ---- Full-time jobs ------------------------------------------------------------------------------

insert into vacancies (id, business_owner_profile_id, title, vacancy_job_type_id, openings, salary_min,
                       salary_max, pay_period, working_days_per_week, location, district_id, latitude,
                       longitude, location_precision, vacancy_status, fee_amount, fee_listing_days,
                       paid_count, published_at, expires_at, created_date, is_deleted, status)
select md5('vac-' || i)::uuid, md5('bp-' || (1 + i % (select businesses from n)))::uuid, 'Perf vacancy ' || i,
       (select id from vacancy_job_types order by id limit 1), 1 + i % 5, 12000, 18000, 3, 6, 'Shop ' || i,
       d.id, d.lat, d.lon, 3, (array[2,2,2,3,1])[1 + i % 5], 49, 30, 1,
       now() - (i % 25) * interval '1 day', now() + (30 - i % 25) * interval '1 day', now(), false, 1
from generate_series(1, (select vacancies from n)) i
join districts_with_centre d on d.rn = 1 + (i % :district_count);

insert into vacancy_applications (id, vacancy_id, worker_profile_id, application_status, status_changed_at,
                                  created_date, is_deleted, status)
select md5('va-' || i || '-' || k)::uuid, md5('vac-' || i)::uuid,
       md5('wp-' || (1 + (i * 17 + k * 6151) % (select workers from n)))::uuid,
       (array[1,5,2,3,4])[1 + k % 5], now(), now(), false, 1
from generate_series(1, (select vacancies from n)) i
cross join generate_series(1, 20) k;

-- ---- Notifications ------------------------------------------------------------------------------

insert into notifications (id, user_id, kind, title, body, target, target_id, read_at, created_date, is_deleted, status)
select md5('nt-' || i)::uuid,
       case i % 3 when 0 then md5('user-c-' || (1 + i % (select customers from n)))::uuid
                  when 1 then md5('user-w-' || (1 + i % (select workers from n)))::uuid
                  else md5('user-b-' || (1 + i % (select businesses from n)))::uuid end,
       (array[1,5,22,24,40,41,49])[1 + i % 7], 'Perf notification', 'Body ' || i, 1,
       md5('bk-' || (1 + i % (select bookings from n)))::uuid,
       case when i % 4 = 0 then null else now() end,
       now() - (i % 90) * interval '1 day', false, 1
from generate_series(1, (select notifications from n)) i;

analyze;

select relname as table, n_live_tup as rows
from pg_stat_user_tables where n_live_tup > 1000 order by n_live_tup desc;
