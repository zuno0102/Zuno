-- More crew-strength scenarios: the customer accepting, and a long back-and-forth.
--
-- The first four orders covered the business accepting. These cover the other direction and the
-- case where it takes several rounds to land on a number:
--
--   Order 5  business offered → CUSTOMER accepted        confirmed by the customer, 1 round
--   Order 6  four rounds → CUSTOMER accepted             confirmed on the 4th, 4 rounds
--   Order 7  four rounds, still open, waiting on customer
--   Order 8  four rounds, still open, waiting on business
--
-- Added alongside the first four on the same service. Re-runnable: clears its own rows first.

begin;

create temporary table ctx as
select
    b.id                                                                as business_id,
    (select u.id from users u where u.email = 'owner@zuno.local')       as business_user_id,
    (select bk.customer_profile_id from bookings bk
      where bk.business_owner_profile_id = b.id
      order by bk.created_date desc limit 1)                            as customer_id,
    (select cp.user_id from customer_profiles cp
      where cp.id = (select bk.customer_profile_id from bookings bk
                      where bk.business_owner_profile_id = b.id
                      order by bk.created_date desc limit 1))           as customer_user_id,
    (select bk.address_id from bookings bk
      where bk.business_owner_profile_id = b.id
      order by bk.created_date desc limit 1)                            as address_id,
    (select s.id from business_services s
      where s.name = 'CREW DEMO — Wedding catering' limit 1)            as service_id
from business_owner_profiles b
join users u on u.id = b.user_id
where u.email = 'owner@zuno.local';

-- Only this file's rows. The ids are fixed so a re-run replaces rather than duplicates.
delete from booking_agreement_proposals where booking_id in (
    '22222222-cccc-4005-8005-000000000005'::uuid,
    '22222222-cccc-4006-8006-000000000006'::uuid,
    '22222222-cccc-4007-8007-000000000007'::uuid,
    '22222222-cccc-4008-8008-000000000008'::uuid);
delete from booking_service_answers where booking_id in (
    '22222222-cccc-4005-8005-000000000005'::uuid,
    '22222222-cccc-4006-8006-000000000006'::uuid,
    '22222222-cccc-4007-8007-000000000007'::uuid,
    '22222222-cccc-4008-8008-000000000008'::uuid);
delete from bookings where id in (
    '22222222-cccc-4005-8005-000000000005'::uuid,
    '22222222-cccc-4006-8006-000000000006'::uuid,
    '22222222-cccc-4007-8007-000000000007'::uuid,
    '22222222-cccc-4008-8008-000000000008'::uuid);

-- booking_status 1 = Pending, 6 = Confirmed. price_type 4 = PerPerson.
-- On a settled order price_quoted holds the agreed TOTAL and required_worker_count the agreed
-- crew; on an unsettled one it is still the ₹500 rate with a crew of 0.
insert into bookings
    (id, customer_profile_id, business_owner_profile_id, business_service_id, address_id,
     booking_status, scheduled_date, price_quoted, price_type, required_worker_count,
     notes, created_date, is_deleted, status)
select
    o.id, ctx.customer_id, ctx.business_id, ctx.service_id, ctx.address_id,
    o.state, now() + (o.days || ' days')::interval,
    o.price, 4, o.crew, o.venue, now() - (o.age || ' hours')::interval, false, 1
from ctx, (values
    ('22222222-cccc-4005-8005-000000000005'::uuid, 6, 40,  6000.00, 12,
     'Bolgatty Palace · 200 guests · customer accepted straight away', 8),
    -- Five rounds, not four: the sides alternate, so a negotiation the business opens can only
    -- END on a business offer after an odd number of rounds. Four would leave the customer
    -- speaking last, which is the business accepting — the case order 4 already covers.
    ('22222222-cccc-4006-8006-000000000006'::uuid, 6, 46, 11500.00, 23,
     'Crowne Plaza · 600 guests · five rounds, customer accepted', 7),
    ('22222222-cccc-4007-8007-000000000007'::uuid, 1, 52,   500.00,  0,
     'Taj Malabar · 450 guests · five rounds, waiting on the customer', 6),
    ('22222222-cccc-4008-8008-000000000008'::uuid, 1, 58,   500.00,  0,
     'Casino Hotel · 350 guests · four rounds, waiting on the business', 5)
) as o(id, state, days, price, crew, venue, age);

insert into booking_service_answers
    (id, booking_id, business_service_question_id, question_prompt, answer_text, sort_order,
     created_date, is_deleted, status)
select gen_random_uuid(), a.booking_id, q.id, q.prompt, a.answer, q.sort_order, now(), false, 1
from (values
    ('22222222-cccc-4005-8005-000000000005'::uuid, 0::smallint, '9'),
    ('22222222-cccc-4005-8005-000000000005'::uuid, 1::smallint, 'biryani, chicken roast, payasam'),
    ('22222222-cccc-4005-8005-000000000005'::uuid, 2::smallint, '200'),
    ('22222222-cccc-4006-8006-000000000006'::uuid, 0::smallint, '16'),
    ('22222222-cccc-4006-8006-000000000006'::uuid, 1::smallint, 'biryani, mutton, prawns, 3 sweets'),
    ('22222222-cccc-4006-8006-000000000006'::uuid, 2::smallint, '600'),
    ('22222222-cccc-4007-8007-000000000007'::uuid, 0::smallint, '13'),
    ('22222222-cccc-4007-8007-000000000007'::uuid, 1::smallint, 'veg sadhya, payasam, appam stew'),
    ('22222222-cccc-4007-8007-000000000007'::uuid, 2::smallint, '450'),
    ('22222222-cccc-4008-8008-000000000008'::uuid, 0::smallint, '11'),
    ('22222222-cccc-4008-8008-000000000008'::uuid, 1::smallint, 'biryani, fish curry, halwa'),
    ('22222222-cccc-4008-8008-000000000008'::uuid, 2::smallint, '350')
) as a(booking_id, position, answer)
join ctx on true
join business_service_questions q
  on q.business_service_id = ctx.service_id and q.sort_order = a.position;

-- proposed_by_role: 1 Customer, 2 Business.   proposal_status: 1 Open, 2 Accepted, 3 Superseded.
-- created_date spreads the rounds out so they read in the order they happened.
insert into booking_agreement_proposals
    (id, booking_id, proposed_by_role, proposed_by_user_id, worker_count, price, message,
     proposal_status, responded_at, created_date, is_deleted, status)
select
    gen_random_uuid(), p.booking_id, p.role,
    case p.role when 2 then ctx.business_user_id else ctx.customer_user_id end,
    p.crew, p.price, p.message, p.state,
    case when p.state = 1 then null else now() - (p.age || ' minutes')::interval end,
    now() - ((p.age + 5) || ' minutes')::interval, false, 1
from ctx, (values
    -- 5: one offer, the CUSTOMER accepted it. No haggling at all.
    ('22222222-cccc-4005-8005-000000000005'::uuid, 2::smallint, 12, 6000.00,
     '200 guests, 9 dishes — 12 covers it', 2::smallint, 400),

    -- 6: five rounds, and the CUSTOMER closed it by accepting the business's last word.
    ('22222222-cccc-4006-8006-000000000006'::uuid, 2::smallint, 30, 15000.00,
     '600 guests with 16 dishes needs 30', 3::smallint, 350),
    ('22222222-cccc-4006-8006-000000000006'::uuid, 1::smallint, 18,  9000.00,
     '30 is far too many, 18 should do', 3::smallint, 340),
    ('22222222-cccc-4006-8006-000000000006'::uuid, 2::smallint, 26, 13000.00,
     '18 cannot plate 16 dishes for 600. 26 is our floor', 3::smallint, 330),
    ('22222222-cccc-4006-8006-000000000006'::uuid, 1::smallint, 21, 10500.00,
     'we can spare 2 of our own — 21?', 3::smallint, 320),
    ('22222222-cccc-4006-8006-000000000006'::uuid, 2::smallint, 23, 11500.00,
     '23 with your 2 helping. Final.', 2::smallint, 310),

    -- 7: four rounds and still going. The business spoke last, so it is the customer's turn.
    ('22222222-cccc-4007-8007-000000000007'::uuid, 2::smallint, 24, 12000.00,
     '450 guests, sadhya service needs 24', 3::smallint, 260),
    ('22222222-cccc-4007-8007-000000000007'::uuid, 1::smallint, 16,  8000.00,
     'sadhya is served seated, 16 is plenty', 3::smallint, 250),
    ('22222222-cccc-4007-8007-000000000007'::uuid, 2::smallint, 22, 11000.00,
     'seated service is MORE staff, not less', 3::smallint, 240),
    ('22222222-cccc-4007-8007-000000000007'::uuid, 1::smallint, 19,  9500.00,
     'last offer from us — 19', 3::smallint, 230),
    ('22222222-cccc-4007-8007-000000000007'::uuid, 2::smallint, 21, 10500.00,
     '21 and we will throw in the welcome drinks', 1::smallint, 220),

    -- 8: four rounds, customer spoke last, so the business owes the reply.
    ('22222222-cccc-4008-8008-000000000008'::uuid, 2::smallint, 20, 10000.00,
     '350 guests, 11 dishes — 20 people', 3::smallint, 180),
    ('22222222-cccc-4008-8008-000000000008'::uuid, 1::smallint, 12,  6000.00,
     'we only need serving, not cooking. 12', 3::smallint, 170),
    ('22222222-cccc-4008-8008-000000000008'::uuid, 2::smallint, 18,  9000.00,
     'cooking is included in the rate. 18', 3::smallint, 160),
    ('22222222-cccc-4008-8008-000000000008'::uuid, 1::smallint, 15,  7500.00,
     '15 is what we budgeted for', 1::smallint, 150)
) as p(booking_id, role, crew, price, message, state, age);

commit;

select
    substring(b.notes from '· ([^·]*)$')                 as scenario,
    case b.booking_status when 6 then 'CONFIRMED' else 'Pending' end as state,
    b.required_worker_count                              as crew,
    b.price_quoted                                       as price,
    (select count(*) from booking_agreement_proposals p
      where p.booking_id = b.id)                         as rounds,
    coalesce(
      (select case p.proposed_by_role when 2 then 'customer must reply'
                                      when 1 then 'business must reply' end
        from booking_agreement_proposals p
        where p.booking_id = b.id and p.proposal_status = 1),
      (select 'accepted by the ' || case p.proposed_by_role when 2 then 'customer'
                                                            else 'business' end
        from booking_agreement_proposals p
        where p.booking_id = b.id and p.proposal_status = 2)
    )                                                    as outcome
from bookings b
where b.id in (
    '22222222-cccc-4005-8005-000000000005'::uuid,
    '22222222-cccc-4006-8006-000000000006'::uuid,
    '22222222-cccc-4007-8007-000000000007'::uuid,
    '22222222-cccc-4008-8008-000000000008'::uuid)
order by b.scheduled_date;
