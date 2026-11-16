# 01 — Problem Understanding & Domain Analysis

## 1. System Overview
The **Dream11 Fantasy Sports Data Engineering Platform (`dream11_db`)** models an end-to-end fantasy cricket ecosystem supporting user onboarding, real-world match telemetry, custom 11-player fantasy squad construction, multi-tier contest participation, and double-entry style wallet ledger tracking.

## 2. Scale & Data Volume Summary
Based on initial profiling (`profile.py`) across 10 relational entities (~698,255 total records):

| Entity | Row Count | Grain / Primary Key | Key Observations |
| :--- | :---: | :--- | :--- |
| `teams` | 18 | `team_id` | Franchise & national cricket teams (`FRANCHISE`, etc.). |
| `players` | 450 | `player_id` | 25 players per team across 4 roles (`WK`, `BAT`, `AR`, `BOWL`); credits range around 6.5–10.5. |
| `matches` | 212 | `match_id` | Spans 5 tournaments (e.g., `IPL 2025`) across 17 venues; statuses include `COMPLETED`, etc. |
| `player_match_stats` | 4,444 | `(match_id, player_id)` | Box-score performance (runs, balls, 4s, 6s, wickets, catches) and computed `fantasy_points` across 202 completed/active matches. |
| `users` | 50,000 | `user_id` | Registered platform users across 17 Indian states (`state_code`) with KYC states (`PENDING`, `VERIFIED`, `REJECTED`). ~39.9% (`19,935`) lack email addresses. |
| `user_teams` | 39,975 | `user_team_id` | User-created squads (`T1`, `T2`, `T3`) per match with designated `captain_id` (2x points) and `vice_captain_id` (1.5x points). `2,098` teams have `NULL` `total_points` (upcoming/unscored matches). |
| `user_team_players` | 439,925 | `(user_team_id, player_id)` | Bridge table mapping exactly **11 players per squad** (`39,975 × 11 = 439,925`). |
| `contests` | 2,544 | `contest_id` | 12 contests per match (`212 × 12 = 2,544`) across 4 types (`MEGA`, etc.). `424` private contests include an `invite_code`; `2,120` public contests have `NULL`. |
| `contest_entries` | 42,746 | `entry_id` | Participation records linking a `user_team_id` to a `contest_id`. `2,125` entries have `NULL` `final_rank` (unsettled/live matches). |
| `wallet_transactions` | 118,343 | `txn_id` | Financial ledger tracking 6 transaction types (`DEPOSIT`, `ENTRY_FEE`, `WINNING`, `REFUND`, `WITHDRAWAL`, `BONUS`). `63,000` non-contest rows have `NULL` `reference_entry_id`. |

## 3. Core Business Rules & Domain Mechanics
1. **Squad Composition:** Every `user_team` consists of exactly 11 distinct players (`user_team_players`) selected from the two competing teams in a given `match_id`, designating one `captain_id` and one `vice_captain_id`.
2. **Match Lifecycle & Null Semantics:**
   - Matches that have not concluded (`UPCOMING` / `LIVE` / `ABANDONED`) result in `NULL` values for `user_teams.total_points` (2,098 rows) and `contest_entries.final_rank` (2,125 rows).
   - `NULL` in these columns represents **unsettled state**, not missing/corrupt data.
3. **Contest & Prize Economics:**
   - Each match hosts 12 contests (`2,544` total). Guaranteed contests (`is_guaranteed = true`) pay out the full `prize_pool` regardless of fill rate, whereas non-guaranteed contests depend on spot occupancy.
4. **Financial Auditability:**
   - Every contest entry fee debit, prize payout credit, or refund links back to `contest_entries(entry_id)` via `wallet_transactions.reference_entry_id`.
   - Standalone deposits and withdrawals leave `reference_entry_id` as `NULL`.

## 4. Analytical & Engineering Objectives
- **Transactional Integrity:** Enforce strict relational constraints, domain checks (`credits > 0`, `entry_fee >= 0`), and timezone-aware timestamps (`TIMESTAMPTZ` in `+05:30` IST).
- **Query Performance:** Support low-latency analytical aggregations across high-cardinality join paths (`users → user_teams → user_team_players → player_match_stats` and `contests → contest_entries → wallet_transactions`).
- **Operational Observability:** Enable leaderboards, player ownership/captaincy rates, contest fill-rate & rake profitability analysis, and user wallet balance reconciliation.
