#!/usr/bin/env bash
# Splits "Catering & events" into two main categories, because they are two trades.
#
# Catering keeps the category, its four sub-categories and all ten services — every one of them is
# food. Events is new, and starts with the six kinds of work the rest of the catalogue is shaped
# around: six sub-categories per category, named for what a customer would search for.
#
# Idempotent: fixed ids, and every insert is guarded.
set -euo pipefail

CATERING='0853c413-f578-4d8f-998c-542c67c7388c'
EVENTS='a1111111-0000-0000-0000-00000000000a'
PSQL="${PSQL:-psql}"

SECRETS="C:/Users/TLTuser/AppData/Roaming/Microsoft/UserSecrets/4e5c30fb-10fa-4613-a907-38ad9e1b98d5/secrets.json"
PGPASSWORD=$(grep -o '"ConnectionStrings:ZunoDatabase": "[^"]*"' "$SECRETS" | grep -o 'Password=[^;"]*' | cut -d= -f2)
export PGPASSWORD

q() { "$PSQL" -h 127.0.0.1 -U postgres -d "${ZUNO_DB:-zuno}" -At -F' | ' -c "$1"; }

q "
begin;

update service_categories
   set name = 'Catering', slug = 'catering', display_order = 9, modified_date = now()
 where id = '$CATERING';

insert into service_categories
  (id, name, slug, description, display_order, is_active, is_deleted, status, created_date)
values
  ('$EVENTS', 'Events', 'events',
   'Running the day itself: decoration, stage, sound, pictures.',
   10, true, false, 1, now())
on conflict (id) do update
   set name = excluded.name, is_active = true, display_order = excluded.display_order;

insert into service_sub_categories
  (id, service_category_id, name, slug, display_order, is_active, is_deleted, status, created_date)
values
  ('a2222222-0000-0000-000a-000000000001', '$EVENTS', 'Event decoration',   'event-decoration',   1, true, false, 1, now()),
  ('a2222222-0000-0000-000a-000000000002', '$EVENTS', 'Stage & tent',       'stage-tent',         2, true, false, 1, now()),
  ('a2222222-0000-0000-000a-000000000003', '$EVENTS', 'Sound & lighting',   'sound-lighting',     3, true, false, 1, now()),
  ('a2222222-0000-0000-000a-000000000004', '$EVENTS', 'Photography & video','photography-video',  4, true, false, 1, now()),
  ('a2222222-0000-0000-000a-000000000005', '$EVENTS', 'Event planning',     'event-planning',     5, true, false, 1, now()),
  ('a2222222-0000-0000-000a-000000000006', '$EVENTS', 'Live music & DJ',    'live-music-dj',      6, true, false, 1, now())
on conflict (id) do update
   set name = excluded.name, is_active = true;

commit;
" > /dev/null

echo "=== main categories a customer now sees ==="
q "select c.display_order, c.name,
          (select count(*) from service_sub_categories sc
            where sc.service_category_id = c.id and sc.is_active) || ' sub-categories',
          (select count(*) from business_services s
            where s.service_category_id = c.id and s.is_active) || ' services'
     from service_categories c where c.is_active order by c.display_order;"

echo "=== under Events ==="
q "select name from service_sub_categories
    where service_category_id = '$EVENTS' and is_active order by display_order;"
