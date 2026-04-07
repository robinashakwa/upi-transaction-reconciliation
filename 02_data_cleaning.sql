-- =============================================================
-- FILE: 02_data_cleaning.sql
-- PROJECT: UPI Transaction Reconciliation & Failure Analysis
-- PURPOSE: Audit raw data, document anomalies, produce clean view
-- =============================================================

-- ---------------------------------------------------------------
-- STEP 1: RAW DATA AUDIT
-- ---------------------------------------------------------------

-- 1a. Total record count
SELECT COUNT(*) AS total_raw_records FROM transactions;

-- 1b. Null check across key columns
SELECT
    COUNT(*) FILTER (WHERE transaction_id IS NULL)  AS null_transaction_id,
    COUNT(*) FILTER (WHERE user_id IS NULL)         AS null_user_id,
    COUNT(*) FILTER (WHERE amount IS NULL)          AS null_amount,
    COUNT(*) FILTER (WHERE status IS NULL)          AS null_status,
    COUNT(*) FILTER (WHERE created_at IS NULL)      AS null_created_at
FROM transactions;

-- 1c. Status distribution (catch non-standard values)
SELECT status, COUNT(*) AS count
FROM transactions
GROUP BY status
ORDER BY count DESC;

-- 1d. Amount sanity check (negative or zero values)
SELECT
    COUNT(*) FILTER (WHERE amount <= 0) AS invalid_amounts,
    MIN(amount)                          AS min_amount,
    MAX(amount)                          AS max_amount,
    ROUND(AVG(amount), 2)               AS avg_amount
FROM transactions;

-- ---------------------------------------------------------------
-- STEP 2: DUPLICATE DETECTION
-- ---------------------------------------------------------------

-- 2a. Exact transaction_id duplicates
SELECT transaction_id, COUNT(*) AS dup_count
FROM transactions
GROUP BY transaction_id
HAVING COUNT(*) > 1
ORDER BY dup_count DESC;

-- 2b. Suspected duplicate transactions
-- Same user + same amount within 5-minute window
SELECT
    t1.transaction_id   AS original_txn,
    t2.transaction_id   AS duplicate_txn,
    t1.user_id,
    t1.amount,
    t1.created_at       AS original_time,
    t2.created_at       AS duplicate_time,
    ROUND(
        (EXTRACT(EPOCH FROM (t2.created_at - t1.created_at)) / 60.0)::NUMERIC,
        2
    )                   AS minutes_apart
FROM transactions t1
JOIN transactions t2
    ON  t1.user_id  = t2.user_id
    AND t1.amount   = t2.amount
    AND t1.transaction_id < t2.transaction_id
    AND ABS(EXTRACT(EPOCH FROM (t2.created_at - t1.created_at))) < 300
ORDER BY t1.user_id, t1.amount;

-- ---------------------------------------------------------------
-- STEP 3: CLEANED VIEW
-- (Use this view downstream; raw table stays untouched)
-- ---------------------------------------------------------------
CREATE OR REPLACE VIEW v_clean_transactions AS
SELECT
    transaction_id,
    user_id,
    sender_upi,
    receiver_upi,
    ROUND(amount, 2)                          AS amount,
    currency,
    UPPER(TRIM(status))                       AS status,
    upi_app,
    bank,
    category,
    CAST(created_at AS TIMESTAMP)             AS created_at,
    device_type,
    city
FROM transactions
WHERE transaction_id IS NOT NULL
  AND amount > 0
  AND status IN ('SUCCESS', 'FAILED', 'PENDING');

-- Verify clean view
SELECT status, COUNT(*) AS count
FROM v_clean_transactions
GROUP BY status;

-- ---------------------------------------------------------------
-- STEP 4: DATA QUALITY SUMMARY REPORT
-- ---------------------------------------------------------------
SELECT
    (SELECT COUNT(*) FROM transactions)                           AS total_raw,
    (SELECT COUNT(*) FROM v_clean_transactions)                   AS total_clean,
    (SELECT COUNT(*) FROM transactions) -
    (SELECT COUNT(*) FROM v_clean_transactions)                   AS records_excluded,
    (SELECT COUNT(*) FILTER (WHERE amount <= 0) FROM transactions) AS zero_neg_amounts,
    (SELECT COUNT(*) FILTER (WHERE status IS NULL) FROM transactions) AS null_statuses;
