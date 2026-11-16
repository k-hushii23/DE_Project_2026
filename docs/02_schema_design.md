# 02 — Relational Schema Design & Architecture

## 1. Normalization & Modeling Strategy
The database is normalized to **Third Normal Form (3NF)** to eliminate update anomalies across high-frequency transactional workloads (team edits, contest joins, wallet credits) while maintaining clean star-like join paths for analytical queries.

- **Many-to-Many Resolution:** `user_team_players` resolves the M:N relationship between `user_teams` and `players` via a composite primary key `(user_team_id, player_id)`.
- **Match Box-Score Grain:** `player_match_stats` uses a natural composite primary key `(match_id, player_id)` to guarantee at most one performance record per player per match.
- **Ledger Decoupling:** `wallet_transactions` maintains a nullable foreign key (`reference_entry_id`) to `contest_entries(entry_id)` so both contest-linked cashflows and external wallet funding events coexist in a single unified ledger.

## 2. Entity-Relationship Overview

```text
teams (18)
 |--< players (450) --< player_match_stats (4,444) >-- matches (212)
 +--< matches (home_team_id, away_team_id)               |
                                                         +--< contests (2,544)
users (50,000)                                           |       |
 |--< user_teams (39,975) >------------------------------+       |
 |     |--< user_team_players (439,925) >-- players              |
 |     +--< contest_entries (42,746) >---------------------------+
 |               |
 +--< wallet_transactions (118,343) --(optional FK)--------------+
```

## 3. Data Type Decisions & Profiling Edge Cases
During CSV profiling (`profile.py`), several raw formatting behaviors required explicit DDL handling in `sql/01_schema.sql`:

1. **Nullable Integer Columns (`final_rank`, `reference_entry_id`):**
   - Pandas inferred these as `float64` because CSVs encode nullable integers alongside decimals (`1.0`). Defined as `INT` in PostgreSQL (`\copy` parses empty strings as `NULL`).
2. **10-Digit Phone Numbers (`users.phone`):**
   - Values such as `7300000001` exceed the 32-bit signed integer limit (`2,147,483,647`). Stored as `VARCHAR(15)` with a `UNIQUE` constraint to preserve leading zeros and formatting.
3. **Monetary & Scoring Precision:**
   - Financial fields (`entry_fee`, `prize_pool`, `winnings`, `amount`) use exact fixed-point `NUMERIC(10,2)` / `NUMERIC(12,2)` rather than floating-point `REAL`/`DOUBLE PRECISION` to prevent rounding drift in wallet reconciliation.
   - `fantasy_points` (`NUMERIC(6,2)`) and `total_points` (`NUMERIC(7,2)`) preserve fractional captaincy (`1.5x`) and bowling/economy points accurately.
4. **Timezone-Aware Timestamps:**
   - All event timestamps (`created_at`, `starts_at`, `joined_at`) include explicit IST offsets (`+05:30`) and are stored as `TIMESTAMPTZ`.

## 4. Indexing Strategy
PostgreSQL automatically creates B-tree indexes for all `PRIMARY KEY` and `UNIQUE` constraints. To prevent sequential scans on foreign-key joins and time-range filters, explicit B-tree indexes were added in `sql/01_schema.sql`:

| Index Name | Table & Column(s) | Primary Query Pattern Supported |
| :--- | :--- | :--- |
| `idx_players_team_id` | `players(team_id)` | Squad roster lookups by franchise/team |
| `idx_matches_starts_at` | `matches(starts_at)` | Chronological match schedules & time-window filtering |
| `idx_user_teams_user_match` | `user_teams(user_id, match_id)` | User match history & multi-team entry limits |
| `idx_utp_player_id` | `user_team_players(player_id)` | Player selection / ownership percentage calculations |
| `idx_contests_match_id` | `contests(match_id)` | Contest catalog retrieval per match |
| `idx_contest_entries_contest` | `contest_entries(contest_id)` | Contest leaderboards & fill-rate aggregations |
| `idx_contest_entries_team` | `contest_entries(user_team_id)` | Mapping fantasy squads to contest outcomes |
| `idx_wallet_txn_user_id` | `wallet_transactions(user_id)` | User wallet balance & transaction history statements |
| `idx_wallet_txn_ref_entry` | `wallet_transactions(reference_entry_id)` | Auditing entry fee debits vs. prize payouts per entry |