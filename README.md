# upi-transaction-reconciliation
SQL project for UPI payment reconciliation, failure analysis, and financial anomaly detection
# 💳 UPI Transaction Reconciliation & Failure Analysis

### SQL Project | Fintech Data Analytics | PhonePe-Style System

---

## 📌 Problem Statement

In real-world UPI systems, **transaction logs** and **payment settlement systems** often go out of sync.

This leads to:

* Money debited but not settled
* Incorrect revenue reporting
* Customer complaints and refund issues

This project builds a **SQL-based reconciliation system** to detect and classify such discrepancies.

---

## 🎯 Objective

* Reconcile transaction and payment data
* Detect missing payments, mismatches, and failures
* Analyze failure patterns across time, apps, and banks
* Estimate financial risk from anomalies

---

## 📊 Dataset

* Source: Kaggle UPI Transactions Dataset
* Records: 2,035 transactions
* Users: 400
* Time Period: Jan 2024 – Dec 2024
* UPI Apps: PhonePe, Google Pay, Paytm, BHIM, CRED, Amazon Pay
* Banks: SBI, HDFC, ICICI, Axis, Kotak, PNB, BOB, Canara
* Total Volume: ₹1.83 Cr

🔗 Dataset Link:
https://www.kaggle.com/datasets/bijitda/upi-transactions-dataset

---

## 🔧 Data Transformation

The original dataset was enhanced to simulate a real-world fintech system:

* Created a `transactions` table (user-side logs)
* Created a `payments` table (settlement system)
* Injected realistic anomalies:

  * Missing payments
  * Amount mismatches
  * Failed transactions
  * Duplicate transactions

👉 This enabled building a **reconciliation system similar to PhonePe/Razorpay workflows**

---

## 🧱 Data Model

Two core tables:

* `transactions` → records user-initiated payments
* `payments` → records backend settlement

Both are linked using `transaction_id`.

---

## 🔧 SQL Techniques Used

* Joins (LEFT JOIN, INNER JOIN)
* CTEs (WITH clause)
* Window Functions (ROW_NUMBER, LAG, NTILE)
* CASE WHEN
* Aggregations with FILTER
* Date functions (EXTRACT, DATE_TRUNC)
* Views for clean data layer

---

## 🔍 Core Analysis

The system detects and classifies:

* Missing Payments → SUCCESS transactions with no payment record
* Amount Mismatch → transaction amount ≠ processed amount
* Failed Transactions → status = FAILED
* Duplicate Transactions → same user + amount within 5 minutes
* Status Conflicts → SUCCESS in transaction but FAILED in payment

---

## 📈 Key Insights

* Only **62% transactions** were fully valid
* **18.13% failure rate** (significantly high)
* ₹15.6L+ financial exposure identified
* 87 missing payments (₹7.7L at risk)
* Peak failures at **8 AM & 10 PM**
* Amazon Pay had highest failure rate (~22.5%)

---

## 💼 Business Impact

This project demonstrates how data analysts can:

* Detect revenue leakage and financial inconsistencies
* Improve payment success rates
* Support operations and finance teams
* Enable faster issue resolution in fintech systems

---

## 🚀 Tools Used

* SQL (PostgreSQL / DuckDB)
* Excel

---

## 🔮 Future Improvements

* Build Power BI dashboard for visualization
* Automate reconciliation using Python
* Implement real-time alerting system

---

## 👩‍💻 Author

Robina Shakwa

---

## ⭐ Project Highlight

Built a SQL-based reconciliation system inspired by real-world fintech workflows, identifying **₹15L+ financial risk and operational anomalies**.
