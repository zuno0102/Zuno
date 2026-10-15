-- Two fresh unread notifications for customer@zuno.local, to watch arrive in the Android shade.
--
-- Written to a file rather than passed with psql -c: the rupee sign and the em dash do not survive
-- the shell pipeline on Windows, and a mangled byte aborts the whole statement.
\set ON_ERROR_STOP on

delete from notifications
where id in ('cf000000-0000-0000-0000-0000000000bb',
             'cf000000-0000-0000-0000-0000000000cc');

insert into notifications
  (id, user_id, kind, title, body, target, target_id, read_at, is_deleted, status, created_date)
values
  ('cf000000-0000-0000-0000-0000000000bb',
   '5666fe99-b6fc-4f45-a5b2-ba2006376c6e', 2,
   'Boss T proposed ₹12,000 for 2 crew',
   'Your answer is needed before this order can be confirmed.',
   1, '0cee3e55-418d-4e09-8c17-80fbec9fdfd0', null, false, 1, now()),

  ('cf000000-0000-0000-0000-0000000000cc',
   '5666fe99-b6fc-4f45-a5b2-ba2006376c6e', 60,
   'Test Owner',
   'We will arrive by 6pm — is the gate open?',
   3, '22222222-cccc-4008-8008-000000000008', null, false, 1, now());

select count(*) || ' unread waiting' as state
from notifications
where user_id = '5666fe99-b6fc-4f45-a5b2-ba2006376c6e'
  and read_at is null and is_deleted = false;
