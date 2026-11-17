SET search_path TO dream11;
BEGIN;


-- @R01
SELECT m.match_id, h.short_name || ' vs ' || a.short_name AS fixture, m.starts_at,
       count(c.contest_id) AS contests, sum(c.prize_pool) AS prize_money
FROM matches m
JOIN teams h ON h.team_id = m.home_team_id
JOIN teams a ON a.team_id = m.away_team_id
LEFT JOIN contests c ON c.match_id = m.match_id
WHERE m.status = 'UPCOMING'
GROUP BY m.match_id, h.short_name, a.short_name, m.starts_at
ORDER BY m.starts_at;


-- @R02
WITH match_teams AS (
    SELECT user_team_id FROM user_teams WHERE match_id = 207
),
team_total AS (
    SELECT count(*) AS total_cnt FROM match_teams
),
player_picks AS (
    SELECT utp.player_id, count(*) AS pick_cnt
    FROM match_teams mt
    JOIN user_team_players utp ON utp.user_team_id = mt.user_team_id
    GROUP BY utp.player_id
)
SELECT p.player_id, p.full_name, t.short_name, p.role, p.credits,
       round(100.0 * coalesce(pp.pick_cnt, 0) / NULLIF(tt.total_cnt, 0), 1) AS selected_pct
FROM matches m
JOIN players p ON p.team_id IN (m.home_team_id, m.away_team_id) AND p.is_active
JOIN teams t   ON t.team_id = p.team_id
CROSS JOIN team_total tt
LEFT JOIN player_picks pp ON pp.player_id = p.player_id
WHERE m.match_id = 207
ORDER BY selected_pct DESC;


-- @R03
SELECT ut.team_label, c.full_name AS captain, v.full_name AS vice_captain, ut.total_points
FROM user_teams ut
JOIN players c ON c.player_id = ut.captain_id
JOIN players v ON v.player_id = ut.vice_captain_id
WHERE ut.user_id = 1006 AND ut.match_id = 130
ORDER BY ut.team_label;


-- @R04
SELECT c.contest_id, c.contest_name, c.entry_fee, c.prize_pool, c.total_spots,
       c.total_spots - count(ce.entry_id) AS spots_left
FROM contests c
LEFT JOIN contest_entries ce ON ce.contest_id = c.contest_id
WHERE c.match_id = 207 AND c.contest_type <> 'PRIVATE'
GROUP BY c.contest_id, c.contest_name, c.entry_fee, c.prize_pool, c.total_spots
ORDER BY c.prize_pool DESC;


-- @R05
SELECT u.username, ut.team_label, ut.total_points,
       RANK() OVER (ORDER BY ut.total_points DESC) AS position
FROM contest_entries ce
JOIN user_teams ut ON ut.user_team_id = ce.user_team_id
JOIN users u       ON u.user_id = ut.user_id
WHERE ce.contest_id = 2185
ORDER BY position
LIMIT 100;


-- @R06
WITH team_side_counts AS (
    SELECT ut.user_team_id, p.team_id,
           count(*) AS side_cnt,
           sum(p.credits) AS side_credits
    FROM user_teams ut
    JOIN user_team_players utp ON utp.user_team_id = ut.user_team_id
    JOIN players p             ON p.player_id = utp.player_id
    WHERE ut.match_id = 183
    GROUP BY ut.user_team_id, p.team_id
)
SELECT user_team_id,
       sum(side_cnt) AS players,
       sum(side_credits) AS credits_used,
       max(side_cnt) AS max_from_one_team
FROM team_side_counts
GROUP BY user_team_id
HAVING sum(side_cnt) <> 11 OR sum(side_credits) > 100 OR max(side_cnt) > 7;


-- @R07
SELECT p.full_name, p.role, coalesce(s.fantasy_points, 0) AS base_points,
       coalesce(s.fantasy_points, 0) * CASE WHEN p.player_id = ut.captain_id THEN 2
                                            WHEN p.player_id = ut.vice_captain_id THEN 1.5 ELSE 1 END AS team_points
FROM user_teams ut
JOIN user_team_players utp ON utp.user_team_id = ut.user_team_id
JOIN players p             ON p.player_id = utp.player_id
LEFT JOIN player_match_stats s ON s.match_id = ut.match_id AND s.player_id = p.player_id
WHERE ut.user_id = 1006 AND ut.match_id = 130 AND ut.team_label = 'T1'
ORDER BY team_points DESC;


-- @R08
SELECT p.full_name, count(*) AS times_captain
FROM user_teams ut
JOIN players p ON p.player_id = ut.captain_id
WHERE ut.match_id = 207
GROUP BY p.full_name
ORDER BY times_captain DESC
LIMIT 10;


-- @R09
SELECT created_at, txn_type, amount,
       sum(CASE WHEN txn_type IN ('DEPOSIT', 'WINNINGS', 'BONUS', 'REFUND') THEN amount ELSE -amount END)
           OVER (ORDER BY created_at, txn_id) AS running_balance
FROM wallet_transactions
WHERE user_id = 1006 AND status = 'SUCCESS'
ORDER BY created_at, txn_id;


-- @R10
SELECT txn_id, user_id, amount, created_at
FROM wallet_transactions
WHERE txn_type = 'WITHDRAWAL' AND status = 'PENDING'
  AND created_at < TIMESTAMPTZ '2026-06-30 23:59:00+05:30' - interval '24 hours'
ORDER BY created_at;


-- @R11
SELECT u.user_id, u.username, u.state_code, count(*) AS paid_entries
FROM users u
JOIN user_teams ut      ON ut.user_id = u.user_id
JOIN contest_entries ce ON ce.user_team_id = ut.user_team_id
JOIN contests c         ON c.contest_id = ce.contest_id AND c.entry_fee > 0
WHERE u.state_code IN ('AS', 'OD', 'TG', 'AP')
  AND ce.joined_at >= TIMESTAMPTZ '2026-01-01 00:00:00+05:30'
GROUP BY u.user_id, u.username, u.state_code
ORDER BY paid_entries DESC;


-- @R12
SELECT p.full_name, t.short_name, count(*) AS matches, round(avg(s.fantasy_points), 1) AS avg_points
FROM player_match_stats s
JOIN players p ON p.player_id = s.player_id
JOIN teams t   ON t.team_id = p.team_id
JOIN matches m ON m.match_id = s.match_id AND m.tournament = 'IPL 2026'
GROUP BY p.full_name, t.short_name
HAVING count(*) >= 5
ORDER BY avg_points DESC
LIMIT 20;


-- @R13
SELECT ce.entry_id, ce.contest_id, ce.joined_at
FROM contest_entries ce
JOIN contests c ON c.contest_id = ce.contest_id
WHERE c.entry_fee > 0
  AND NOT EXISTS (
      SELECT 1 FROM wallet_transactions w
      WHERE w.reference_entry_id = ce.entry_id
  );


-- @R14
SELECT c.contest_type, count(DISTINCT c.contest_id) AS contests,
       round(100.0 * count(ce.entry_id) / sum(DISTINCT c.total_spots), 1) AS rough_fill_pct
FROM contests c
JOIN matches m ON m.match_id = c.match_id AND m.status = 'COMPLETED'
LEFT JOIN contest_entries ce ON ce.contest_id = c.contest_id
WHERE m.starts_at >= TIMESTAMPTZ '2026-01-01 00:00:00+05:30'
  AND m.starts_at <  TIMESTAMPTZ '2027-01-01 00:00:00+05:30'
GROUP BY c.contest_type
ORDER BY contests DESC;


-- @R15
SELECT u.user_id, u.username, sum(ce.winnings) AS winnings, count(*) FILTER (WHERE ce.winnings > 0) AS wins
FROM contest_entries ce
JOIN user_teams ut ON ut.user_team_id = ce.user_team_id
JOIN users u       ON u.user_id = ut.user_id
WHERE ce.joined_at >= TIMESTAMPTZ '2026-01-01 00:00:00+05:30'
GROUP BY u.user_id, u.username
ORDER BY winnings DESC
LIMIT 20;


-- @R16
SELECT p.player_id, p.full_name, t.short_name, p.role, p.credits
FROM players p
JOIN teams t ON t.team_id = p.team_id
WHERE p.full_name ILIKE '%sharma%'
ORDER BY p.credits DESC;


-- @R17
SELECT ce.contest_id, ut.user_id, count(*) AS teams_in_contest
FROM contest_entries ce
JOIN user_teams ut ON ut.user_team_id = ce.user_team_id
GROUP BY ce.contest_id, ut.user_id
HAVING count(*) > 1
ORDER BY teams_in_contest DESC;


-- @R18
SELECT u.user_id, u.username, u.kyc_status, sum(w.amount) AS total_winnings
FROM users u
JOIN wallet_transactions w ON w.user_id = u.user_id AND w.txn_type = 'WINNINGS' AND w.status = 'SUCCESS'
WHERE u.kyc_status <> 'VERIFIED'
GROUP BY u.user_id, u.username, u.kyc_status
HAVING sum(w.amount) > 1000
ORDER BY total_winnings DESC;


-- @R19
SELECT p.player_id, p.full_name, count(utp.user_team_id) AS times_picked
FROM players p
JOIN teams t ON t.team_id = p.team_id AND t.team_type = 'FRANCHISE'
LEFT JOIN user_team_players utp ON utp.player_id = p.player_id
GROUP BY p.player_id, p.full_name
ORDER BY times_picked DESC;


-- @R20
SELECT day, deposits, sum(deposits) OVER (ORDER BY day) AS running_total
FROM (
    SELECT created_at::date AS day, sum(amount) AS deposits
    FROM wallet_transactions
    WHERE txn_type = 'DEPOSIT' AND status = 'SUCCESS'
      AND created_at >= TIMESTAMPTZ '2026-06-01 00:00:00+05:30'
      AND created_at <  TIMESTAMPTZ '2026-07-01 00:00:00+05:30'
    GROUP BY 1
) d
ORDER BY day;


-- @R21
SELECT ut.user_id, count(*) AS h2h_played,
       round(100.0 * count(*) FILTER (WHERE ce.final_rank = 1) / count(*), 1) AS win_pct
FROM contest_entries ce
JOIN contests c    ON c.contest_id = ce.contest_id AND c.contest_type = 'HEAD_TO_HEAD'
JOIN user_teams ut ON ut.user_team_id = ce.user_team_id
WHERE ce.final_rank IS NOT NULL
GROUP BY ut.user_id
HAVING count(*) >= 3
ORDER BY win_pct DESC, h2h_played DESC
LIMIT 30;


-- @R22
SELECT w.txn_id, w.user_id, w.txn_type, w.amount, w.status, w.created_at
FROM (
    SELECT txn_id
    FROM wallet_transactions
    ORDER BY created_at DESC
    OFFSET 50000
    LIMIT 25
) p
JOIN wallet_transactions w ON w.txn_id = p.txn_id
ORDER BY w.created_at DESC;


-- @R23
SELECT user_id, username, kyc_status
FROM users
WHERE phone = '7300001042';


--- @R24
SELECT full_name, starts_at, fantasy_points
FROM (
    SELECT p.full_name, m.starts_at, s.fantasy_points,
           ROW_NUMBER() OVER (PARTITION BY p.player_id ORDER BY m.starts_at DESC) AS rn
    FROM player_match_stats s
    JOIN players p ON p.player_id = s.player_id
    JOIN teams t   ON t.team_id = p.team_id AND t.short_name = 'CSK'
    JOIN matches m ON m.match_id = s.match_id
) x
WHERE rn <= 5
ORDER BY full_name, starts_at DESC;


-- @R25
SELECT ce.entry_id, ut.user_id, c.entry_fee, m.match_id
FROM contest_entries ce
JOIN contests c    ON c.contest_id = ce.contest_id AND c.entry_fee > 0
JOIN user_teams ut ON ut.user_team_id = ce.user_team_id
JOIN matches m     ON m.match_id = ut.match_id AND m.status = 'ABANDONED'
WHERE NOT EXISTS (SELECT 1 FROM wallet_transactions w WHERE w.reference_entry_id = ce.entry_id AND w.txn_type = 'REFUND')
ORDER BY m.match_id, ce.entry_id;


-- @W01
INSERT INTO user_teams (user_team_id, user_id, match_id, team_label, captain_id, vice_captain_id, created_at)
SELECT 90000001, 1006, 207, 'T9',
       (m.home_team_id - 1) * 25 + 1, (m.away_team_id - 1) * 25 + 2, '2026-07-01 18:00:00+05:30'
FROM matches m WHERE m.match_id = 207;


-- @W02
INSERT INTO contest_entries (entry_id, contest_id, user_team_id, joined_at)
SELECT 90000001, c.contest_id, ut.user_team_id, '2026-07-01 18:05:00+05:30'
FROM contests c
JOIN user_teams ut ON ut.match_id = c.match_id
WHERE c.match_id = 207 AND c.contest_type = 'MEGA'
  AND ut.user_team_id = (SELECT max(user_team_id) FROM user_teams WHERE match_id = 207)
ON CONFLICT (contest_id, user_team_id) DO NOTHING;


-- @W03
INSERT INTO wallet_transactions (txn_id, user_id, txn_type, amount, reference_entry_id, status, created_at)
SELECT 90000001, ut.user_id, 'ENTRY_FEE', c.entry_fee, ce.entry_id, 'SUCCESS', '2026-07-01 18:05:00+05:30'
FROM contest_entries ce
JOIN contests c    ON c.contest_id = ce.contest_id
JOIN user_teams ut ON ut.user_team_id = ce.user_team_id
WHERE ce.entry_id = (SELECT max(entry_id) FROM contest_entries);


-- @W04
UPDATE user_teams ut
SET total_points = s.pts
FROM (SELECT ut2.user_team_id,
             sum(coalesce(pms.fantasy_points, 0) * CASE WHEN utp.player_id = ut2.captain_id THEN 2
                                                        WHEN utp.player_id = ut2.vice_captain_id THEN 1.5 ELSE 1 END) AS pts
      FROM user_teams ut2
      JOIN user_team_players utp ON utp.user_team_id = ut2.user_team_id
      LEFT JOIN player_match_stats pms ON pms.match_id = ut2.match_id AND pms.player_id = utp.player_id
      WHERE ut2.match_id = 183
      GROUP BY ut2.user_team_id) s
WHERE s.user_team_id = ut.user_team_id;


-- @W05
UPDATE wallet_transactions
SET status = 'SUCCESS'
WHERE txn_type = 'WITHDRAWAL' AND status = 'PENDING'
  AND created_at < TIMESTAMPTZ '2026-06-30 23:59:00+05:30' - interval '24 hours';


--- @END
ROLLBACK;