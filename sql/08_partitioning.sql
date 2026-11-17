SET search_path TO dream11;


-- Declarative RANGE Partitioning on wallet_transactions by created_at
-- Note: PostgreSQL requires the partition key (created_at) to be part of every PRIMARY KEY / UNIQUE constraint.


DROP TABLE IF EXISTS wallet_transactions_partitioned CASCADE;


CREATE TABLE wallet_transactions_partitioned (
    txn_id              INT           NOT NULL,
    user_id             INT           NOT NULL REFERENCES users(user_id),
    txn_type            VARCHAR(30)   NOT NULL,
    amount              NUMERIC(10,2) NOT NULL,
    reference_entry_id  INT           REFERENCES contest_entries(entry_id),
    status              VARCHAR(20)   NOT NULL,
    created_at          TIMESTAMPTZ   NOT NULL,
    PRIMARY KEY (txn_id, created_at)
) PARTITION BY RANGE (created_at);


-- Half-year partitions covering historical 2025, 2026 H1/H2, and 2027+ growth
CREATE TABLE wallet_txn_2025_h1 PARTITION OF wallet_transactions_partitioned
    FOR VALUES FROM ('2025-01-01 00:00:00+05:30') TO ('2025-07-01 00:00:00+05:30');


CREATE TABLE wallet_txn_2025_h2 PARTITION OF wallet_transactions_partitioned
    FOR VALUES FROM ('2025-07-01 00:00:00+05:30') TO ('2026-01-01 00:00:00+05:30');


CREATE TABLE wallet_txn_2026_h1 PARTITION OF wallet_transactions_partitioned
    FOR VALUES FROM ('2026-01-01 00:00:00+05:30') TO ('2026-07-01 00:00:00+05:30');


CREATE TABLE wallet_txn_2026_h2 PARTITION OF wallet_transactions_partitioned
    FOR VALUES FROM ('2026-07-01 00:00:00+05:30') TO ('2027-01-01 00:00:00+05:30');


CREATE TABLE wallet_txn_default PARTITION OF wallet_transactions_partitioned DEFAULT;


-- Partition-local B-tree indexes (automatically propagated to every child partition)
CREATE INDEX idx_part_wallet_user_status_created
    ON wallet_transactions_partitioned (user_id, status, created_at, txn_id);


CREATE INDEX idx_part_wallet_type_status_created
    ON wallet_transactions_partitioned (txn_type, status, created_at);


CREATE INDEX idx_part_wallet_ref_entry
    ON wallet_transactions_partitioned (reference_entry_id)
    WHERE reference_entry_id IS NOT NULL;


CREATE INDEX idx_part_wallet_created_desc
    ON wallet_transactions_partitioned (created_at DESC);


-- Load existing ledger rows into partitioned table & update planner stats
INSERT INTO wallet_transactions_partitioned
SELECT txn_id, user_id, txn_type, amount, reference_entry_id, status, created_at
FROM wallet_transactions;


ANALYZE wallet_transactions_partitioned;


-- Demonstrate Partition Pruning on June 2026 Deposit Query (R20) — scans ONLY wallet_txn_2026_h1
EXPLAIN (ANALYZE, BUFFERS)
SELECT created_at::date AS day, sum(amount) AS deposits
FROM wallet_transactions_partitioned
WHERE txn_type = 'DEPOSIT'
  AND status = 'SUCCESS'
  AND created_at >= TIMESTAMPTZ '2026-06-01 00:00:00+05:30'
  AND created_at <  TIMESTAMPTZ '2026-07-01 00:00:00+05:30'
GROUP BY 1
ORDER BY 1;