# 04 — Query & Index Optimization Report (CP3)


## 1. Executive Summary
Combining targeted B-tree/partial indexes (sql/05_indexes.sql) with set-based SQL rewrites (sql/06_optimized_queries.sql) reduced total 30-query benchmark latency from **6,133.90 ms** (baseline) to **166.96 ms** (optimized) — a **36.74× overall speedup** (97.3% latency reduction).


**Baseline Total Average Latency:** 6,133.90 ms
**Optimized Total Average Latency:** 166.96 ms
**Read Workload (R01–R25) Improvement:** 6,122.36 ms → 157.57 ms (**38.85× faster**)
**Write Workload (W01–W05) Improvement:** 11.54 ms → 9.39 ms (**1.23× faster**, with W05 improving **3.15×**)
## 2. Index Strategy (sql/05_indexes.sql)


| Index Name | Table & Definition | Target Queries | Plan Impact |
| :--- | :--- | :--- | :--- |
| idx_utp_player_id | user_team_players(player_id, user_team_id) | R02, R19 | Enables covering player-first index lookups without scanning 439,925 rows repeatedly |
| idx_user_teams_match_id | user_teams(match_id) | R02, R06, R08, R25, W04 | Replaces 39,975-row Seq Scan with Bitmap Index Scan for single-match slices |
| idx_user_teams_user_match | user_teams(user_id, match_id) | R03, R07 | Reduces user match-team lookups to sub-0.08 ms Index Scan |
| idx_contest_entries_team_id | contest_entries(user_team_id) | R11, R15, R17, R21, R25 | Eliminates Seq Scan when joining user_teams → contest_entries |
| idx_contest_entries_joined_at | contest_entries(joined_at) | R11, R15 | Supports range pruning on joined_at >= '2026-01-01' |
| idx_contest_entries_contest_rank | contest_entries(contest_id, final_rank) WHERE final_rank IS NOT NULL | R21 | Partial index filtering settled contest entries |
| idx_contests_match_type | contests(match_id, contest_type) | R01, R04, W02 | Converts Seq Scan on contests to Index Scan (R04: 2.48 ms → 0.13 ms) |
| idx_wallet_txn_user_status_created | wallet_transactions(user_id, status, created_at, txn_id) | R09 | Eliminates sort + Seq Scan on 118,343 rows (R09: 3.92 ms → 0.07 ms) |
| idx_wallet_txn_type_status_created | wallet_transactions(txn_type, status, created_at) | R10, R18, R20, W05 | Index-only/range scan for withdrawal approvals and deposit windows |
| idx_wallet_txn_ref_entry | wallet_transactions(reference_entry_id) WHERE reference_entry_id IS NOT NULL | R13, R25 | Converts Seq Scan anti-joins to Index Only Scan |
| idx_wallet_txn_created_desc | wallet_transactions(created_at DESC) | R22 | Eliminates 118,343-row full sort before OFFSET 50000 |
| idx_matches_status_starts / idx_matches_tournament | matches(status, starts_at) / matches(tournament) | R01, R12, R14, R25 | Accelerates match state and tournament filtering |
| idx_players_team_active | players(team_id, is_active) | R02, R24 | Bitmap Index Scan for active squad rosters |
| idx_users_state_code | users(state_code) WHERE state_code IN ('AS','OD','TG','AP') | R11 | Partial index targeting restricted-state compliance audits |


## 3. SQL Query Rewrites (sql/06_optimized_queries.sql)
1. **R06 (Fair-Play Validation — 3,548.472 ms → 1.887 ms, 1,880× speedup):**
   - Replaced the CROSS JOIN LATERAL correlated subquery (which executed 11 × N sub-scans per team in match 183) with a two-stage CTE (team_side_counts) that aggregates (user_team_id, team_id) in a single pass and rolls up sum(side_cnt), sum(side_credits), and max(side_cnt) per team.
2. **R19 (All-Time Player Selection Counts — 2,345.981 ms → 75.121 ms, 31.2× speedup):**
   - Replaced the scalar correlated subquery (SELECT count(*) FROM user_team_players utp WHERE utp.player_id = p.player_id) with a single LEFT JOIN ... GROUP BY p.player_id, p.full_name hash aggregation over user_team_players.
3. **R02 (Match 207 Player Ownership % — 52.236 ms → 1.570 ms, 33.3× speedup):**
   - Decoupled team-count aggregation (match_teams, player_picks) from the players join using CTEs, preventing multiplicative row expansion across user_teams × players prior to grouping.
4. **R13 (Unbilled Paid Entries — 13.267 ms → 6.419 ms, 2.07× speedup):**
   - Rewrote ce.entry_id NOT IN (SELECT w.reference_entry_id FROM wallet_transactions w) as NOT EXISTS (SELECT 1 FROM wallet_transactions w WHERE w.reference_entry_id = ce.entry_id), avoiding NULL anti-join hazards and enabling Index Only Scan using idx_wallet_txn_ref_entry.
5. **R14 & R20 (Sargable Timestamp Range Predicates — R20: 4.542 ms → 0.746 ms, 6.09× speedup):**
   - Replaced EXTRACT(YEAR FROM m.starts_at) = 2026 (R14) and created_at::date BETWEEN ... (R20) with half-open TIMESTAMPTZ range bounds (>= and <), allowing direct B-tree index range scans.
6. **R22 (Deep Pagination Deferred Join — 22.933 ms → 4.154 ms, 5.52× speedup):**
   - Pushed ORDER BY created_at DESC OFFSET 50000 LIMIT 25 into a narrow subquery scanning only idx_wallet_txn_created_desc before joining back to wallet_transactions on txn_id for the final 25 rows.


## 4. Before vs. After Benchmark Comparison (All 30 Queries)


| Query | Type | Baseline Avg (ms) | Optimized Avg (ms) | Speedup | Key Optimization |
| :--- | :--- | ---: | ---: | ---: | :--- |
| **R01** | READ | 0.304 | 0.403 | 0.75× | Small table (212 matches); planner favors seq scan |
| **R02** | READ | 52.236 | 1.570 | **33.27×** | CTE pre-aggregation + idx_user_teams_match_id |
| **R03** | READ | 1.375 | 0.069 | **19.93×** | Index Scan using idx_user_teams_user_match |
| **R04** | READ | 2.477 | 0.125 | **19.82×** | Index Scan using idx_contests_match_type |
| **R05** | READ | 2.300 | 0.451 | **5.10×** | Index Only Scan on contest_entries unique key |
| **R06** | READ | 3,548.472 | 1.887 | **1,880.48×** | Eliminated CROSS JOIN LATERAL via 2-stage CTE + index |
| **R07** | READ | 1.663 | 0.080 | **20.79×** | Index Scan using idx_user_teams_user_match |
| **R08** | READ | 1.347 | 0.313 | **4.30×** | Bitmap Index Scan on idx_user_teams_match_id |
| **R09** | READ | 3.923 | 0.066 | **59.44×** | Composite index idx_wallet_txn_user_status_created |
| **R10** | READ | 4.425 | 0.048 | **92.19×** | Index Scan using idx_wallet_txn_type_status_created |
| **R11** | READ | 15.748 | 9.444 | **1.67×** | idx_contest_entries_joined_at + partial state_code index |
| **R12** | READ | 1.583 | 0.916 | **1.73×** | Updated planner statistics (ANALYZE) |
| **R13** | READ | 13.267 | 6.419 | **2.07×** | NOT EXISTS rewrite + Index Only Scan on reference_entry_id |
| **R14** | READ | 9.419 | 13.222 | 0.71× | Sargable TIMESTAMPTZ bounds; full-year scan dominates |
| **R15** | READ | 27.352 | 19.854 | **1.38×** | Index Scan using idx_contest_entries_joined_at |
| **R16** | READ | 0.515 | 0.200 | **2.58×** | Cached 450-row players scan |
| **R17** | READ | 12.102 | 11.979 | 1.01× | Full-table duplicate group check |
| **R18** | READ | 14.264 | 5.190 | **2.75×** | Bitmap Index Scan on idx_wallet_txn_type_status_created |
| **R19** | READ | 2,345.981 | 75.121 | **31.23×** | Replaced scalar correlated subquery with single LEFT JOIN |
| **R20** | READ | 4.542 | 0.746 | **6.09×** | Half-open TIMESTAMPTZ range + idx_wallet_txn_created_desc |
| **R21** | READ | 5.017 | 5.084 | 0.99× | Multi-table H2H aggregation |
| **R22** | READ | 22.933 | 4.154 | **5.52×** | Deferred join over idx_wallet_txn_created_desc |
| **R23** | READ | 0.024 | 0.019 | **1.26×** | Index Scan using users_phone_key |
| **R24** | READ | 1.136 | 0.433 | **2.62×** | Bitmap Index Scan on idx_players_team_active |
| **R25** | READ | 7.637 | 1.837 | **4.16×** | Index-driven join path across user_teams & wallet_transactions |
| **W01** | WRITE | 0.453 | 0.493 | 0.92× | Single-row insert (matches PK lookup) |
| **W02** | WRITE | 0.316 | 0.248 | **1.27×** | Index Scan using idx_contests_match_type |
| **W03** | WRITE | 0.315 | 0.556 | 0.57× | Additional index maintenance on insert (sub-millisecond) |
| **W04** | WRITE | 5.649 | 6.566 | 0.86× | Batch points update for match 183 |
| **W05** | WRITE | 4.811 | 1.527 | **3.15×** | Index Scan using idx_wallet_txn_type_status_created |