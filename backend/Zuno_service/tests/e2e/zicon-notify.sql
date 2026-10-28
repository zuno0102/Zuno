\set ON_ERROR_STOP on
delete from notifications where id = 'cf000000-0000-0000-0000-00000000000f';
insert into notifications
  (id, user_id, kind, title, body, target, target_id, read_at, is_deleted, status, created_date)
values
  ('cf000000-0000-0000-0000-00000000000f',
   '5666fe99-b6fc-4f45-a5b2-ba2006376c6e', 1,
   'Boss T confirmed your booking',
   'Plain clean on 23 Oct.',
   1, '0cee3e55-418d-4e09-8c17-80fbec9fdfd0', null, false, 1, now());
