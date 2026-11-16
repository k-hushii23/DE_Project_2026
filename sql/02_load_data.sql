BEGIN;

\copy teams FROM 'seed_data/teams.csv' WITH (FORMAT csv, HEADER true);
\copy users FROM 'seed_data/users.csv' WITH (FORMAT csv, HEADER true);
\copy players FROM 'seed_data/players.csv' WITH (FORMAT csv, HEADER true);
\copy matches FROM 'seed_data/matches.csv' WITH (FORMAT csv, HEADER true);
\copy player_match_stats FROM 'seed_data/player_match_stats.csv' WITH (FORMAT csv, HEADER true);
\copy user_teams FROM 'seed_data/user_teams.csv' WITH (FORMAT csv, HEADER true);
\copy user_team_players FROM 'seed_data/user_team_players.csv' WITH (FORMAT csv, HEADER true);
\copy contests FROM 'seed_data/contests.csv' WITH (FORMAT csv, HEADER true);
\copy contest_entries FROM 'seed_data/contest_entries.csv' WITH (FORMAT csv, HEADER true);
\copy wallet_transactions FROM 'seed_data/wallet_transactions.csv' WITH (FORMAT csv, HEADER true);

COMMIT;

-- Verify loaded row counts against profile.py
SELECT 'teams' AS table_name, COUNT(*) AS row_count FROM teams
UNION ALL SELECT 'users', COUNT(*) FROM users
UNION ALL SELECT 'players', COUNT(*) FROM players
UNION ALL SELECT 'matches', COUNT(*) FROM matches
UNION ALL SELECT 'player_match_stats', COUNT(*) FROM player_match_stats
UNION ALL SELECT 'user_teams', COUNT(*) FROM user_teams
UNION ALL SELECT 'user_team_players', COUNT(*) FROM user_team_players
UNION ALL SELECT 'contests', COUNT(*) FROM contests
UNION ALL SELECT 'contest_entries', COUNT(*) FROM contest_entries
UNION ALL SELECT 'wallet_transactions', COUNT(*) FROM wallet_transactions
ORDER BY table_name;
