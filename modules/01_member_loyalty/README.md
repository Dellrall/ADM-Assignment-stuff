# Member 1: Member & Loyalty Management

## 📌 Module Overview
This module governs customer lifecycle, VIP subscriptions, loyalty point accruals (1 pt per RM 1.00 spent), voucher redemptions, and inactivity risk management for 88 Speedmart.

---

## 📁 Showcase Files Breakdown

| Task | File Name | Description & Complexity Highlights |
| :--- | :--- | :--- |
| **Task 4 & 8** | [`01_queries.sql`](01_queries.sql) | • **Query 1 (Strategic):** Customer churn risk matrix using CTE, multi-table joins, `DENSE_RANK()`, date arithmetic.<br>• **Query 2 (Tactical):** Voucher burn rate and ROI with `RATIO_TO_REPORT()`.<br>• **Extra Efforts:** Sequence `seq_member_id`, 2 Indexes, 2 Views (`v_member_churn_risk`, `v_voucher_conversion_roi`). |
| **Task 5 & 8** | [`02_procedures.sql`](02_procedures.sql) | • **Procedure 1:** `sp_register_or_renew_member` (Regex validation, VIP 1-year auto-calculation, custom exceptions).<br>• **Procedure 2:** `sp_process_point_redemption` (Row locking, min spend checks, `PRAGMA EXCEPTION_INIT(-2291)`). |
| **Task 6** | [`03_triggers.sql`](03_triggers.sql) | • **Trigger 1:** `trg_guard_point_redemption` (Rejects redemptions exceeding balance or by inactive members).<br>• **Trigger 2:** `trg_enforce_vip_expiration` (`WHEN (NEW.MembershipType = 'VIP')` auto-calculates 12-month expiry). |
| **Task 7** | [`04_reports.sql`](04_reports.sql) | • **Report 1:** `sp_rpt_member_annual_statement` (Nested cursors: Member $\rightarrow$ 12-Month Orders $\rightarrow$ Redemptions).<br>• **Report 2:** `sp_rpt_voucher_performance_summary` (Nested cursors: Voucher Catalog $\rightarrow$ Customer Claims). |

---

## 🚀 Live Presentation Execution Commands

```sql
-- Step 1: Execute Queries & Views
@modules/01_member_loyalty/01_queries.sql

-- Step 2: Compile & Test Stored Procedures
@modules/01_member_loyalty/02_procedures.sql

-- Step 3: Compile & Verify Triggers
@modules/01_member_loyalty/03_triggers.sql

-- Step 4: Run Nested Cursor Reports
@modules/01_member_loyalty/04_reports.sql
```
