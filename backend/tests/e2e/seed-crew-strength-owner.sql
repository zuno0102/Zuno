-- Crew-strength test data on the account you are actually signed in as.
--
-- The first attempt at this made its own business, so the orders were real but invisible to a
-- session logged in as owner@zuno.local. This puts them on that owner's own business instead,
-- reusing a customer and address it has already dealt with.
--
-- Four orders, one at each stage of agreeing how many people the job takes:
--   150 guests   nobody has offered yet        "₹500 per person · crew size to be agreed"
--   400 guests   business offered 20           waiting on the customer
--   300 guests   customer countered 14         back with the business
--   500 guests   agreed at 18                  CONFIRMED · ₹9,000 · 18 people
--
-- Re-runnable: it clears anything a previous run left behind first.

begin;

create temporary table ctx as
select
    b.id                                                                as business_id,
    (select bk.customer_profile_id from bookings bk
      where bk.business_owner_profile_id = b.id
      order by bk.created_date desc limit 1)                            as customer_id,
    (select bk.address_id from bookings bk
      where bk.business_owner_profile_id = b.id
      order by bk.created_date desc limit 1)                            as address_id,
    (select c.id from service_categories c where c.slug = 'cleaning')   as category_id
from business_owner_profiles b
join users u on u.id = b.user_id
where u.email = 'owner@zuno.local';

-- Clean out a previous run. Children first: proposals and answers point at the bookings.
delete from booking_agreement_proposals
where booking_id in (
    select bk.id from bookings bk
    join business_services s on s.id = bk.business_service_id
    where s.name = 'CREW DEMO — Wedding catering');

delete from booking_service_answers
where booking_id in (
    select bk.id from bookings bk
    join business_services s on s.id = bk.business_service_id
    where s.name = 'CREW DEMO — Wedding catering');

delete from bookings
where business_service_id in (
    select id from business_services where name = 'CREW DEMO — Wedding catering');

delete from business_service_questions
where business_service_id in (
    select id from business_services where name = 'CREW DEMO — Wedding catering');

delete from business_services where name = 'CREW DEMO — Wedding catering';

-- The service: priced by the head, so the crew size is what gets agreed. price_type 4 =
-- PerPerson, and required_worker_count 0 means "depends on the event".
insert into business_services
    (id, business_owner_profile_id, service_category_id, name, description,
     price_type, price, required_worker_count, is_active, created_date, is_deleted, status)
select
    gen_random_uuid(), ctx.business_id, ctx.category_id,
    'CREW DEMO — Wedding catering', 'Full service catering, priced by the head',
    4, 500, 0, true, now(), false, 1
from ctx;

create temporary table svc as
select id from business_services where name = 'CREW DEMO — Wedding catering';

-- What this business asks a customer before it can staff the job.
insert into business_service_questions
    (id, business_service_id, prompt, is_required, sort_order, created_date, is_deleted, status)
select gen_random_uuid(), svc.id, q.prompt, q.required, q.position, now(), false, 1
from svc, (values
    ('Enter your dishes count', true,  0::smallint),
    ('Enter your items',        true,  1::smallint),
    ('Total serving items',     false, 2::smallint)
) as q(prompt, required, position);

-- The four orders. price_quoted holds the RATE while the crew is unsettled, and is overwritten
-- with the agreed TOTAL when an offer is accepted — which is why the last one reads 9000.
insert into bookings
    (id, customer_profile_id, business_owner_profile_id, business_service_id, address_id,
     booking_status, scheduled_date, price_quoted, price_type, required_worker_count,
     notes, created_date, is_deleted, status)
select
    o.id, ctx.customer_id, ctx.business_id, svc.id, ctx.address_id,
    o.booking_status, now() + (o.days || ' days')::interval,
    o.price, 4, o.crew, o.venue, now() - (o.age || ' hours')::interval, false, 1
from ctx, svc, (values
    ('11111111-cccc-4001-8001-000000000001'::uuid, 1, 12,  500.00, 0,  'Kalathil Auditorium · 150 guests', 4),
    ('11111111-cccc-4002-8002-000000000002'::uuid, 1, 18,  500.00, 0,  'Grand Hyatt Bolgatty · 400 guests', 3),
    ('11111111-cccc-4003-8003-000000000003'::uuid, 1, 25,  500.00, 0,  'Kadavanthra Hall · 300 guests', 2),
    ('11111111-cccc-4004-8004-000000000004'::uuid, 6, 32, 9000.00, 18, 'Le Meridien Kochi · 500 guests', 1)
) as o(id, booking_status, days, price, crew, venue, age);

-- The customer's answers, with the wording frozen onto each one.
insert into booking_service_answers
    (id, booking_id, business_service_question_id, question_prompt, answer_text, sort_order,
     created_date, is_deleted, status)
select gen_random_uuid(), a.booking_id, q.id, q.prompt, a.answer, q.sort_order,
       now(), false, 1
from (values
    ('11111111-cccc-4001-8001-000000000001'::uuid, 0::smallint, '8'),
    ('11111111-cccc-4001-8001-000000000001'::uuid, 1::smallint, 'biryani, chicken curry, payasam'),
    ('11111111-cccc-4001-8001-000000000001'::uuid, 2::smallint, '150'),
    ('11111111-cccc-4002-8002-000000000002'::uuid, 0::smallint, '12'),
    ('11111111-cccc-4002-8002-000000000002'::uuid, 1::smallint, 'biryani, paneer, gulab jamun, salad'),
    ('11111111-cccc-4002-8002-000000000002'::uuid, 2::smallint, '400'),
    ('11111111-cccc-4003-8003-000000000003'::uuid, 0::smallint, '10'),
    ('11111111-cccc-4003-8003-000000000003'::uuid, 1::smallint, 'veg meals, sambar, avial, payasam'),
    ('11111111-cccc-4003-8003-000000000003'::uuid, 2::smallint, '300'),
    ('11111111-cccc-4004-8004-000000000004'::uuid, 0::smallint, '14'),
    ('11111111-cccc-4004-8004-000000000004'::uuid, 1::smallint, 'biryani, fish fry, prawns, gulab jamun'),
    ('11111111-cccc-4004-8004-000000000004'::uuid, 2::smallint, '500')
) as a(booking_id, position, answer)
join svc on true
join business_service_questions q
  on q.business_service_id = svc.id and q.sort_order = a.position;

-- The offers. proposal_status: 1 Open, 2 Accepted, 3 Superseded.
-- proposed_by_role: 1 Customer, 2 Business.
insert into booking_agreement_proposals
    (id, booking_id, proposed_by_role, proposed_by_user_id, worker_count, price, message,
     proposal_status, responded_at, created_date, is_deleted, status)
select
    gen_random_uuid(), p.booking_id, p.role,
    case p.role when 2 then (select id from users where email = 'owner@zuno.local')
                else (select cp.user_id from customer_profiles cp join ctx on true
                      where cp.id = ctx.customer_id) end,
    p.crew, p.price, p.message, p.state,
    case when p.state = 1 then null else now() end,
    now() - (p.age || ' minutes')::interval, false, 1
from ctx, (values
    -- 400 guests: the business has offered and is waiting on the customer.
    ('11111111-cccc-4002-8002-000000000002'::uuid, 2::smallint, 20, 10000.00,
     '400 guests needs 5 servers per 100', 1::smallint, 90),
    -- 300 guests: the customer countered, so it is back with the business.
    ('11111111-cccc-4003-8003-000000000003'::uuid, 2::smallint, 16,  8000.00,
     '300 guests, 16 covers it comfortably', 3::smallint, 120),
    ('11111111-cccc-4003-8003-000000000003'::uuid, 1::smallint, 14,  7000.00,
     'our family will help serve, 14 is enough', 1::smallint, 60),
    -- 500 guests: agreed. The business came down from 20 to 18.
    ('11111111-cccc-4004-8004-000000000004'::uuid, 2::smallint, 20, 10000.00,
     '500 guests, we recommend 20', 3::smallint, 180),
    ('11111111-cccc-4004-8004-000000000004'::uuid, 1::smallint, 18,  9000.00,
     '18 is enough, we have 2 of our own', 2::smallint, 150)
) as p(booking_id, role, crew, price, message, state, age);

commit;

select
    substring(b.notes from '· (.*)$')                    as event,
    case b.booking_status when 6 then 'CONFIRMED' else 'Pending' end as state,
    b.required_worker_count                              as crew,
    b.price_quoted                                       as price,
    (select count(*) from booking_agreement_proposals p
      where p.booking_id = b.id)                         as rounds,
    coalesce((select case p.proposed_by_role when 2 then 'business offered'
                                             when 1 then 'customer countered' end
              from booking_agreement_proposals p
              where p.booking_id = b.id and p.proposal_status = 1), 'no offer yet') as waiting_on
from bookings b
join business_services s on s.id = b.business_service_id
where s.name = 'CREW DEMO — Wedding catering'
order by b.scheduled_date;
