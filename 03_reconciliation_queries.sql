-- =============================================================
-- FILE: 03_reconciliation_queries.sql
-- PROJECT: UPI Transaction Reconciliation & Failure Analysis
-- PURPOSE: Identify mismatches, missing payments, failures
-- =============================================================

-- ---------------------------------------------------------------
-- QUERY 1: MISSING PAYMENTS
-- Transactions with no corresponding payment record
-- (Money debited from sender but no settlement initiated)
-- ---------------------------------------------------------------
SELECT
    t.transaction_id,
    t.user_id,
    t.amount,
    t.status            AS txn_status,
    t.upi_app,
    t.bank,
    t.created_at,
    'Missing Payment'   AS issue_type
FROM transactions t
LEFT JOIN payments p
    ON t.transaction_id = p.transaction_id
WHERE p.transaction_id IS NULL
  AND t.status = 'SUCCESS'      -- Expected to have settlement
ORDER BY t.amount DESC;

-- Count summary
SELECT COUNT(*) AS missing_payment_count
FROM transactions t
LEFT JOIN payments p ON t.transaction_id = p.transaction_id
WHERE p.transaction_id IS NULL AND t.status = 'SUCCESS';


-- ---------------------------------------------------------------
-- QUERY 2: FAILED TRANSACTIONS ANALYSIS
-- ---------------------------------------------------------------

-- 2a. All failed transactions
SELECT
    transaction_id,
    user_id,
    amount,
    upi_app,
    bank,
    city,
    created_at,
    EXTRACT(HOUR FROM created_at) AS failure_hour
FROM transactions
WHERE status = 'FAILED'
ORDER BY created_at;

-- 2b. Failure rate overall
SELECT
    COUNT(*)                                                          AS total_transactions,
    COUNT(*) FILTER (WHERE status = 'FAILED')                        AS failed_count,
    COUNT(*) FILTER (WHERE status = 'SUCCESS')                       AS success_count,
    COUNT(*) FILTER (WHERE status = 'PENDING')                       AS pending_count,
    ROUND(
        100.0 * COUNT(*) FILTER (WHERE status = 'FAILED') / COUNT(*),
        2
    )                                                                 AS failure_rate_pct
FROM transactions;

-- 2c. Failure rate by UPI App
SELECT
    upi_app,
    COUNT(*)                                                          AS total,
    COUNT(*) FILTER (WHERE status = 'FAILED')                        AS failed,
    ROUND(
        100.0 * COUNT(*) FILTER (WHERE status = 'FAILED') / COUNT(*),
        2
    )                                                                 AS failure_rate_pct
FROM transactions
GROUP BY upi_app
ORDER BY failure_rate_pct DESC;

-- 2d. Failure rate by Bank
SELECT
    bank,
    COUNT(*)                                                          AS total,
    COUNT(*) FILTER (WHERE status = 'FAILED')                        AS failed,
    ROUND(
        100.0 * COUNT(*) FILTER (WHERE status = 'FAILED') / COUNT(*),
        2
    )                                                                 AS failure_rate_pct
FROM transactions
GROUP BY bank
ORDER BY failure_rate_pct DESC;


-- ---------------------------------------------------------------
-- QUERY 3: AMOUNT MISMATCH
-- Transaction amount ≠ processed amount in payment record
-- (Revenue leakage / accounting discrepancy)
-- ---------------------------------------------------------------
SELECT
    t.transaction_id,
    t.user_id,
    t.amount                        AS transaction_amount,
    p.processed_amount,
    ROUND(t.amount - p.processed_amount, 2)  AS variance,
    t.status                        AS txn_status,
    p.payment_status,
    t.upi_app,
    t.bank,
    t.created_at
FROM transactions t
INNER JOIN payments p
    ON t.transaction_id = p.transaction_id
WHERE ROUND(t.amount, 2) != ROUND(p.processed_amount, 2)
ORDER BY ABS(t.amount - p.processed_amount) DESC;

-- Total revenue at risk from mismatches
SELECT
    COUNT(*)                                       AS mismatch_count,
    ROUND(SUM(ABS(t.amount - p.processed_amount)), 2) AS total_variance_inr
FROM transactions t
INNER JOIN payments p ON t.transaction_id = p.transaction_id
WHERE ROUND(t.amount, 2) != ROUND(p.processed_amount, 2);


-- ---------------------------------------------------------------
-- QUERY 4: DUPLICATE TRANSACTION DETECTION
-- Same user + same amount within 5-minute window (window functions)
-- ---------------------------------------------------------------
WITH ranked_txns AS (
    SELECT
        transaction_id,
        user_id,
        amount,
        status,
        created_at,
        ROW_NUMBER() OVER (
            PARTITION BY user_id, amount
            ORDER BY created_at
        ) AS rn,
        LAG(created_at) OVER (
            PARTITION BY user_id, amount
            ORDER BY created_at
        ) AS prev_txn_time
    FROM transactions
),
duplicates AS (
    SELECT
        transaction_id,
        user_id,
        amount,
        status,
        created_at,
        prev_txn_time,
        EXTRACT(EPOCH FROM (created_at - prev_txn_time)) AS seconds_since_prev
    FROM ranked_txns
    WHERE rn > 1
      AND EXTRACT(EPOCH FROM (created_at - prev_txn_time)) < 300  -- 5 min window
)
SELECT
    transaction_id,
    user_id,
    amount,
    status,
    created_at,
    prev_txn_time,
    ROUND(seconds_since_prev::NUMERIC, 0)  AS seconds_apart,
    'Suspected Duplicate'                   AS flag
FROM duplicates
ORDER BY user_id, created_at;

-- Count of suspected duplicates
SELECT COUNT(*) AS suspected_duplicates FROM (
    WITH ranked_txns AS (
        SELECT transaction_id, user_id, amount, created_at,
               ROW_NUMBER() OVER (PARTITION BY user_id, amount ORDER BY created_at) AS rn,
               LAG(created_at) OVER (PARTITION BY user_id, amount ORDER BY created_at) AS prev_txn_time
        FROM transactions
    )
    SELECT transaction_id
    FROM ranked_txns
    WHERE rn > 1 AND EXTRACT(EPOCH FROM (created_at - prev_txn_time)) < 300
) sub;


-- ---------------------------------------------------------------
-- QUERY 5: DELAYED PAYMENT PROCESSING
-- created_at → processed_at gap > 60 seconds is flagged
-- ---------------------------------------------------------------
SELECT
    t.transaction_id,
    t.user_id,
    t.amount,
    t.created_at,
    p.processed_at,
    ROUND(
        EXTRACT(EPOCH FROM (p.processed_at - t.created_at))::NUMERIC,
        2
    ) AS processing_seconds,
    CASE
        WHEN EXTRACT(EPOCH FROM (p.processed_at - t.created_at)) > 60  THEN 'High Delay'
        WHEN EXTRACT(EPOCH FROM (p.processed_at - t.created_at)) > 30  THEN 'Moderate Delay'
        ELSE 'Normal'
    END AS delay_category,
    t.upi_app,
    t.bank
FROM transactions t
INNER JOIN payments p ON t.transaction_id = p.transaction_id
ORDER BY processing_seconds DESC;

-- Average processing time by UPI app
SELECT
    t.upi_app,
    ROUND(AVG(EXTRACT(EPOCH FROM (p.processed_at - t.created_at)))::NUMERIC, 2) AS avg_processing_sec,
    COUNT(*) AS payment_count
FROM transactions t
JOIN payments p ON t.transaction_id = p.transaction_id
GROUP BY t.upi_app
ORDER BY avg_processing_sec DESC;


-- ---------------------------------------------------------------
-- QUERY 6: MASTER RECONCILIATION REPORT
-- Single query capturing ALL anomaly types
-- ---------------------------------------------------------------
SELECT
    t.transaction_id,
    t.user_id,
    t.amount                                AS txn_amount,
    p.processed_amount,
    ROUND(t.amount - COALESCE(p.processed_amount, 0), 2) AS variance,
    t.status                                AS txn_status,
    p.payment_status,
    t.upi_app,
    t.bank,
    t.city,
    t.created_at,
    p.processed_at,
    CASE
        WHEN p.transaction_id IS NULL AND t.status = 'SUCCESS'
            THEN 'Missing Payment'
        WHEN ROUND(t.amount, 2) != ROUND(p.processed_amount, 2)
            THEN 'Amount Mismatch'
        WHEN t.status = 'FAILED'
            THEN 'Failed Transaction'
        WHEN t.status = 'PENDING' AND p.payment_status IS NULL
            THEN 'Pending — No Payment Record'
        WHEN t.status = 'SUCCESS' AND p.payment_status = 'FAILED'
            THEN 'Status Conflict — Txn Success / Payment Failed'
        ELSE 'Valid'
    END AS reconciliation_status
FROM transactions t
LEFT JOIN payments p ON t.transaction_id = p.transaction_id
ORDER BY reconciliation_status, t.created_at;

-- Reconciliation summary
SELECT
    reconciliation_status,
    COUNT(*)                        AS record_count,
    ROUND(SUM(t.amount), 2)        AS total_amount_inr,
    ROUND(100.0 * COUNT(*) / SUM(COUNT(*)) OVER (), 2) AS pct_of_total
FROM (
    SELECT
        t.transaction_id,
        t.amount,
        CASE
            WHEN p.transaction_id IS NULL AND t.status = 'SUCCESS' THEN 'Missing Payment'
            WHEN ROUND(t.amount, 2) != ROUND(p.processed_amount, 2) THEN 'Amount Mismatch'
            WHEN t.status = 'FAILED' THEN 'Failed Transaction'
            WHEN t.status = 'PENDING' AND p.payment_status IS NULL THEN 'Pending — No Record'
            WHEN t.status = 'SUCCESS' AND p.payment_status = 'FAILED' THEN 'Status Conflict'
            ELSE 'Valid'
        END AS reconciliation_status
    FROM transactions t
    LEFT JOIN payments p ON t.transaction_id = p.transaction_id
) sub
GROUP BY reconciliation_status
ORDER BY record_count DESC;
