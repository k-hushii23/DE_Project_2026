DROP TABLE IF EXISTS wallet_transactions, contest_entries, contests, user_team_players, user_teams, player_match_stats, matches, players, teams, users CASCADE;

-- 1. Core Reference Tables
CREATE TABLE teams (
    team_id     INT PRIMARY KEY,
    team_name   VARCHAR(100) NOT NULL UNIQUE,
    short_name  VARCHAR(10)  NOT NULL UNIQUE,
    team_type   VARCHAR(20)  NOT NULL
);

CREATE TABLE users (
    user_id     INT PRIMARY KEY,
    username    VARCHAR(50)  NOT NULL UNIQUE,
    phone       VARCHAR(15)  NOT NULL UNIQUE,
    email       VARCHAR(120) UNIQUE,
    state_code  CHAR(2)      NOT NULL,
    kyc_status  VARCHAR(20)  NOT NULL,
    created_at  TIMESTAMPTZ  NOT NULL
);

CREATE TABLE players (
    player_id   INT PRIMARY KEY,
    full_name   VARCHAR(100) NOT NULL,
    team_id     INT          NOT NULL REFERENCES teams(team_id),
    role        VARCHAR(10)  NOT NULL,
    credits     NUMERIC(4,1) NOT NULL CHECK (credits > 0),
    is_active   BOOLEAN      NOT NULL
);

-- 2. Match & Performance Tables
CREATE TABLE matches (
    match_id      INT PRIMARY KEY,
    tournament    VARCHAR(50)  NOT NULL,
    home_team_id  INT          NOT NULL REFERENCES teams(team_id),
    away_team_id  INT          NOT NULL REFERENCES teams(team_id),
    venue         VARCHAR(100) NOT NULL,
    starts_at     TIMESTAMPTZ  NOT NULL,
    status        VARCHAR(20)  NOT NULL
);

CREATE TABLE player_match_stats (
    match_id        INT          NOT NULL REFERENCES matches(match_id),
    player_id       INT          NOT NULL REFERENCES players(player_id),
    runs            INT          NOT NULL DEFAULT 0,
    balls_faced     INT          NOT NULL DEFAULT 0,
    fours           INT          NOT NULL DEFAULT 0,
    sixes           INT          NOT NULL DEFAULT 0,
    wickets         INT          NOT NULL DEFAULT 0,
    catches         INT          NOT NULL DEFAULT 0,
    fantasy_points  NUMERIC(6,2) NOT NULL DEFAULT 0,
    PRIMARY KEY (match_id, player_id)
);

-- 3. Fantasy Team Roster Tables
CREATE TABLE user_teams (
    user_team_id     INT PRIMARY KEY,
    user_id          INT          NOT NULL REFERENCES users(user_id),
    match_id         INT          NOT NULL REFERENCES matches(match_id),
    team_label       VARCHAR(10)  NOT NULL,
    captain_id       INT          NOT NULL REFERENCES players(player_id),
    vice_captain_id  INT          NOT NULL REFERENCES players(player_id),
    total_points     NUMERIC(7,2),
    created_at       TIMESTAMPTZ  NOT NULL
);

CREATE TABLE user_team_players (
    user_team_id  INT NOT NULL REFERENCES user_teams(user_team_id),
    player_id     INT NOT NULL REFERENCES players(player_id),
    PRIMARY KEY (user_team_id, player_id)
);

-- 4. Contests & Financial Ledger Tables
CREATE TABLE contests (
    contest_id     INT PRIMARY KEY,
    match_id       INT           NOT NULL REFERENCES matches(match_id),
    contest_name   VARCHAR(100)  NOT NULL,
    contest_type   VARCHAR(20)   NOT NULL,
    entry_fee      NUMERIC(10,2) NOT NULL CHECK (entry_fee >= 0),
    total_spots    INT           NOT NULL CHECK (total_spots > 0),
    prize_pool     NUMERIC(12,2) NOT NULL CHECK (prize_pool >= 0),
    is_guaranteed  BOOLEAN       NOT NULL,
    invite_code    VARCHAR(20)
);

CREATE TABLE contest_entries (
    entry_id      INT PRIMARY KEY,
    contest_id    INT           NOT NULL REFERENCES contests(contest_id),
    user_team_id  INT           NOT NULL REFERENCES user_teams(user_team_id),
    joined_at     TIMESTAMPTZ   NOT NULL,
    final_rank    INT,
    winnings      NUMERIC(10,2) NOT NULL DEFAULT 0
);

CREATE TABLE wallet_transactions (
    txn_id              INT PRIMARY KEY,
    user_id             INT           NOT NULL REFERENCES users(user_id),
    txn_type            VARCHAR(30)   NOT NULL,
    amount              NUMERIC(10,2) NOT NULL,
    reference_entry_id  INT           REFERENCES contest_entries(entry_id),
    status              VARCHAR(20)   NOT NULL,
    created_at          TIMESTAMPTZ   NOT NULL
);

-- Performance Indexes on Foreign Keys & Frequent Filters
CREATE INDEX idx_players_team_id ON players(team_id);
CREATE INDEX idx_matches_starts_at ON matches(starts_at);
CREATE INDEX idx_user_teams_user_match ON user_teams(user_id, match_id);
CREATE INDEX idx_utp_player_id ON user_team_players(player_id);
CREATE INDEX idx_contests_match_id ON contests(match_id);
CREATE INDEX idx_contest_entries_contest ON contest_entries(contest_id);
CREATE INDEX idx_contest_entries_team ON contest_entries(user_team_id);
CREATE INDEX idx_wallet_txn_user_id ON wallet_transactions(user_id);
CREATE INDEX idx_wallet_txn_ref_entry ON wallet_transactions(reference_entry_id);
