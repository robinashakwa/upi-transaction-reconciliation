-- =============================================================
-- FILE: 04_advanced_analysis.sql
-- PROJECT: UPI Transaction Reconciliation & Failure Analysis
-- PURPOSE: Window functions, CTEs, trend analysis, segmentation
-- =============================================================

-- ---------------------------------------------------------------
-- ANALYSIS 1: FAILURE RATE BY HOUR (Peak Failure Time)
-- ---------------------------------------------------------------
SELECT
    EXTRACT(HOUR FROM created_at)           AS hour_of_day,
    COUNT(*)                                AS total_transactions,
    COUNT(*) FILTER (WHERE status='FAILED') AS failed_count,
    ROUND(
        100.0 * COUNT(*) FILTER (WHERE status='FAILED') / COUNT(*),
        2
    )                                       AS failure_rate_pct,
    CASE
        WHEN EXTRACT(HOUR FROM created_at) BETWEEN 7  AND 10 THEN 'Morning Peak'
        WHEN EXTRACT(HOUR FROM created_at) BETWEEN 12 AND 14 THEN 'Afternoon Peak'
        WHEN EXTRACT(HOUR FROM created_at) BETWEEN 19 AND 22 THEN 'Evening Peak'
        ELSE 'Off-Peak'
    END                                     AS time_segment
FROM transactions
GROUP BY 1
ORDER BY failed_count DESC;


-- ---------------------------------------------------------------
-- ANALYSIS 2: FAILURE RATE BY DAY OF WEEK
-- ---------------------------------------------------------------
SELECT
    TO_CHAR(created_at, 'Day')  AS day_name,
    EXTRACT(DOW FROM created_at) AS dow_number,
    COUNT(*)                     AS total,
    COUNT(*) FILTER (WHERE status='FAILED') AS failed,
    ROUND(
        100.0 * COUNT(*) FILTER (WHERE status='FAILED') / COUNT(*),
        2
    )                            AS failure_rate_pct
FROM transactions
GROUP BY 1, 2
ORDER BY dow_number;


-- ---------------------------------------------------------------
-- ANALYSIS 3: DAILY TRANSACTION VOLUME & TREND
-- ---------------------------------------------------------------
WITH daily_stats AS (
    SELECT
        DATE(created_at)                             AS txn_date,
        COUNT(*)                                     AS total_txns,
        COUNT(*) FILTER (WHERE status='SUCCESS')     AS successful,
        COUNT(*) FILTER (WHERE status='FAILED')      AS failed,
        ROUND(SUM(amount) FILTER (WHERE status='SUCCESS'), 2) AS successful_volume_inr
    FROM transactions
    GROUP BY 1
),
daily_with_trend AS (
    SELECT
        txn_date,
        total_txns,
        successful,
        failed,
        successful_volume_inr,
        ROUND(AVG(total_txns) OVER (
            ORDER BY txn_date ROWS BETWEEN 6 PRECEDING AND CURRENT ROW
        ), 1)                                        AS rolling_7d_avg_txns,
        LAG(total_txns) OVER (ORDER BY txn_date)     AS prev_day_txns
    FROM daily_stats
)
SELECT
    *,
    total_txns - prev_day_txns                      AS day_over_day_change
FROM daily_with_trend
ORDER BY txn_date;


-- ---------------------------------------------------------------
-- ANALYSIS 4: USER-LEVEL RFM SEGMENTATION
-- (Recency, Frequency, Monetary — adapted for payment analytics)
-- ---------------------------------------------------------------
WITH user_metrics AS (
    SELECT
        user_id,
        COUNT(*)                                     AS frequency,
        ROUND(SUM(amount) FILTER (WHERE status='SUCCESS'), 2) AS monetary,
        MAX(created_at)                              AS last_txn_date,
        EXTRACT(DAY FROM (
            NOW() - MAX(created_at)
        ))                                           AS recency_days,
        COUNT(*) FILTER (WHERE status='FAILED')      AS failed_txns,
        ROUND(
            100.0 * COUNT(*) FILTER (WHERE status='FAILED') / COUNT(*),
            2
        )                                            AS personal_fail_rate
    FROM transactions
    GROUP BY user_id
),
rfm_scored AS (
    SELECT *,
        NTILE(5) OVER (ORDER BY recency_days)        AS recency_score,  -- lower days = higher value
        NTILE(5) OVER (ORDER BY frequency)           AS frequency_score,
        NTILE(5) OVER (ORDER BY monetary)            AS monetary_score
    FROM user_metrics
),
rfm_labeled AS (
    SELECT *,
        (6 - recency_score) + frequency_score + monetary_score AS rfm_total,
        CASE
            WHEN (6-recency_score) >= 4 AND frequency_score >= 4 AND monetary_score >= 4
                THEN 'Champion'
            WHEN (6-recency_score) >= 3 AND frequency_score >= 3
                THEN 'Loyal User'
            WHEN frequency_score <= 2 AND (6-recency_score) >= 3
                THEN 'New User'
            WHEN (6-recency_score) <= 2
                THEN 'At Risk'
            ELSE 'Potential Loyalist'
        END AS user_segment
    FROM rfm_scored
)
SELECT
    user_segment,
    COUNT(*)                    AS user_count,
    ROUND(AVG(frequency), 1)    AS avg_transactions,
    ROUND(AVG(monetary), 2)     AS avg_spend_inr,
    ROUND(AVG(personal_fail_rate), 2) AS avg_failure_rate_pct
FROM rfm_labeled
GROUP BY user_segment
ORDER BY avg_spend_inr DESC;


-- ---------------------------------------------------------------
-- ANALYSIS 5: ROLLING FAILURE RATE (7-DAY MOVING AVERAGE)
-- ---------------------------------------------------------------
WITH daily_failures AS (
    SELECT
        DATE(created_at)                           AS txn_date,
        COUNT(*)                                   AS total,
        COUNT(*) FILTER (WHERE status='FAILED')    AS failed
    FROM transactions
    GROUP BY 1
)
SELECT
    txn_date,
    total,
    failed,
    ROUND(100.0 * failed / total, 2)              AS daily_fail_pct,
    ROUND(
        AVG(100.0 * failed / total) OVER (
            ORDER BY txn_date ROWS BETWEEN 6 PRECEDING AND CURRENT ROW
        ),
        2
    )                                              AS rolling_7d_fail_rate
FROM daily_failures
ORDER BY txn_date;


-- ---------------------------------------------------------------
-- ANALYSIS 6: HIGH-VALUE TRANSACTION FAILURE ANALYSIS
-- Transactions > ₹10,000 — higher business impact if failed
-- ---------------------------------------------------------------
SELECT
    CASE
        WHEN amount < 1000   THEN '< ₹1,000'
        WHEN amount < 5000   THEN '₹1,000 – ₹5,000'
        WHEN amount < 10000  THEN '₹5,000 – ₹10,000'
        WHEN amount < 50000  THEN '₹10,000 – ₹50,000'
        ELSE '> ₹50,000'
    END                                                AS amount_bucket,
    COUNT(*)                                           AS total_txns,
    COUNT(*) FILTER (WHERE status='FAILED')            AS failed,
    ROUND(
        100.0 * COUNT(*) FILTER (WHERE status='FAILED') / COUNT(*),
        2
    )                                                  AS failure_rate_pct,
    ROUND(SUM(amount) FILTER (WHERE status='FAILED'), 2) AS failed_volume_inr
FROM transactions
GROUP BY 1
ORDER BY MIN(amount);


-- ---------------------------------------------------------------
-- ANALYSIS 7: STATUS CONFLICT DETECTION (Advanced)
-- Transactions marked SUCCESS in txn table but FAILED in payments
-- This is the most dangerous reconciliation failure type
-- ---------------------------------------------------------------
SELECT
    t.transaction_id,
    t.user_id,
    t.amount,
    t.status           AS txn_status,
    p.payment_status,
    t.upi_app,
    t.bank,
    t.created_at,
    p.processed_at,
    'CRITICAL: Status Conflict' AS alert_level
FROM transactions t
INNER JOIN payments p ON t.transaction_id = p.transaction_id
WHERE t.status = 'SUCCESS' AND p.payment_status = 'FAILED'
ORDER BY t.amount DESC;


-- ---------------------------------------------------------------
-- ANALYSIS 8: CITY-WISE FAILURE RATE
-- ---------------------------------------------------------------
SELECT
    city,
    COUNT(*)                                            AS total,
    COUNT(*) FILTER (WHERE status='FAILED')             AS failed,
    ROUND(
        100.0 * COUNT(*) FILTER (WHERE status='FAILED') / COUNT(*),
        2
    )                                                   AS failure_rate_pct,
    ROUND(SUM(amount), 2)                               AS total_volume_inr
FROM transactions
GROUP BY city
ORDER BY failure_rate_pct DESC;


-- ---------------------------------------------------------------
-- ANALYSIS 9: CATEGORY-WISE FAILURE BREAKDOWN
-- ---------------------------------------------------------------
SELECT
    category,
    COUNT(*)                                            AS total_txns,
    COUNT(*) FILTER (WHERE status='FAILED')             AS failed,
    ROUND(
        100.0 * COUNT(*) FILTER (WHERE status='FAILED') / COUNT(*),
        1
    )                                                   AS failure_rate_pct,
    ROUND(SUM(amount) FILTER (WHERE status='SUCCESS'), 2) AS successful_volume_inr
FROM transactions
GROUP BY category
ORDER BY failure_rate_pct DESC;


-- ---------------------------------------------------------------
-- ANALYSIS 10: COHORT ANALYSIS — User Retention by First-Month
-- ---------------------------------------------------------------
WITH user_first_txn AS (
    SELECT
        user_id,
        DATE_TRUNC('month', MIN(created_at)) AS cohort_month
    FROM transactions
    GROUP BY user_id
),
user_activity AS (
    SELECT
        t.user_id,
        uft.cohort_month,
        DATE_TRUNC('month', t.created_at) AS activity_month
    FROM transactions t
    JOIN user_first_txn uft ON t.user_id = uft.user_id
)
SELECT
    cohort_month,
    EXTRACT(MONTH FROM AGE(activity_month, cohort_month)) AS months_since_first,
    COUNT(DISTINCT user_id)                                AS active_users
FROM user_activity
GROUP BY 1, 2
ORDER BY cohort_month, months_since_first;
