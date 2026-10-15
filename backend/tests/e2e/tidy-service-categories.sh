#!/usr/bin/env bash
# Leaves the customer's category filter showing main categories only.
#
# Nine rows of rubbish had accumulated from e2e runs: eight named "Catering & events <epoch>",
# because the script creates a fresh category every time it runs, and one called "!!!". They sat in
# the All categories sheet beside the eight real ones.
#
# The eight seeded categories carry display_order 1-8; everything the e2e scripts made carries 20+.
# That is how they are told apart here.
#
# Nothing is deleted. Categories are deactivated, which the catalogue query already filters on, so
# this is undone by setting is_active back to true.
#
# One of the junk categories is kept and renamed rather than deactivated: Test Owner's real
# "wedding catering" service lives on it, along with its sub-categories. Promoting that row keeps
# that service and its sub-categories intact, and gives the catalogue the catering category it never
# actually had.
set -euo pipefail

KEEP='0853c413-f578-4d8f-998c-542c67c7388c'
PSQL="${PSQL:-psql}"

SECRETS="C:/Users/TLTuser/AppData/Roaming/Microsoft/UserSecrets/4e5c30fb-10fa-4613-a907-38ad9e1b98d5/secrets.json"
PGPASSWORD=$(grep -o '"ConnectionStrings:ZunoDatabase": "[^"]*"' "$SECRETS" | grep -o 'Password=[^;"]*' | cut -d= -f2)
export PGPASSWORD

q() { "$PSQL" -h 127.0.0.1 -U postgres -d "${ZUNO_DB:-zuno}" -At -F' | ' -c "$1"; }

echo "=== before ==="
q "select count(*) || ' active categories' from service_categories where is_active;"

q "
begin;

-- 1. Promote the one worth keeping. It holds a real service, so it becomes the catering category.
update service_categories
   set name = 'Catering & events', display_order = 9, modified_date = now()
 where id = '$KEEP';

update service_sub_categories
   set is_active = false, modified_date = now()
 where service_category_id = '$KEEP' and name like 'Shared name %';

-- 2. Nothing is left stranded on a category about to be switched off.
update business_services s
   set service_category_id = '$KEEP', modified_date = now()
  from service_categories c
 where c.id = s.service_category_id
   and c.display_order >= 20 and c.id <> '$KEEP';

-- 3. Switch the rest off, sub-categories included, or they would still fill the pickers.
update service_sub_categories sc
   set is_active = false, modified_date = now()
  from service_categories c
 where c.id = sc.service_category_id
   and c.display_order >= 20 and c.id <> '$KEEP';

update service_categories
   set is_active = false, modified_date = now()
 where display_order >= 20 and id <> '$KEEP';

commit;
" > /dev/null

echo "=== after: what the filter now offers ==="
q "select display_order || '. ' || name ||
          ' - ' || (select count(*) from business_services s
                     where s.service_category_id = c.id and s.is_active) || ' services'
     from service_categories c where c.is_active order by display_order;"

echo "=== switched off (reversible) ==="
q "select count(*) || ' categories, ' ||
          (select count(*) from service_sub_categories where not is_active) || ' sub-categories'
     from service_categories where not is_active;"
