SET search_path TO dream11;


-- 1. user_team_players: accelerates R02, R06, R19 (player-first lookups & covering count)
CREATE INDEX IF NOT EXISTS idx_utp_player_id ON user_team_players(player_id, user_team_id);


-- 2. user_teams: accelerates match-level and user+match lookups (R02, R03, R06, R07, R08, W04)
CREATE INDEX IF NOT EXISTS idx_user_teams_match_id ON user_teams(match_id);
CREATE INDEX IF NOT EXISTS idx_user_teams_user_match ON user_teams(user_id, match_id);


-- 3. contest_entries: accelerates user_team joins, time filters, and H2H win-rate (R04, R11, R15, R17, R21, R25)
CREATE INDEX IF NOT EXISTS idx_contest_entries_team_id ON contest_entries(user_team_id);
CREATE INDEX IF NOT EXISTS idx_contest_entries_joined_at ON contest_entries(joined_at);
CREATE INDEX IF NOT EXISTS idx_contest_entries_contest_rank ON contest_entries(contest_id, final_rank) WHERE final_rank IS NOT NULL;


-- 4. contests: accelerates match contest lookups and entry_fee filters (R01, R04, R11, R13, R21, W02)
CREATE INDEX IF NOT EXISTS idx_contests_match_type ON contests(match_id, contest_type);


-- 5. wallet_transactions: accelerates user statements, pending withdrawals, deposits, ref audits, and timeline pagination
CREATE INDEX IF NOT EXISTS idx_wallet_txn_user_status_created ON wallet_transactions(user_id, status, created_at, txn_id);
CREATE INDEX IF NOT EXISTS idx_wallet_txn_type_status_created ON wallet_transactions(txn_type, status, created_at);
CREATE INDEX IF NOT EXISTS idx_wallet_txn_ref_entry ON wallet_transactions(reference_entry_id) WHERE reference_entry_id IS NOT NULL;
CREATE INDEX IF NOT EXISTS idx_wallet_txn_created_desc ON wallet_transactions(created_at DESC);


-- 6. matches, players, users: accelerates status/tournament/state filters (R01, R11, R12, R14, R16, R24, R25)
CREATE INDEX IF NOT EXISTS idx_matches_status_starts ON matches(status, starts_at);
CREATE INDEX IF NOT EXISTS idx_matches_tournament ON matches(tournament);
CREATE INDEX IF NOT EXISTS idx_players_team_active ON players(team_id, is_active);
CREATE INDEX IF NOT EXISTS idx_users_state_code ON users(state_code) WHERE state_code IN ('AS', 'OD', 'TG', 'AP');


-- Refresh planner statistics after index creation
ANALYZE;