-- Test data for "jobs near me".
--
-- Eight hiring posts at real coordinates up the Kerala coast, on the signed-in owner's own business,
-- so a radius around Trivandrum can be seen to include and exclude the right ones.
--
-- Two of them exist to prove things a naive implementation gets wrong:
--   * NEARBY H  is 200m from Trivandrum but has NO coordinates, so it must appear in the
--               "location not set" group rather than vanish or be treated as 0km away.
--   * NEARBY G  is in Kochi, 176km away, and is the one an "everything nearby" bug would leak in.
--
-- Re-runnable: deletes its own rows by title prefix first.

BEGIN;

DELETE FROM hiring_post_applications
WHERE hiring_post_id IN (SELECT id FROM hiring_posts WHERE title LIKE 'NEARBY %');
DELETE FROM hiring_posts WHERE title LIKE 'NEARBY %';

WITH biz AS (
    SELECT b.id
    FROM business_owner_profiles b
    JOIN users u ON u.id = b.user_id
    WHERE u.email = 'owner@zuno.local'
    LIMIT 1
),
-- Distances are straight-line from Thiruvananthapuram district centre (8.5241, 76.9366).
places(tag, title, district_name, loc, lat, lon, precision) AS (
    VALUES
      ('A', 'NEARBY A - Technopark canteen crew',      'Thiruvananthapuram', 'Technopark Phase 1, Kazhakoottam', 8.5686,  76.8742, 3),
      ('B', 'NEARBY B - Kovalam beach event servers',  'Thiruvananthapuram', 'Kovalam beach road',               8.3988,  76.9782, 3),
      ('C', 'NEARBY C - Attingal wedding kitchen',     'Thiruvananthapuram', 'Attingal town',                    8.6959,  76.8148, 3),
      ('D', 'NEARBY D - Varkala cliff catering',       'Thiruvananthapuram', 'Varkala cliff',                    8.7379,  76.7163, 3),
      ('E', 'NEARBY E - Kollam beach festival crew',   'Kollam',             'Kollam beach',                     8.8932,  76.6141, 3),
      ('F', 'NEARBY F - Alappuzha houseboat service',  'Alappuzha',          'Alappuzha boat jetty',             9.4981,  76.3388, 3),
      ('G', 'NEARBY G - Kochi Marine Drive banquet',   'Ernakulam',          'Marine Drive, Kochi',              9.9816,  76.2999, 3),
      -- Deliberately no coordinates: the "location not set" case.
      ('H', 'NEARBY H - Location not set (test)',      NULL,                 'Behind the temple',                NULL,    NULL,    0)
)
INSERT INTO hiring_posts (
    id, business_owner_profile_id, booking_id, title, description,
    event_date, duration_minutes, location, district_id, latitude, longitude, location_precision,
    workers_needed, salary_amount, salary_unit, hiring_post_status, status,
    created_date, is_deleted
)
SELECT
    gen_random_uuid(),
    biz.id,
    NULL,                                        -- standalone: no order behind it
    p.title,
    'Seeded test post for the nearby-jobs radius filter.',
    now() + interval '10 days',
    480,
    p.loc,
    d.id,
    p.lat,
    p.lon,
    p.precision,
    3,
    900,
    1,                                           -- SalaryUnit.PerEvent
    1,                                           -- HiringPostStatus.Open
    1,                                           -- legacy "status" column, NOT NULL; every live row is 1
    now(),
    false
FROM places p
CROSS JOIN biz
LEFT JOIN districts d
       ON d.name = p.district_name
      AND d.is_deleted = false
      AND d.state_id = (SELECT id FROM states WHERE name = 'Kerala' AND is_deleted = false);

COMMIT;
