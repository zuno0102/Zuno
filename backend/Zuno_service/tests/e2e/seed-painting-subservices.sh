#!/usr/bin/env bash
# Seeds five more sub-services under "Paintings" (Test Owner), so the customer-side
# "Related services" list can be looked at with a real spread in it.
#
# Deliberately varied, because the list has to survive all of it: long and short descriptions, a
# missing description, a missing duration, every price type, and some with pictures and some without.
#
# Idempotent: the rows carry fixed ids and are deleted before being re-inserted.
set -euo pipefail

SERVICE_ID='0934fd83-9469-4c98-9cb3-c44755796cc3'
ROOT="C:/Beaulin Shajil/Projects/MobileApps/Zuno/backend/Zuno_service/src/Zuno.Api/wwwroot/uploads/services/$SERVICE_ID"
PSQL="${PSQL:-psql}"

SECRETS="C:/Users/TLTuser/AppData/Roaming/Microsoft/UserSecrets/4e5c30fb-10fa-4613-a907-38ad9e1b98d5/secrets.json"
PGPASSWORD=$(grep -o '"ConnectionStrings:ZunoDatabase": "[^"]*"' "$SECRETS" | grep -o 'Password=[^;"]*' | cut -d= -f2)
export PGPASSWORD

q() { "$PSQL" -h 127.0.0.1 -U postgres -d "${ZUNO_DB:-zuno}" -At -F' | ' -c "$1"; }

# ---- pictures -------------------------------------------------------------------------------
# Copied from the service's own gallery. Real files, so the thumbnails and the gallery on each
# sub-service page actually load rather than falling back to the broken-image box.
for pair in "f0001:0 1" "f0002:2" "f0003:1"; do
  vid="d0000000-0000-0000-0000-0000000${pair%%:*}"
  mkdir -p "$ROOT/variants/$vid"
  slot=0
  for src in ${pair#*:}; do
    cp "$ROOT/image-$src.jpg" "$ROOT/variants/$vid/image-$slot.jpg"
    slot=$((slot + 1))
  done
done

# ---- rows -----------------------------------------------------------------------------------
# price_type: 1 Fixed, 2 Hourly, 3 Daily, 4 PerPerson
q "
delete from business_service_media
 where business_service_variant_id in (
   select id from business_service_variants
    where id::text like 'd0000000-0000-0000-0000-0000000f%');
delete from business_service_variants
 where id::text like 'd0000000-0000-0000-0000-0000000f%';

insert into business_service_variants
  (id, business_service_id, name, description, price_type, price,
   estimated_duration_minutes, service_sub_category_id, is_active, is_deleted, status, created_date)
values
  ('d0000000-0000-0000-0000-0000000f0001', '$SERVICE_ID',
   'Interior wall painting',
   'Two coats of emulsion on all interior walls and ceilings, with minor crack filling and a light sanding beforehand. Furniture is sheeted and moved back at the end of the day, and the paint is included in the price.',
   1, 4500, 480, 'a2222222-0000-0000-0005-000000000001', true, false, 1, now()),

  ('d0000000-0000-0000-0000-0000000f0002', '$SERVICE_ID',
   'Putty & primer work',
   'Wall putty and primer only, for a surface somebody else will paint.',
   2, 350, 240, 'a2222222-0000-0000-0005-000000000003', true, false, 1, now()),

  ('d0000000-0000-0000-0000-0000000f0003', '$SERVICE_ID',
   'Texture & stencil feature wall',
   'One feature wall in a textured or stencilled finish, chosen from a sample board brought on the day. Priced per wall up to 120 square feet; larger walls are quoted after a look.',
   1, 6500, 600, 'a2222222-0000-0000-0005-000000000004', true, false, 1, now()),

  ('d0000000-0000-0000-0000-0000000f0004', '$SERVICE_ID',
   'Terrace waterproofing',
   'Terrace coating ahead of the monsoon.',
   3, 2800, null, 'a2222222-0000-0000-0005-000000000006', true, false, 1, now()),

  ('d0000000-0000-0000-0000-0000000f0005', '$SERVICE_ID',
   'Wood polishing',
   null,
   4, 900, 180, 'a2222222-0000-0000-0005-000000000005', true, false, 1, now());

-- business_service_id stays null: a picture belongs to the service or to one of the things listed
-- under it, never to both, and the table has a check constraint saying so.
insert into business_service_media
  (id, business_service_id, business_service_variant_id, media_type, url, sort_order,
   is_deleted, status, created_date)
values
  ('e0000000-0000-0000-0000-0000000f0001', null, 'd0000000-0000-0000-0000-0000000f0001',
   1, '/uploads/services/$SERVICE_ID/variants/d0000000-0000-0000-0000-0000000f0001/image-0.jpg', 0, false, 1, now()),
  ('e0000000-0000-0000-0000-0000000f0002', null, 'd0000000-0000-0000-0000-0000000f0001',
   1, '/uploads/services/$SERVICE_ID/variants/d0000000-0000-0000-0000-0000000f0001/image-1.jpg', 1, false, 1, now()),
  ('e0000000-0000-0000-0000-0000000f0003', null, 'd0000000-0000-0000-0000-0000000f0002',
   1, '/uploads/services/$SERVICE_ID/variants/d0000000-0000-0000-0000-0000000f0002/image-0.jpg', 0, false, 1, now()),
  ('e0000000-0000-0000-0000-0000000f0004', null, 'd0000000-0000-0000-0000-0000000f0003',
   1, '/uploads/services/$SERVICE_ID/variants/d0000000-0000-0000-0000-0000000f0003/image-0.jpg', 0, false, 1, now());
" > /dev/null

echo "=== sub-services now on Paintings ==="
q "select v.name,
          case v.price_type when 1 then 'fixed' when 2 then 'hourly' when 3 then 'daily' else 'per person' end,
          v.price,
          coalesce(v.estimated_duration_minutes::text, 'no duration'),
          coalesce(sc.name, 'no sub-category'),
          (select count(*) from business_service_media m where m.business_service_variant_id = v.id) || ' pictures'
     from business_service_variants v
     left join service_sub_categories sc on sc.id = v.service_sub_category_id
    where v.business_service_id = '$SERVICE_ID' and v.is_active
    order by v.price;"
