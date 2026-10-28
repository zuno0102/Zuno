#!/usr/bin/env bash
# Ratings on finished bookings, and the roll-up that goes with them.
#
# "Top rated" on the home screen was empty, and the reason was data rather than code: the only rating
# in the database was one I had inserted directly, which skipped the command that keeps
# business_owner_profiles.customer_rating_average and customer_review_count in step with it.
#
# So this does both halves — a rating row per finished booking that has none, and the roll-up
# recomputed from the ratings table for every business. Recomputing rather than incrementing means
# running it twice cannot drift the average.
set -euo pipefail

PSQL="${PSQL:-psql}"
SECRETS="C:/Users/TLTuser/AppData/Roaming/Microsoft/UserSecrets/4e5c30fb-10fa-4613-a907-38ad9e1b98d5/secrets.json"
PGPASSWORD=$(grep -o '"ConnectionStrings:ZunoDatabase": "[^"]*"' "$SECRETS" | grep -o 'Password=[^;"]*' | cut -d= -f2)
export PGPASSWORD

q() { "$PSQL" -h 127.0.0.1 -U postgres -d "${ZUNO_DB:-zuno}" -At -F' | ' -c "$1"; }

q "
begin;

-- A rating on every completed booking that has none. Scores spread 3-5 so 'top rated' is a ranking
-- rather than a wall of fives, and seeded from the booking id so re-running gives the same answer.
insert into ratings
  (id, booking_id, customer_profile_id, business_owner_profile_id, score, comment,
   is_deleted, status, created_date)
select gen_random_uuid(), b.id, b.customer_profile_id, b.business_owner_profile_id,
       3 + (('x' || substr(md5(b.id::text), 1, 8))::bit(32)::bigint % 3),
       (array['Good work, on time.',
              'Happy with the result.',
              'Did exactly what we asked.',
              'Would book again.',
              'Tidy and professional.'])[1 + (('x' || substr(md5(b.id::text), 9, 8))::bit(32)::bigint % 5)],
       false, 1, b.completed_at
  from bookings b
 where b.booking_status = 4
   and not b.is_deleted
   and not exists (select 1 from ratings r where r.booking_id = b.id);

-- The roll-up the app actually reads, recomputed from the rows above.
update business_owner_profiles p
   set customer_rating_average = agg.avg_score,
       customer_review_count = agg.n,
       modified_date = now()
  from (select business_owner_profile_id, round(avg(score)::numeric, 2) as avg_score, count(*) as n
          from ratings where not is_deleted
         group by business_owner_profile_id) agg
 where agg.business_owner_profile_id = p.id;

commit;
" > /dev/null

echo "=== businesses now carrying a rating ==="
q "select count(*) || ' of ' || (select count(*) from business_owner_profiles where verification_status = 1)
     from business_owner_profiles
    where verification_status = 1 and customer_rating_average is not null;"

echo "=== the best of them ==="
q "select business_name, customer_rating_average || ' from ' || customer_review_count || ' reviews'
     from business_owner_profiles
    where customer_rating_average is not null
    order by customer_rating_average desc, customer_review_count desc limit 6;"
