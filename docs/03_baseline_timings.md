# 03 — Baseline Query Timings & Bottleneck Analysis (CP2)

## 1. Benchmark Environment & Methodology
- **Database Engine:** PostgreSQL (`dream11_db`, schema `dream11`)
- **Dataset Scale:** ~698,255 rows across 10 normalized tables (`user_team_players`: 439,925; `wallet_transactions`: 118,343; `users`: 50,000; `contest_entries`: 42,746; `user_teams`: 39,975)
- **Schema State:** Unoptimized baseline (`sql/01_schema.sql` — primary key and unique constraint indexes only; zero secondary foreign-key or filter indexes)
- **Execution Protocol:** `./benchmarks/run_benchmark.sh dream11_db baseline` executed `EXPLAIN (ANALYZE, BUFFERS)` 3 times per query (`R01–R25` reads, `W01–W05` writes wrapped in `BEGIN ... ROLLBACK`).

## 2. Summary Metrics
- **Total Workload Average Execution Time:** `6,133.90 ms` (~6.13 seconds across 30 queries)
- **Read Workload (`R01–R25`) Sum of Averages:** `6,122.36 ms`
- **Write Workload (`W01–W05`) Sum of Averages:** `11.54 ms`
- **Dominant Bottlenecks:** `R06` (`3,548.472 ms`, 57.8% of total time) and `R19` (`2,345.981 ms`, 38.2% of total time) together account for **96.1%** of total baseline latency.

## 3. Complete Baseline Timing Table (30 Queries)

| Query | Type | Avg (ms) | Median (ms) | Min (ms) | Max (ms) | Primary Scan Nodes Observed |
| :--- | :--- | ---: | ---: | ---: | ---: | :--- |
| **R01** | READ | 0.304 | 0.304 | 0.296 | 0.312 | Seq Scan on `contests`, `matches`; Index Scan on `teams` |
| **R02** | READ | 52.236 | 52.160 | 51.520 | 53.027 | Seq Scan on `user_teams`, `players`; Index Only Scan on `user_team_players` |
| **R03** | READ | 1.375 | 1.367 | 1.352 | 1.407 | Seq Scan on `user_teams`, `players` |
| **R04** | READ | 2.477 | 2.432 | 2.399 | 2.600 | Seq Scan on `contest_entries`, `contests` |
| **R05** | READ | 2.300 | 2.268 | 2.235 | 2.397 | Seq Scan on `user_teams`; Bitmap Scan on `contest_entries` |
| **R06** | READ | **3,548.472** | 3,551.926 | 3,519.975 | 3,573.514 | Seq Scan on `user_teams`, `players`; Index Only/Bitmap Scan on `user_team_players` |
| **R07** | READ | 1.663 | 1.666 | 1.608 | 1.716 | Seq Scan on `user_teams`, `players`; Bitmap Scan on `user_team_players` |
| **R08** | READ | 1.347 | 1.361 | 1.304 | 1.375 | Seq Scan on `user_teams`, `players` |
| **R09** | READ | 3.923 | 3.908 | 3.709 | 4.151 | Seq Scan on `wallet_transactions` |
| **R10** | READ | 4.425 | 4.439 | 4.386 | 4.451 | Seq Scan on `wallet_transactions` |
| **R11** | READ | 15.748 | 15.463 | 15.377 | 16.405 | Seq Scan on `contest_entries`, `contests`, `user_teams`, `users` |
| **R12** | READ | 1.583 | 1.582 | 1.569 | 1.599 | Seq Scan on `matches`; Bitmap Scan on `player_match_stats` |
| **R13** | READ | 13.267 | 13.368 | 12.771 | 13.661 | Seq Scan on `contest_entries`, `wallet_transactions`, `contests` |
| **R14** | READ | 9.419 | 9.347 | 9.193 | 9.717 | Seq Scan on `contests`, `matches`; Index Scan on `contest_entries` |
| **R15** | READ | 27.352 | 23.056 | 22.531 | 36.469 | Seq Scan on `contest_entries`, `user_teams`, `users` |
| **R16** | READ | 0.515 | 0.214 | 0.211 | 1.121 | Seq Scan on `players`; Index Scan on `teams` |
| **R17** | READ | 12.102 | 12.135 | 11.962 | 12.209 | Seq Scan on `contest_entries`, `user_teams` |
| **R18** | READ | 14.264 | 14.233 | 14.208 | 14.350 | Seq Scan on `wallet_transactions`; Index Scan on `users` |
| **R19** | READ | **2,345.981** | 2,344.058 | 2,178.120 | 2,515.764 | Seq Scan on `players`, `teams`, `user_team_players` |
| **R20** | READ | 4.542 | 4.541 | 4.532 | 4.552 | Seq Scan on `wallet_transactions` |
| **R21** | READ | 5.017 | 5.041 | 4.966 | 5.045 | Seq Scan on `user_teams`, `contest_entries`, `contests` |
| **R22** | READ | 22.933 | 22.939 | 22.741 | 23.120 | Seq Scan on `wallet_transactions` |
| **R23** | READ | 0.024 | 0.024 | 0.023 | 0.024 | Index Scan using `users_phone_key` on `users` |
| **R24** | READ | 1.136 | 1.129 | 1.092 | 1.187 | Seq Scan on `players`; Index Scan on `teams`, `player_match_stats` |
| **R25** | READ | 7.637 | 7.651 | 7.599 | 7.662 | Seq Scan on `wallet_transactions`, `contest_entries`, `user_teams`, `matches`, `contests` |
| **W01** | WRITE | 0.453 | 0.383 | 0.376 | 0.600 | Seq Scan on `matches` |
| **W02** | WRITE | 0.316 | 0.328 | 0.280 | 0.341 | Index Scan on `user_teams`; Seq Scan on `contests` |
| **W03** | WRITE | 0.315 | 0.316 | 0.296 | 0.333 | Index Only/Index Scan on `contest_entries`, `contests`, `user_teams` |
| **W04** | WRITE | 5.649 | 5.373 | 5.306 | 6.269 | Seq Scan on `user_teams`; Index Scan on `user_team_players`, `player_match_stats` |
| **W05** | WRITE | 4.811 | 4.435 | 4.434 | 5.563 | Seq Scan on `wallet_transactions` |

## 4. Root-Cause Bottleneck Classification
1. **Correlated Subquery Amplification (`R06` — 3,548 ms, `R19` — 2,346 ms):**
   - `R06` executes a `CROSS JOIN LATERAL` subquery for every `(user_team_id, player_id)` pair in match 183 (`11 × N` repeated joins on `user_team_players` and `players`), plus a full `Seq Scan` on `user_teams`.
   - `R19` executes a scalar correlated subquery `(SELECT count(*) FROM user_team_players utp WHERE utp.player_id = p.player_id)` once per player; because `(user_team_id, player_id)` leads with `user_team_id`, PostgreSQL performs a full `Seq Scan` over 439,925 rows hundreds of times.
2. **Missing Foreign-Key & Composite Filter Indexes (`R02`, `R09–R11`, `R15`, `R17`, `R18`, `R22`, `W04`, `W05`):**
   - `user_teams` lacks indexes on `(match_id)` and `(user_id, match_id)`, forcing full scans of 39,975 rows on every match-level or user-level lookup (`R02`, `R03`, `R06`, `R07`, `R08`, `W04`).
   - `wallet_transactions` lacks indexes on `(user_id, status, created_at)` and `(txn_type, status, created_at)`, causing repeated 118,343-row sequential scans (`R09`, `R10`, `R18`, `R20`, `R22`, `W05`).
   - `contest_entries` lacks indexes on `user_team_id` and `joined_at`, slowing down user-level aggregations (`R11`, `R15`, `R17`).
3. **Anti-Join & Sort Overhead (`R13` — 13.3 ms, `R22` — 22.9 ms):**
   - `R13` uses `NOT IN (SELECT w.reference_entry_id FROM wallet_transactions w)` without filtering `WHERE w.reference_entry_id IS NOT NULL` or using `NOT EXISTS`, preventing an efficient anti-join plan.
   - `R22` scans and sorts all 118,343 `wallet_transactions` rows by `created_at DESC` before applying `OFFSET 50000 LIMIT 25`.