# 📊 Findings & Business Insights
## UPI Transaction Reconciliation & Failure Analysis — PhonePe-Style SQL Project

---

## 🔢 Dataset Overview

| Metric | Value |
|--------|-------|
| Total Transactions Analysed | 2,035 |
| Successful Transactions | 1,462 (71.9%) |
| Failed Transactions | 369 (18.1%) |
| Pending Transactions | 204 (10.0%) |
| Total Transaction Volume | ₹1,83,93,237.71 |
| Date Range | Jan 2024 – Dec 2024 |
| Unique Users | 400 |
| UPI Apps Covered | 6 (PhonePe, Google Pay, Paytm, BHIM, CRED, Amazon Pay) |
| Banks Covered | 8 |

---

## 🚨 Critical Reconciliation Findings

### Finding 1: Overall Failure Rate — 18.13%

> **"18.13% of all UPI transactions failed — well above the RBI-noted industry benchmark of ~0.5%, indicating a simulated high-stress payment environment with multiple gateway and bank-side issues."**

- 369 transactions failed across all apps and banks
- Top failure categories: Rent (22.5%), Entertainment (19.7%), Healthcare (19.7%)
- Failed transaction volume = ₹33,81,437 at risk (estimated)

---

### Finding 2: Missing Payments — 87 Transactions (₹7,70,058 at Risk)

> **"87 SUCCESS transactions have no corresponding payment record — meaning money was debited from the sender but settlement was never initiated. This is the most operationally dangerous reconciliation gap."**

- These 87 transactions represent ₹7,70,058 in unreconciled funds
- This type of gap is typical when the payment processor crashes mid-transaction
- **Business Impact:** Users may raise disputes; company may owe refunds without a clear settlement trail

---

### Finding 3: Amount Mismatch — 167 Transactions (₹7,94,127 Variance)

> **"167 transactions show a discrepancy between the amount charged to the customer (transactions table) and the amount processed in the payment system — creating a combined revenue variance of ₹7,94,127."**

- Mismatch rate: 8.21% of all transactions
- Could be caused by: rounding errors, partial refunds logged incorrectly, or fee deductions not reflected in transaction records
- **Business Impact:** Overstated revenue in MIS reports; potential regulatory non-compliance

---

### Finding 4: Suspected Duplicate Transactions — 40 Cases

> **"40 transactions were identified as potential duplicates — same user ID, same amount, within a 5-minute window — a pattern typically caused by network timeout retries or double-tap payment errors on the app."**

- Window used: 5 minutes (300 seconds)
- If all are true duplicates: ₹X lakh in double charges possible
- **Business Impact:** Customer complaints, refund overhead, and negative NPS impact

---

### Finding 5: Peak Failure Hours — 8 AM and 10 PM

> **"Failure rates spike during 8 AM (20.0%) and 10–11 PM (18.2%), corresponding to morning commute payments and end-of-day bill settlements — both high-traffic windows for UPI apps."**

| Hour | Failures | Total | Failure Rate |
|------|----------|-------|--------------|
| 8 AM | 30 | 150 | 20.0% |
| 10 PM | 32 | 176 | 18.2% |
| 8 PM | 31 | 172 | 18.0% |
| 1 PM | 30 | 181 | 16.6% |

- **Root cause hypothesis:** Bank core banking systems overloaded during peak hours
- **Recommendation:** Implement exponential back-off retry logic and proactive user notifications during high-failure windows

---

### Finding 6: Amazon Pay Has Highest Failure Rate (22.57%)

> **"Amazon Pay recorded the highest failure rate at 22.57%, followed by PhonePe (18.58%) and Paytm (18.0%) — while BHIM (16.42%) and CRED (16.57%) performed comparatively better."**

| UPI App | Total | Failed | Failure Rate |
|---------|-------|--------|--------------|
| Amazon Pay | 350 | 79 | 22.57% |
| PhonePe | 339 | 63 | 18.58% |
| Paytm | 300 | 54 | 18.00% |
| Google Pay | 355 | 59 | 16.62% |
| CRED | 350 | 58 | 16.57% |
| BHIM | 341 | 56 | 16.42% |

---

### Finding 7: BOB and ICICI Banks Show Highest Failure Rates

| Bank | Failure Rate |
|------|--------------|
| BOB | 20.61% |
| ICICI | 20.14% |
| Axis | 19.61% |
| Canara | 18.26% |
| SBI | 17.52% |
| HDFC | 15.64% (lowest) |

> **"HDFC performed best with a 15.64% failure rate, while BOB showed the highest at 20.61% — suggesting API gateway reliability differences between bank-side infrastructure."**

---

### Finding 8: Status Conflicts — 80 Critical Cases

> **"80 transactions show a STATUS CONFLICT — the transaction is marked SUCCESS in the transaction log but FAILED in the payment processor. These are the highest-priority reconciliation cases requiring immediate manual review."**

- These cases may result in double-debits or missed settlements
- Cannot be resolved automatically — require human intervention + user communication

---

### Finding 9: Average Processing Time = 25.2 Seconds

> **"The average time between transaction creation and payment processing is 25.2 seconds, with a maximum of 290 seconds — indicating occasional severe delays likely linked to bank API timeouts."**

- High-delay transactions (>60s) are likely to trigger user "retry" behaviour, contributing to duplicates
- **Recommendation:** Set processing SLA at 30 seconds; alert ops team for anything >60s

---

## 📊 Reconciliation Status Summary

| Status | Count | % of Total |
|--------|-------|------------|
| ✅ Valid | 1,271 | 62.46% |
| ❌ Failed Transaction | 264 | 12.97% |
| ⚠️ Amount Mismatch | 167 | 8.21% |
| 🔄 Pending — No Record | 166 | 8.16% |
| 🚫 Missing Payment | 87 | 4.28% |
| 🔴 Status Conflict | 80 | 3.93% |

**Only 62.46% of transactions are fully valid and reconciled.**  
This means 37.54% — over 1 in 3 transactions — has some form of anomaly.

---

## 💼 Business Impact Summary

| Issue | Count | Estimated Financial Exposure |
|-------|-------|------------------------------|
| Missing Payments | 87 | ₹7,70,058 |
| Amount Mismatches | 167 | ₹7,94,127 variance |
| Status Conflicts | 80 | Full amount at risk |
| Suspected Duplicates | 40 | Potential double-charge |
| **Total** | **374** | **₹15,64,185+** |

---

## ✅ Recommendations

1. **Implement real-time reconciliation** — run master reconciliation query every hour, not end-of-day
2. **Set up automated alerting** for Status Conflict cases (highest risk)
3. **Investigate peak-hour failures** — work with bank partners (especially BOB, ICICI) on API reliability during 8–10 AM and 8–10 PM
4. **Add deduplication logic** at the UPI app layer — 5-minute idempotency keys per (user_id + amount) pair
5. **Audit Amazon Pay integration** — 22.57% failure rate needs root-cause analysis
6. **Create daily MIS dashboard** in Power BI on top of these reconciliation queries

---

*Analysis performed using SQL (PostgreSQL-compatible) on 2,035 simulated UPI transactions modelled after real PhonePe-style payment data.*
