# 💳 UPI Transaction Reconciliation & Failure Analysis
### A PhonePe-Style SQL Project | Data Analyst Portfolio

---

## 📌 Overview

This project simulates a PhonePe-like UPI payment system to perform **data reconciliation** between transaction records and payment settlement records. The goal is to ensure financial data accuracy, detect operational failures, and support revenue assurance — exactly the kind of work done by Data/Operations Analysts at UPI-scale fintech companies.

> **Interview Statement:** *"I built a UPI transaction reconciliation system using SQL, where I compared transaction and payment data to identify mismatches, failed payments, and duplicates — similar to systems used at PhonePe and Razorpay for financial operations analytics."*

---

## 📊 Dataset

| Detail | Info |
|--------|------|
| Source | Kaggle — [UPI Transactions Dataset](https://www.kaggle.com/datasets/bijitda/upi-transactions-dataset) |
| Records | 2,035 transactions (cleaned) |
| Time Period | January – December 2024 |
| Apps Covered | PhonePe, Google Pay, Paytm, BHIM, CRED, Amazon Pay |
| Banks | SBI, HDFC, ICICI, Axis, Kotak, PNB, BOB, Canara |
| Cities | Bengaluru, Mumbai, Delhi, Hyderabad, Chennai, Pune, Kolkata, Ahmedabad |

---

## 🎯 Problem Statement

In a real UPI payment system, two separate databases exist:

1. **Transaction Log** — records every payment initiated by the user
2. **Payment Processor** — records whether money was actually settled

**When these two don't match, it creates:**
- Revenue leakage (amount mismatches)
- Customer disputes (debited but not received)
- Regulatory non-compliance (inaccurate MIS reports)
- Double charges (duplicates)

This project identifies and classifies all such anomalies.

---

## 📁 Project Structure

```
upi-reconciliation-sql-project/
│
├── data/
│   ├── raw_transactions.csv         ← Original dataset (with injected anomalies)
│   ├── cleaned_transactions.csv     ← After data cleaning
│   └── payments.csv                 ← Simulated payment processor table
│
├── sql/
│   ├── 01_schema.sql                ← Table definitions + indexes
│   ├── 02_data_cleaning.sql         ← Null handling, deduplication, views
│   ├── 03_reconciliation_queries.sql← Core reconciliation logic
│   └── 04_advanced_analysis.sql     ← Window functions, CTEs, trend analysis
│
├── insights/
│   └── findings.md                  ← Business insights from query results
│
└── README.md
```

---

## 🧱 Schema Design

### `transactions` table
Mirrors the UPI payment gateway transaction log — one row per initiated payment.

```sql
CREATE TABLE transactions (
    transaction_id   VARCHAR(50)    PRIMARY KEY,
    user_id          VARCHAR(50)    NOT NULL,
    sender_upi       VARCHAR(100),
    receiver_upi     VARCHAR(100),
    amount           DECIMAL(12,2)  NOT NULL,
    currency         CHAR(3)        DEFAULT 'INR',
    status           VARCHAR(20),   -- SUCCESS / FAILED / PENDING
    upi_app          VARCHAR(50),
    bank             VARCHAR(50),
    category         VARCHAR(50),
    created_at       TIMESTAMP,
    device_type      VARCHAR(20),
    city             VARCHAR(50)
);
```

### `payments` table
Simulates the payment processor / settlement system — derived from transactions to introduce realistic mismatches.

```sql
CREATE TABLE payments (
    payment_id       VARCHAR(50)    PRIMARY KEY,
    transaction_id   VARCHAR(50)    REFERENCES transactions(transaction_id),
    processed_amount DECIMAL(12,2),
    payment_status   VARCHAR(20),
    processed_at     TIMESTAMP
);
```

**Intentional discrepancies introduced:**
- 87 SUCCESS transactions with no payment record (missing payments)
- 167 amount mismatches between tables
- 80 status conflicts (txn=SUCCESS, payment=FAILED)
- 40 suspected duplicates within 5-minute windows

---

## 🔧 SQL Techniques Used

| Technique | Where Used |
|-----------|------------|
| `LEFT JOIN` | Missing payment detection |
| `INNER JOIN` | Amount mismatch analysis |
| `CTEs` | Duplicate detection, RFM segmentation, cohort analysis |
| `Window Functions` | `ROW_NUMBER()`, `LAG()`, `NTILE()`, rolling averages |
| `CASE WHEN` | Reconciliation status classification |
| `FILTER (WHERE ...)` | Conditional aggregations |
| `DATE_TRUNC` | Daily/monthly trend analysis |
| `EXTRACT` | Hour-of-day, day-of-week failure patterns |
| `CREATE VIEW` | Reusable clean data layer |
| `COALESCE` | NULL-safe calculations |

---

## 🔥 Key Reconciliation Findings

| Issue | Count | Business Impact |
|-------|-------|-----------------|
| ✅ Valid Transactions | 1,271 (62.5%) | — |
| ❌ Failed Transactions | 264 (13.0%) | User experience & NPS |
| ⚠️ Amount Mismatch | 167 (8.2%) | ₹7,94,127 variance |
| 🔄 Pending — No Record | 166 (8.2%) | Unresolved liabilities |
| 🚫 Missing Payments | 87 (4.3%) | ₹7,70,058 at risk |
| 🔴 Status Conflicts | 80 (3.9%) | Highest priority — manual review needed |

### Critical Insights

- **Overall failure rate: 18.13%** — driven by bank-side API overloads during peak hours
- **Peak failure window: 8 AM (20.0%)** — morning commute payments hitting gateway limits
- **Amazon Pay highest failure rate: 22.57%** — needs integration audit
- **BOB bank: 20.61% failure rate** vs HDFC at 15.64% — clear infrastructure gap
- **Processing SLA:** Average 25.2 seconds; maximum 290 seconds (5x above acceptable threshold)

---

## 📈 Master Reconciliation Query

The single query that classifies every transaction in the system:

```sql
SELECT
    t.transaction_id,
    t.user_id,
    t.amount                                AS txn_amount,
    p.processed_amount,
    t.status                                AS txn_status,
    p.payment_status,
    CASE
        WHEN p.transaction_id IS NULL AND t.status = 'SUCCESS'
            THEN 'Missing Payment'
        WHEN ROUND(t.amount, 2) != ROUND(p.processed_amount, 2)
            THEN 'Amount Mismatch'
        WHEN t.status = 'FAILED'
            THEN 'Failed Transaction'
        WHEN t.status = 'SUCCESS' AND p.payment_status = 'FAILED'
            THEN 'Status Conflict'
        ELSE 'Valid'
    END AS reconciliation_status
FROM transactions t
LEFT JOIN payments p ON t.transaction_id = p.transaction_id;
```

---

## 💼 Business Impact

1. **₹15,64,185+ in financial exposure** identified across missing payments and mismatches
2. **Peak-hour failure patterns** can guide engineering teams to scale gateway capacity proactively
3. **Duplicate detection logic** can be productionised as a real-time idempotency check
4. **Status conflict cases** (80 transactions) need immediate ops escalation — highest risk of double-debit or missed settlement
5. **Bank-level failure analysis** gives vendor management teams data to negotiate SLAs

---

## 🚀 How to Run

### Option A: DuckDB (recommended — no setup)
```python
import duckdb
import pandas as pd

con = duckdb.connect()
con.execute("CREATE TABLE transactions AS SELECT * FROM read_csv_auto('data/cleaned_transactions.csv')")
con.execute("CREATE TABLE payments AS SELECT * FROM read_csv_auto('data/payments.csv')")

# Now run any query from the sql/ folder
```

### Option B: SQLite
```bash
sqlite3 upi.db
.mode csv
.import data/cleaned_transactions.csv transactions
.import data/payments.csv payments
.read sql/03_reconciliation_queries.sql
```

### Option C: PostgreSQL
```sql
COPY transactions FROM 'data/cleaned_transactions.csv' DELIMITER ',' CSV HEADER;
COPY payments FROM 'data/payments.csv' DELIMITER ',' CSV HEADER;
```

---

## 🔮 Next Steps

- [ ] Power BI dashboard on top of reconciliation output (killer combo for portfolio)
- [ ] Python + pandas pipeline to auto-flag anomalies daily
- [ ] Stored procedures for scheduled reconciliation jobs
- [ ] Email alert simulation for Status Conflict cases

---

## 👩‍💻 Author

**Robina** | Data Analyst | Bengaluru  
*Portfolio Project — Built for Placement Preparation*  
*Tools: SQL (PostgreSQL/DuckDB), Python, pandas*
