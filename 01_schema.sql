-- =============================================================
-- FILE: 01_schema.sql
-- PROJECT: UPI Transaction Reconciliation & Failure Analysis
-- AUTHOR: Robina | PhonePe-Style SQL Project
-- =============================================================

-- ---------------------------------------------------------------
-- DROP TABLES (for re-runs)
-- ---------------------------------------------------------------
DROP TABLE IF EXISTS payments;
DROP TABLE IF EXISTS transactions;

-- ---------------------------------------------------------------
-- TABLE 1: transactions
-- Mirrors the raw UPI transaction log from a payment gateway
-- ---------------------------------------------------------------
CREATE TABLE transactions (
    transaction_id   VARCHAR(50)     PRIMARY KEY,
    user_id          VARCHAR(50)     NOT NULL,
    sender_upi       VARCHAR(100),
    receiver_upi     VARCHAR(100),
    amount           DECIMAL(12, 2)  NOT NULL,
    currency         CHAR(3)         DEFAULT 'INR',
    status           VARCHAR(20)     CHECK (status IN ('SUCCESS', 'FAILED', 'PENDING')),
    upi_app          VARCHAR(50),
    bank             VARCHAR(50),
    category         VARCHAR(50),
    created_at       TIMESTAMP       NOT NULL,
    device_type      VARCHAR(20),
    city             VARCHAR(50)
);

-- ---------------------------------------------------------------
-- TABLE 2: payments
-- Simulated settlement/payment processor table
-- In real systems (PhonePe/Razorpay) this is a separate service
-- ---------------------------------------------------------------
CREATE TABLE payments (
    payment_id       VARCHAR(50)     PRIMARY KEY,
    transaction_id   VARCHAR(50)     REFERENCES transactions(transaction_id),
    processed_amount DECIMAL(12, 2),
    payment_status   VARCHAR(20)     CHECK (payment_status IN ('SUCCESS', 'FAILED', 'PENDING')),
    processed_at     TIMESTAMP
);

-- ---------------------------------------------------------------
-- INDEXES for performance
-- ---------------------------------------------------------------
CREATE INDEX IF NOT EXISTS idx_txn_user    ON transactions(user_id);
CREATE INDEX IF NOT EXISTS idx_txn_status  ON transactions(status);
CREATE INDEX IF NOT EXISTS idx_txn_time    ON transactions(created_at);
CREATE INDEX IF NOT EXISTS idx_pay_txnid   ON payments(transaction_id);

-- ---------------------------------------------------------------
-- LOAD DATA (adjust path for your environment)
-- ---------------------------------------------------------------
-- For SQLite:
--   .mode csv
--   .import data/cleaned_transactions.csv transactions
--   .import data/payments.csv payments

-- For PostgreSQL:
--   COPY transactions FROM 'data/cleaned_transactions.csv' DELIMITER ',' CSV HEADER;
--   COPY payments FROM 'data/payments.csv' DELIMITER ',' CSV HEADER;

-- For MySQL:
--   LOAD DATA INFILE 'data/cleaned_transactions.csv'
--     INTO TABLE transactions FIELDS TERMINATED BY ',' IGNORE 1 ROWS;

-- Verify load
SELECT 'transactions' AS tbl, COUNT(*) AS row_count FROM transactions
UNION ALL
SELECT 'payments', COUNT(*) FROM payments;
