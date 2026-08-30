# Member 3: Order, Payment & Fulfillment Management

## 📌 Module Overview
This module orchestrates the omnichannel commercial pipeline for 88 Speedmart. It manages online and counter order placement, enforces mutual exclusivity between In-Store Pickup (with 6-digit claim tokens) and 3PL Delivery dispatch, processes multi-channel payment settlements, and automates customer loyalty point accruals.

---

## 📁 Showcase Files Breakdown

| Task | File Name | Description & Complexity Highlights |
| :--- | :--- | :--- |
| **Task 4 & 8** | [`01_queries.sql`](01_queries.sql) | • **Query 1 (Strategic):** Omnichannel fulfillment channel revenue and basket size analysis using `CASE` categorization, multi-table joins, and `RATIO_TO_REPORT()`.<br>• **Query 2 (Tactical):** 3PL courier partner SLA fulfillment rate & logistics surcharge audit.<br>• **Extra Efforts:** Sequences `seq_order_id` & `seq_payment_id`, 2 Indexes, 2 Views (`v_omnichannel_fulfillment_rev`, `v_courier_sla_performance`). |
| **Task 5 & 8** | [`02_procedures.sql`](02_procedures.sql) | • **Procedure 1:** `sp_create_pickup_order` (Atomic order & pickup booking, 6-digit code generation, daily cancellation limit check).<br>• **Procedure 2:** `sp_settle_order_payment` (Multi-channel payment, points accrual, `PRAGMA EXCEPTION_INIT(-1)` for unique txn validation). |
| **Task 6** | [`03_triggers.sql`](03_triggers.sql) | • **Trigger 1:** `trg_guard_exclusive_fulfillment` (Enforces Core Assumption 2: blocks concurrent Pickup & Delivery records for the same order).<br>• **Trigger 2:** `trg_guard_paid_payment_state` (`WHEN (OLD.PaymentStatus = 'Paid' AND NEW.PaymentStatus = 'Pending')` protects financial integrity). |
| **Task 7** | [`04_reports.sql`](04_reports.sql) | • **Report 1:** `sp_rpt_order_tax_invoice` (Nested cursors: Order Header $\rightarrow$ Line Items with discounts & net grand totals).<br>• **Report 2:** `sp_rpt_branch_daily_manifest` (Nested cursors: Branch $\rightarrow$ Pickup Queue $\rightarrow$ Courier Dispatches). |

---

## 🚀 Live Presentation Execution Commands

```sql
-- Step 1: Execute Queries & Views
@modules/03_order_fulfillment/01_queries.sql

-- Step 2: Compile & Test Stored Procedures
@modules/03_order_fulfillment/02_procedures.sql

-- Step 3: Compile & Verify Triggers
@modules/03_order_fulfillment/03_triggers.sql

-- Step 4: Run Nested Cursor Reports
@modules/03_order_fulfillment/04_reports.sql
```
