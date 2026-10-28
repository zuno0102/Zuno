-- Payout destinations for the crew on "Acrylic Paintings", so a pay run can actually reach them.
-- Without a verified destination the handler fails each worker with "No UPI ID or bank account on
-- file", which is correct behaviour but makes the flow impossible to demonstrate.
--
-- verification_status 1 = Verified. Only verified details may be paid to.
-- status 1 = Active, is_deleted false: the columns every BaseEntity row carries.

INSERT INTO worker_payout_details (
    id, worker_profile_id, upi_vpa, account_holder_name,
    verification_status, verified_at, created_date, is_deleted, status
)
SELECT
    gen_random_uuid(),
    w.id,
    -- A recognisable handle per worker, in the shape a real VPA takes.
    lower(split_part(u.first_name, ' ', 1)) || '@' ||
        (ARRAY['okhdfcbank', 'okaxis', 'ybl', 'oksbi'])[1 + (row_number() OVER (ORDER BY u.first_name) - 1) % 4],
    trim(u.first_name || ' ' || u.last_name),
    1,
    now(),
    now(),
    false,
    1
FROM hiring_post_applications a
JOIN hiring_posts p       ON p.id = a.hiring_post_id
JOIN worker_profiles w    ON w.id = a.worker_profile_id
JOIN users u              ON u.id = w.user_id
WHERE p.title = 'Acrylic Paintings'
  AND p.is_deleted = false
  AND a.application_status = 4          -- Accepted: only these are owed wages
  AND NOT EXISTS (
      SELECT 1 FROM worker_payout_details d
      WHERE d.worker_profile_id = w.id AND d.is_deleted = false
  );
